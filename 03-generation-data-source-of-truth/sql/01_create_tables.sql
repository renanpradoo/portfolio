-- ============================================================
-- Project: Generation Data Source of Truth
-- File: 01_create_tables.sql
-- Description:
--   Creates the relational structure for the synthetic generation
--   source-of-truth model.
--
-- Target dialect: PostgreSQL
-- ============================================================

-- Optional: create a dedicated schema
-- CREATE SCHEMA IF NOT EXISTS generation_sot;
-- SET search_path TO generation_sot;

-- ============================================================
-- 1. projects
-- ============================================================

DROP TABLE IF EXISTS compiled_generation;
DROP TABLE IF EXISTS generation_version_control;
DROP TABLE IF EXISTS projects;

CREATE TABLE projects (
    project_id                  VARCHAR(20) PRIMARY KEY,
    project_name                VARCHAR(120) NOT NULL,
    installed_capacity_kwp      NUMERIC(10, 2) NOT NULL,
    project_type                VARCHAR(50) NOT NULL,
    asset_category              VARCHAR(50) NOT NULL,
    commercial_operation_date   DATE,
    state                       CHAR(2) NOT NULL,
    city                        VARCHAR(100) NOT NULL,
    distributor                 VARCHAR(100) NOT NULL,
    operational_status          VARCHAR(50) NOT NULL,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_projects_capacity_positive
        CHECK (installed_capacity_kwp > 0),

    CONSTRAINT chk_projects_project_type
        CHECK (project_type IN (
            'Ground-mounted',
            'Roof-mounted',
            'Carport',
            'Other'
        )),

    CONSTRAINT chk_projects_asset_category
        CHECK (asset_category IN (
            'Shared Generation',
            'Remote Generation',
            'On-site Generation',
            'Other'
        )),

    CONSTRAINT chk_projects_operational_status
        CHECK (operational_status IN (
            'Operational',
            'Under Construction',
            'Commissioning',
            'Inactive',
            'Decommissioned'
        ))
);

-- ============================================================
-- 2. generation_version_control
-- ============================================================

CREATE TABLE generation_version_control (
    generation_version_control_id   VARCHAR(30) PRIMARY KEY,
    project_id                      VARCHAR(20) NOT NULL,
    generation_type                 VARCHAR(50) NOT NULL,
    model_type                      VARCHAR(50) NOT NULL,
    model_version                   VARCHAR(50) NOT NULL,
    simulation_responsible          VARCHAR(80) NOT NULL,
    meteorological_database         VARCHAR(80),
    datasource                      VARCHAR(150) NOT NULL,
    p50_generation_kwh              NUMERIC(14, 2) NOT NULL,
    p90_generation_kwh              NUMERIC(14, 2) NOT NULL,
    p95_generation_kwh              NUMERIC(14, 2) NOT NULL,
    is_trusted_benchmark            BOOLEAN NOT NULL DEFAULT FALSE,
    is_active_version               BOOLEAN NOT NULL DEFAULT FALSE,
    simulation_date                 DATE NOT NULL,
    created_at                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_gvc_project
        FOREIGN KEY (project_id)
        REFERENCES projects(project_id),

    CONSTRAINT chk_gvc_generation_type
        CHECK (generation_type IN (
            'PVSyst',
            'SolarGIS',
            'Modeled'
        )),

    CONSTRAINT chk_gvc_model_type
        CHECK (model_type IN (
            'As-built',
            'Legacy',
            'Preliminary'
        )),

    CONSTRAINT chk_gvc_simulation_responsible
        CHECK (simulation_responsible IN (
            'EPC',
            'Engineering Team',
            'Construction Team',
            'External Consultant'
        )),

    CONSTRAINT chk_gvc_meteorological_database
        CHECK (
            meteorological_database IS NULL
            OR meteorological_database IN (
                'SolarGIS',
                'Meteonorm',
                'NASA',
                'Other'
            )
        ),

    CONSTRAINT chk_gvc_generation_values_positive
        CHECK (
            p50_generation_kwh > 0
            AND p90_generation_kwh > 0
            AND p95_generation_kwh > 0
        ),

    CONSTRAINT chk_gvc_probability_order
        CHECK (
            p50_generation_kwh >= p90_generation_kwh
            AND p90_generation_kwh >= p95_generation_kwh
        ),

    CONSTRAINT uq_gvc_project_generation_model_version
        UNIQUE (
            project_id,
            generation_type,
            model_type,
            model_version
        )
);

