-- ============================================================
-- Project: Generation Data Source of Truth
-- File: 02_analysis_queries.sql
-- Description:
--   Analytical and data quality queries for the generation
--   source-of-truth model.
--
-- Target dialect: PostgreSQL
-- ============================================================

-- ============================================================
-- 1. List projects and their active trusted benchmarks
-- ============================================================
-- Purpose:
--   Identify which benchmark version is currently active and trusted
--   for each project and generation type.

SELECT
    p.project_id,
    p.project_name,
    p.installed_capacity_kwp,
    gvc.generation_type,
    gvc.model_type,
    gvc.model_version,
    gvc.simulation_responsible,
    gvc.meteorological_database,
    gvc.p50_generation_kwh,
    gvc.p90_generation_kwh,
    gvc.p95_generation_kwh,
    gvc.simulation_date
FROM projects p
LEFT JOIN generation_version_control gvc
    ON p.project_id = gvc.project_id
   AND gvc.is_active_version = TRUE
   AND gvc.is_trusted_benchmark = TRUE
ORDER BY
    p.project_id,
    gvc.generation_type;


-- ============================================================
-- 2. Check projects without an active trusted benchmark
-- ============================================================
-- Purpose:
--   Detect projects that do not have at least one active trusted
--   benchmark version.

SELECT
    p.project_id,
    p.project_name,
    p.installed_capacity_kwp,
    p.operational_status
FROM projects p
WHERE NOT EXISTS (
    SELECT 1
    FROM generation_version_control gvc
    WHERE gvc.project_id = p.project_id
      AND gvc.is_active_version = TRUE
      AND gvc.is_trusted_benchmark = TRUE
)
ORDER BY
    p.project_id;


-- ============================================================
-- 3. Detect multiple active trusted benchmarks per project/type
-- ============================================================
-- Purpose:
--   Validate the governance rule that each project should have only
--   one active trusted benchmark per generation type.

SELECT
    project_id,
    generation_type,
    COUNT(*) AS active_trusted_benchmark_count
FROM generation_version_control
WHERE is_active_version = TRUE
  AND is_trusted_benchmark = TRUE
GROUP BY
    project_id,
    generation_type
HAVING COUNT(*) > 1
ORDER BY
    project_id,
    generation_type;


-- ============================================================
-- 4. Actual generation coverage after COD
-- ============================================================
-- Purpose:
--   Check how many monthly actual-generation records exist after
--   commercial operation date for each operational project.

SELECT
    p.project_id,
    p.project_name,
    p.commercial_operation_date,
    MIN(cg.reference_month) AS first_actual_month,
    MAX(cg.reference_month) AS last_actual_month,
    COUNT(cg.compiled_generation_id) AS actual_months_available
FROM projects p
LEFT JOIN compiled_generation cg
    ON p.project_id = cg.project_id
   AND cg.generation_type = 'Actual'
   AND cg.reference_month >= DATE_TRUNC('month', p.commercial_operation_date)::DATE
WHERE p.commercial_operation_date IS NOT NULL
GROUP BY
    p.project_id,
    p.project_name,
    p.commercial_operation_date
ORDER BY
    p.project_id;


-- ============================================================
-- 5. Detect actual generation records before COD
-- ============================================================
-- Purpose:
--   Actual generation should generally not exist before the project's
--   commercial operation date.

SELECT
    cg.project_id,
    p.project_name,
    p.commercial_operation_date,
    cg.reference_month,
    cg.generation_value_kwh
FROM compiled_generation cg
JOIN projects p
    ON cg.project_id = p.project_id
WHERE cg.generation_type = 'Actual'
  AND p.commercial_operation_date IS NOT NULL
  AND cg.reference_month < DATE_TRUNC('month', p.commercial_operation_date)::DATE
ORDER BY
    cg.project_id,
    cg.reference_month;


-- ============================================================
-- 6. Monthly actual vs trusted PVSyst benchmark
-- ============================================================
-- Purpose:
--   Compare realized monthly generation against the active trusted
--   PVSyst benchmark curve.

