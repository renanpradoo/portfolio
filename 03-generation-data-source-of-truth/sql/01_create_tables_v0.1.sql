-- ============================================================
-- Project: Generation Data Source of Truth
-- File: 01_create_tables.sql
-- Description:
--   Reconstructed SQL table-creation script for a synthetic version
--   of a real generation data source-of-truth project.
--
-- Context:
--   The original project structured generation-related data so it
--   could feed Tableau reporting and support executive analysis.
--   The production SQL layer was relatively simple and focused on
--   preparing clean, reliable tables for reporting.
--
-- Reconstruction note:
--   This script was rebuilt for portfolio purposes using synthetic
--   data and AI assistance. It reflects the intended data model,
--   table relationships, constraints, and business rules behind the
--   original project, but it is not a direct copy of the production
--   environment.
--
-- Target dialect: PostgreSQL
-- ============================================================


-- ============================================================
-- Optional schema setup
-- ============================================================

-- CREATE SCHEMA IF NOT EXISTS generation_sot;
-- SET search_path TO generation_sot;


-- ============================================================
-- Drop tables
-- ============================================================

DROP TABLE IF EXISTS compiled_generation;
DROP TABLE IF EXISTS generation_version_control;
DROP TABLE IF EXISTS projects;


-- ============================================================
-- 1. projects
-- ============================================================

CREATE TABLE projects (
    project_id                  VARCHAR(20) PRIMARY KEY,
    project_name                VARCHAR(120) NOT NULL,
    installed_capacity_kwp      NUMERIC(10, 2) NOT NULL,
    project_type                VARCHAR(50),
    asset_category              VARCHAR(50),
    commercial_operation_date   DATE,
    state                       CHAR(2),
    city                        VARCHAR(100),
    distributor                 VARCHAR(100),
    operational_status          VARCHAR(50),
    created_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_projects_capacity_positive
        CHECK (installed_capacity_kwp > 0),

    CONSTRAINT chk_projects_project_type
        CHECK (
            project_type IS NULL
            OR project_type IN (
                'Ground-mounted',
                'Roof-mounted',
                'Carport',
                'Other'
            )
        ),

    CONSTRAINT chk_projects_asset_category
        CHECK (
            asset_category IS NULL
            OR asset_category IN (
                'Remote Generation',
                'On-site Generation',
                'Shared Generation',
                'Other'
            )
        ),

    CONSTRAINT chk_projects_operational_status
        CHECK (
            operational_status IS NULL
            OR operational_status IN (
                'Operational',
                'Under Construction',
                'Commissioning',
                'Inactive',
                'Decommissioned'
            )
        )
);


-- ============================================================
-- 2. generation_version_control
-- ============================================================

CREATE TABLE generation_version_control (
    generation_version_control_id   VARCHAR(30) PRIMARY KEY,
    project_id                      VARCHAR(20) NOT NULL,
    generation_type                 VARCHAR(50) NOT NULL,
    model_type                      VARCHAR(50),
    model_version                   VARCHAR(50),
    simulation_responsible          VARCHAR(80),
    meteorological_database         VARCHAR(80),
    datasource                      VARCHAR(150),
    p50_generation_kwh              NUMERIC(14, 2),
    p90_generation_kwh              NUMERIC(14, 2),
    p95_generation_kwh              NUMERIC(14, 2),
    is_trusted_benchmark            BOOLEAN NOT NULL DEFAULT FALSE,
    is_active_version               BOOLEAN NOT NULL DEFAULT FALSE,
    simulation_date                 DATE,
    created_at                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

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
        CHECK (
            model_type IS NULL
            OR model_type IN (
                'As-built',
                'Legacy',
                'Preliminary'
            )
        ),

    CONSTRAINT chk_gvc_simulation_responsible
        CHECK (
            simulation_responsible IS NULL
            OR simulation_responsible IN (
                'EPC',
                'Engineering Team',
                'Construction Team',
                'External Consultant'
            )
        ),

    CONSTRAINT chk_gvc_meteorological_database
        CHECK (
            meteorological_database IS NULL
            OR meteorological_database IN (
                'SolarGIS',
                'Meteonorm',
                'NASA',
                'Other',
                'Not Applicable'
            )
        ),

    CONSTRAINT chk_gvc_generation_values_non_negative
        CHECK (
            (p50_generation_kwh IS NULL OR p50_generation_kwh >= 0)
            AND (p90_generation_kwh IS NULL OR p90_generation_kwh >= 0)
            AND (p95_generation_kwh IS NULL OR p95_generation_kwh >= 0)
        ),

    CONSTRAINT chk_gvc_probability_order
        CHECK (
            p50_generation_kwh IS NULL
            OR p90_generation_kwh IS NULL
            OR p95_generation_kwh IS NULL
            OR (
                p50_generation_kwh >= p90_generation_kwh
                AND p90_generation_kwh >= p95_generation_kwh
            )
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
-- Only one active trusted benchmark should exist per project and
-- generation type.
-- This partial unique index is PostgreSQL-specific.

CREATE UNIQUE INDEX uq_gvc_one_active_trusted_benchmark
    ON generation_version_control(project_id, generation_type)
    WHERE is_trusted_benchmark = TRUE
      AND is_active_version = TRUE;


-- ============================================================
-- 3. compiled_generation
-- ============================================================

CREATE TABLE compiled_generation (
    id                              INTEGER PRIMARY KEY,
    project_id                      VARCHAR(20) NOT NULL,
    reference_month                 DATE NOT NULL,
    generation_type                 VARCHAR(50) NOT NULL,
    generation_value_kwh            NUMERIC(14, 2) NOT NULL,
    generation_version_control_id   VARCHAR(30),
    created_at                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_compiled_generation_project
        FOREIGN KEY (project_id)
        REFERENCES projects(project_id),

    CONSTRAINT fk_compiled_generation_gvc
        FOREIGN KEY (generation_version_control_id)
        REFERENCES generation_version_control(generation_version_control_id),

    CONSTRAINT chk_compiled_generation_reference_month
        CHECK (EXTRACT(DAY FROM reference_month) = 1),

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

    CONSTRAINT uq_compiled_generation_simulated_logical_key
        UNIQUE (
            project_id,
            reference_month,
            generation_type,
            generation_version_control_id
        )
);


-- Actual records have NULL generation_version_control_id.
-- PostgreSQL allows multiple NULL values in a UNIQUE constraint, so this
-- partial index enforces one Actual record per project and reference month.

CREATE UNIQUE INDEX uq_compiled_generation_actual_month
    ON compiled_generation(project_id, reference_month)
    WHERE generation_type = 'Actual'
      AND generation_version_control_id IS NULL;


-- ============================================================
-- Supporting indexes
-- ============================================================

CREATE INDEX idx_gvc_project_id
    ON generation_version_control(project_id);

CREATE INDEX idx_gvc_project_active_trusted
    ON generation_version_control(
        project_id,
        is_active_version,
        is_trusted_benchmark
    );

CREATE INDEX idx_compiled_generation_project_month
    ON compiled_generation(project_id, reference_month);

CREATE INDEX idx_compiled_generation_gvc
    ON compiled_generation(generation_version_control_id);

CREATE INDEX idx_compiled_generation_type_month
    ON compiled_generation(generation_type, reference_month);


-- ============================================================
-- Modeling notes
-- ============================================================

-- 1. projects
--    Stores one row per solar project or asset.
--
-- 2. generation_version_control
--    Stores benchmark metadata and simulation-level values.
--    It does not store monthly generation curves.
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