-- Optional business rule:
-- only one active trusted benchmark per project and generation type.
-- This partial unique index is PostgreSQL-specific.
CREATE UNIQUE INDEX uq_gvc_one_active_trusted_benchmark
    ON generation_version_control(project_id, generation_type)
    WHERE is_trusted_benchmark = TRUE
      AND is_active_version = TRUE;

-- ============================================================
-- 3. compiled_generation
-- ============================================================

CREATE TABLE compiled_generation (
    id                              VARCHAR(40) PRIMARY KEY,
    project_id                      VARCHAR(20) NOT NULL,
    generation_version_control_id   VARCHAR(30),
    reference_month                 DATE NOT NULL,
    generation_type                 VARCHAR(50) NOT NULL,
    generation_value_kwh            NUMERIC(14, 2) NOT NULL,
    created_at                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_compiled_generation_project
        FOREIGN KEY (project_id)
        REFERENCES projects(project_id),

    CONSTRAINT fk_compiled_generation_gvc
        FOREIGN KEY (generation_version_control_id)
        REFERENCES generation_version_control(generation_version_control_id),

    CONSTRAINT chk_compiled_generation_reference_month
        CHECK (reference_month = DATE_TRUNC('month', reference_month)::DATE),

    CONSTRAINT chk_compiled_generation_type
        CHECK (generation_type IN (
            'Actual',
            'PVSyst',
            'SolarGIS',
            'Modeled'
        )),

    CONSTRAINT chk_compiled_generation_value_non_negative
        CHECK (generation_value_kwh >= 0),

    -- Actual generation is measured generation, not a benchmark version.
    -- Benchmark/simulated records should reference the version-control table.
    CONSTRAINT chk_compiled_generation_gvc_usage
        CHECK (
            (generation_type = 'Actual' AND generation_version_control_id IS NULL)
            OR
            (generation_type <> 'Actual' AND generation_version_control_id IS NOT NULL)
        ),

    CONSTRAINT uq_compiled_generation_logical_key
        UNIQUE (
            project_id,
            reference_month,
            generation_type,
            generation_version_control_id
        )
);

-- ============================================================
-- Supporting indexes
-- ============================================================

CREATE INDEX idx_gvc_project_id
    ON generation_version_control(project_id);

CREATE INDEX idx_gvc_project_active_trusted
    ON generation_version_control(project_id, is_active_version, is_trusted_benchmark);

CREATE INDEX idx_compiled_generation_project_month
    ON compiled_generation(project_id, reference_month);

CREATE INDEX idx_compiled_generation_gvc
    ON compiled_generation(generation_version_control_id);

CREATE INDEX idx_compiled_generation_type_month
    ON compiled_generation(generation_type, reference_month);

-- ============================================================
-- Notes
-- ============================================================
-- Modeling logic:
--
-- 1. projects
--    Stores one row per solar project/asset.
--
-- 2. generation_version_control
--    Stores benchmark metadata and simulation-level values.
--    It does not store monthly curves.
--
-- 3. compiled_generation
--    Stores monthly generation records in long format.
--    Actual generation records do not reference GVC.
--    PVSyst, SolarGIS and Modeled records must reference GVC.
--
-- The model allows monthly actual generation to be compared with the
-- correct benchmark curve while preserving traceability over benchmark
-- versions, assumptions and confidence-level outputs such as P50/P90/P95.
-- ============================================================