WITH trusted_pvsyst AS (
    SELECT
        generation_version_control_id,
        project_id
    FROM generation_version_control
    WHERE generation_type = 'PVSyst'
      AND is_active_version = TRUE
      AND is_trusted_benchmark = TRUE
),
actual_generation AS (
    SELECT
        project_id,
        reference_month,
        generation_value_kwh AS actual_generation_kwh
    FROM compiled_generation
    WHERE generation_type = 'Actual'
),
expected_generation AS (
    SELECT
        cg.project_id,
        cg.reference_month,
        cg.generation_value_kwh AS expected_generation_kwh,
        cg.generation_version_control_id
    FROM compiled_generation cg
    JOIN trusted_pvsyst tp
        ON cg.generation_version_control_id = tp.generation_version_control_id
    WHERE cg.generation_type = 'PVSyst'
)
SELECT
    p.project_id,
    p.project_name,
    ag.reference_month,
    ag.actual_generation_kwh,
    eg.expected_generation_kwh,
    ag.actual_generation_kwh - eg.expected_generation_kwh AS generation_delta_kwh,
    ROUND(
        ag.actual_generation_kwh / NULLIF(eg.expected_generation_kwh, 0),
        4
    ) AS actual_vs_expected_ratio
FROM actual_generation ag
JOIN expected_generation eg
    ON ag.project_id = eg.project_id
   AND ag.reference_month = eg.reference_month
JOIN projects p
    ON ag.project_id = p.project_id
ORDER BY
    p.project_id,
    ag.reference_month;


-- ============================================================
-- 7. Annual actual vs trusted PVSyst benchmark
-- ============================================================
-- Purpose:
--   Aggregate monthly actual-vs-expected comparison by year.

WITH monthly_comparison AS (
    SELECT
        p.project_id,
        p.project_name,
        DATE_PART('year', ag.reference_month)::INT AS reference_year,
        ag.generation_value_kwh AS actual_generation_kwh,
        eg.generation_value_kwh AS expected_generation_kwh
    FROM compiled_generation ag
    JOIN generation_version_control gvc
        ON gvc.project_id = ag.project_id
       AND gvc.generation_type = 'PVSyst'
       AND gvc.is_active_version = TRUE
       AND gvc.is_trusted_benchmark = TRUE
    JOIN compiled_generation eg
        ON eg.project_id = ag.project_id
       AND eg.reference_month = ag.reference_month
       AND eg.generation_version_control_id = gvc.generation_version_control_id
       AND eg.generation_type = 'PVSyst'
    JOIN projects p
        ON p.project_id = ag.project_id
    WHERE ag.generation_type = 'Actual'
)
SELECT
    project_id,
    project_name,
    reference_year,
    SUM(actual_generation_kwh) AS actual_generation_kwh,
    SUM(expected_generation_kwh) AS expected_generation_kwh,
    SUM(actual_generation_kwh) - SUM(expected_generation_kwh) AS generation_delta_kwh,
    ROUND(
        SUM(actual_generation_kwh) / NULLIF(SUM(expected_generation_kwh), 0),
        4
    ) AS annual_actual_vs_expected_ratio
FROM monthly_comparison
GROUP BY
    project_id,
    project_name,
    reference_year
ORDER BY
    project_id,
    reference_year;


-- ============================================================
-- 8. Compare benchmark versions for each project
-- ============================================================
-- Purpose:
--   Show differences between PVSyst As-built, PVSyst Legacy,
--   SolarGIS and Modeled benchmark references at summary level.

SELECT
    p.project_id,
    p.project_name,
    gvc.generation_type,
    gvc.model_type,
    gvc.model_version,
    gvc.p50_generation_kwh,
    gvc.p90_generation_kwh,
    gvc.p95_generation_kwh,
    gvc.is_trusted_benchmark,
    gvc.is_active_version,
    ROUND(
        gvc.p90_generation_kwh / NULLIF(gvc.p50_generation_kwh, 0),
        4
    ) AS p90_to_p50_ratio,
    ROUND(
        gvc.p95_generation_kwh / NULLIF(gvc.p50_generation_kwh, 0),
        4
    ) AS p95_to_p50_ratio
FROM generation_version_control gvc
JOIN projects p
    ON p.project_id = gvc.project_id
ORDER BY
    p.project_id,
    gvc.generation_type,
    gvc.model_type,
    gvc.model_version;


-- ============================================================
-- 9. Validate probability ordering in GVC
-- ============================================================
-- Purpose:
--   P50 should be greater than or equal to P90, and P90 should be
--   greater than or equal to P95.

SELECT
    generation_version_control_id,
    project_id,
    generation_type,
    model_type,
    p50_generation_kwh,
    p90_generation_kwh,
    p95_generation_kwh
FROM generation_version_control
WHERE NOT (
    p50_generation_kwh >= p90_generation_kwh
    AND p90_generation_kwh >= p95_generation_kwh
)
ORDER BY
    project_id,
    generation_version_control_id;


-- ============================================================
-- 10. Validate GVC usage in compiled_generation
-- ============================================================
-- Purpose:
--   Actual records should not reference GVC.
--   Simulated/benchmark records should reference GVC.

SELECT
    compiled_generation_id,
    project_id,
    reference_month,
    generation_type,
    generation_version_control_id
FROM compiled_generation
WHERE
    (generation_type = 'Actual' AND generation_version_control_id IS NOT NULL)
    OR
    (generation_type <> 'Actual' AND generation_version_control_id IS NULL)
ORDER BY
    project_id,
    reference_month,
    generation_type;


-- ============================================================
-- 11. Detect duplicated monthly records by logical grain
-- ============================================================
-- Purpose:
--   Validate that there is only one record per project, month,
--   generation type and benchmark version.

SELECT
    project_id,
    reference_month,
    generation_type,
    generation_version_control_id,
    COUNT(*) AS record_count
FROM compiled_generation
GROUP BY
    project_id,
    reference_month,
    generation_type,
    generation_version_control_id
HAVING COUNT(*) > 1
ORDER BY
    project_id,
    reference_month,
    generation_type,
    generation_version_control_id;


-- ============================================================
-- 12. Detect generation records with invalid project references
-- ============================================================
-- Purpose:
--   Identify orphan records in compiled_generation.
--   This should return zero rows if FK constraints are active.

SELECT
    cg.compiled_generation_id,
    cg.project_id,
    cg.reference_month,
    cg.generation_type
FROM compiled_generation cg
LEFT JOIN projects p
    ON cg.project_id = p.project_id
WHERE p.project_id IS NULL
ORDER BY
    cg.project_id,
    cg.reference_month;


-- ============================================================
-- 13. Detect GVC records with invalid project references
-- ============================================================
-- Purpose:
--   Identify orphan records in generation_version_control.
--   This should return zero rows if FK constraints are active.

SELECT
    gvc.generation_version_control_id,
    gvc.project_id,
    gvc.generation_type,
    gvc.model_type
FROM generation_version_control gvc
LEFT JOIN projects p
    ON gvc.project_id = p.project_id
WHERE p.project_id IS NULL
ORDER BY
    gvc.project_id,
    gvc.generation_version_control_id;


-- ============================================================
-- 14. Monthly generation by source/type
-- ============================================================
-- Purpose:
--   Provide a portfolio-level monthly view by generation type.

SELECT
    reference_month,
    generation_type,
    COUNT(DISTINCT project_id) AS project_count,
    SUM(generation_value_kwh) AS total_generation_kwh
FROM compiled_generation
GROUP BY
    reference_month,
    generation_type
ORDER BY
    reference_month,
    generation_type;


-- ============================================================
-- 15. Portfolio capacity by operational status
-- ============================================================
-- Purpose:
--   Summarize installed capacity distribution by project status.

SELECT
    operational_status,
    COUNT(*) AS project_count,
    SUM(installed_capacity_kwp) AS installed_capacity_kwp,
    ROUND(
        SUM(installed_capacity_kwp) / NULLIF(SUM(SUM(installed_capacity_kwp)) OVER (), 0),
        4
    ) AS share_of_total_capacity
FROM projects
GROUP BY
    operational_status
ORDER BY
    installed_capacity_kwp DESC;


-- ============================================================
-- 16. Expected useful-life PVSyst generation by project
-- ============================================================
-- Purpose:
--   Validate the 20-year PVSyst curve volume and total expected
--   generation by project and model version.

SELECT
    p.project_id,
    p.project_name,
    gvc.model_type,
    gvc.model_version,
    COUNT(cg.compiled_generation_id) AS pvsyst_month_count,
    MIN(cg.reference_month) AS first_pvsyst_month,
    MAX(cg.reference_month) AS last_pvsyst_month,
    SUM(cg.generation_value_kwh) AS useful_life_generation_kwh
FROM generation_version_control gvc
JOIN compiled_generation cg
    ON cg.generation_version_control_id = gvc.generation_version_control_id
JOIN projects p
    ON p.project_id = gvc.project_id
WHERE gvc.generation_type = 'PVSyst'
  AND cg.generation_type = 'PVSyst'
GROUP BY
    p.project_id,
    p.project_name,
    gvc.model_type,
    gvc.model_version
ORDER BY
    p.project_id,
    gvc.model_type,
    gvc.model_version;


-- ============================================================
-- 17. Check PVSyst curves with fewer than 240 months
-- ============================================================
-- Purpose:
--   A complete useful-life PVSyst curve should contain 240 monthly
--   records per project/version under the assumptions used in the
--   synthetic sample data.

SELECT
    gvc.project_id,
    gvc.generation_version_control_id,
    gvc.model_type,
    gvc.model_version,
    COUNT(cg.compiled_generation_id) AS month_count
FROM generation_version_control gvc
LEFT JOIN compiled_generation cg
    ON cg.generation_version_control_id = gvc.generation_version_control_id
   AND cg.generation_type = 'PVSyst'
WHERE gvc.generation_type = 'PVSyst'
GROUP BY
    gvc.project_id,
    gvc.generation_version_control_id,
    gvc.model_type,
    gvc.model_version
HAVING COUNT(cg.compiled_generation_id) <> 240
ORDER BY
    gvc.project_id,
    gvc.generation_version_control_id;


-- ============================================================
-- 18. Actual generation productivity by project
-- ============================================================
-- Purpose:
--   Estimate realized generation intensity in kWh/kWp for projects
--   with actual generation records.

SELECT
    p.project_id,
    p.project_name,
    p.installed_capacity_kwp,
    COUNT(cg.compiled_generation_id) AS actual_months,
    SUM(cg.generation_value_kwh) AS actual_generation_kwh,
    ROUND(
        SUM(cg.generation_value_kwh) / NULLIF(p.installed_capacity_kwp, 0),
        2
    ) AS actual_kwh_per_kwp_available_period
FROM projects p
JOIN compiled_generation cg
    ON cg.project_id = p.project_id
WHERE cg.generation_type = 'Actual'
GROUP BY
    p.project_id,
    p.project_name,
    p.installed_capacity_kwp
ORDER BY
    actual_kwh_per_kwp_available_period DESC;


-- ============================================================
-- 19. Monthly generation below 70% of trusted PVSyst benchmark
-- ============================================================
-- Purpose:
--   Flag project-months with potential underperformance.

WITH actual_vs_expected AS (
    SELECT
        p.project_id,
        p.project_name,
        ag.reference_month,
        ag.generation_value_kwh AS actual_generation_kwh,
        eg.generation_value_kwh AS expected_generation_kwh,
        ROUND(
            ag.generation_value_kwh / NULLIF(eg.generation_value_kwh, 0),
            4
        ) AS actual_vs_expected_ratio
    FROM compiled_generation ag
    JOIN generation_version_control gvc
        ON gvc.project_id = ag.project_id
       AND gvc.generation_type = 'PVSyst'
       AND gvc.is_active_version = TRUE
       AND gvc.is_trusted_benchmark = TRUE
    JOIN compiled_generation eg
        ON eg.project_id = ag.project_id
       AND eg.reference_month = ag.reference_month
       AND eg.generation_version_control_id = gvc.generation_version_control_id
    JOIN projects p
        ON p.project_id = ag.project_id
    WHERE ag.generation_type = 'Actual'
      AND eg.generation_type = 'PVSyst'
)
SELECT
    *
FROM actual_vs_expected
WHERE actual_vs_expected_ratio < 0.70
ORDER BY
    actual_vs_expected_ratio,
    project_id,
    reference_month;


-- ============================================================
-- 20. Benchmark audit trail for a selected project
-- ============================================================
-- Purpose:
--   Inspect all benchmark versions associated with a project.
--   Replace 'PRJ_001' with the desired project_id.

SELECT
    gvc.project_id,
    p.project_name,
    gvc.generation_version_control_id,
    gvc.generation_type,
    gvc.model_type,
    gvc.model_version,
    gvc.simulation_responsible,
    gvc.meteorological_database,
    gvc.datasource,
    gvc.p50_generation_kwh,
    gvc.p90_generation_kwh,
    gvc.p95_generation_kwh,
    gvc.is_trusted_benchmark,
    gvc.is_active_version,
    gvc.simulation_date,
    gvc.created_at,
    gvc.updated_at
FROM generation_version_control gvc
JOIN projects p
    ON p.project_id = gvc.project_id
WHERE gvc.project_id = 'PRJ_001'
ORDER BY
    gvc.generation_type,
    gvc.model_type,
    gvc.model_version;
