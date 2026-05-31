# Table: `generation_version_control`

## Description

`generation_version_control` is a dimension table used to control simulation versions, benchmark assumptions and generation modeling references for each project.

This table was created to solve one of the most important problems in the original process: the lack of version control over PVSyst studies, financial model assumptions and meteorological references.

Before this structure, the same project could have multiple simulations without a clear way to identify which one should be treated as the most recent, reliable or official benchmark.

---

## Granularity

One row per:

* Project
* Generation type
* Simulation or model version

In practical terms, each row represents a specific generation benchmark version for a given project.

Examples:

* PVSyst As-built simulation for Project A
* Legacy financial model assumption for Project B
* SolarGIS-based scenario for Project C
* Engineering-adjusted internal model for Project D

---

## Primary Key

Suggested primary key:

```text
generation_version_control_id
```

Alternative composite key:

```text
project_id + generation_type + model_type + model_version
```

The synthetic key is preferred because different data sources may not follow the same version naming convention.

---

## Relationships

| Column                          | References                                          | Relationship Type |
| ------------------------------- | --------------------------------------------------- | ----------------- |
| `project_id`                    | `projects.project_id`                               | Many-to-one       |
| `generation_version_control_id` | `compiled_generation.generation_version_control_id` | One-to-many       |

---

## Columns

| Column                          | Type      | Nullable | Description                                                                     | Example                        |
| ------------------------------- | --------- | -------: | ------------------------------------------------------------------------------- | ------------------------------ |
| `generation_version_control_id` | string    |       No | Unique identifier for the simulation or benchmark version.                      | `GVC_0001`                     |
| `project_id`                    | string    |       No | Unique identifier of the project associated with the simulation.                | `PRJ_001`                      |
| `generation_type`               | string    |       No | Type of generation benchmark controlled by this record.                         | `PVSyst`                       |
| `model_type`                    | string    |      Yes | Classification of the model or simulation.                                      | `As-built`                     |
| `model_version`                 | string    |      Yes | Version reference used to identify the simulation or financial model.           | `FM_v03`                       |
| `simulation_responsible`        | string    |      Yes | Party or team responsible for producing the simulation.                         | `Engineering Team`             |
| `meteorological_database`       | string    |      Yes | Meteorological database used as reference.                                      | `SolarGIS`                     |
| `datasource`                    | string    |      Yes | Source file, model, study or document used as reference.                        | `PVSyst_Project_A_AsBuilt_v02` |
| `p50_generation_kwh`            | numeric   |      Yes | P50 generation estimate in kWh.                                                 | `1850000.00`                   |
| `p90_generation_kwh`            | numeric   |      Yes | P90 generation estimate in kWh.                                                 | `1720000.00`                   |
| `p95_generation_kwh`            | numeric   |      Yes | P95 generation estimate in kWh.                                                 | `1680000.00`                   |
| `is_trusted_benchmark`          | boolean   |       No | Indicates whether this version is considered a trusted benchmark for reporting. | `true`                         |
| `is_active_version`             | boolean   |       No | Indicates whether this version is currently active for analytical use.          | `true`                         |
| `simulation_date`               | date      |      Yes | Date when the simulation or model version was produced.                         | `2023-11-15`                   |
| `created_at`                    | timestamp |      Yes | Date and time when the record was created.                                      | `2024-01-10 09:30:00`          |
| `updated_at`                    | timestamp |      Yes | Date and time when the record was last updated.                                 | `2024-02-01 14:45:00`          |

---

## Accepted Values

### `generation_type`

Suggested accepted values:

| Value             | Meaning                                                     |
| ----------------- | ----------------------------------------------------------- |
| `PVSyst`          | Generation benchmark based on a PVSyst simulation.          |
| `SolarGIS`        | Generation benchmark based on SolarGIS meteorological data. |
| `Modeled`         | Internally modeled or adjusted generation assumption.       |

---

### `model_type`

Suggested accepted values:

| Value         | Meaning                                                          |
| ------------- | ---------------------------------------------------------------- |
| `As-built`    | Simulation based on final built characteristics of the asset.    |
| `Legacy`      | Older simulation or model version kept for historical reference. |
| `Financial`   | Model assumption used for financial planning.                    |
| `Operational` | Adjusted benchmark used for operational monitoring.              |

---

### `simulation_responsible`

Suggested accepted values:

| Value                 | Meaning                                                              |
| --------------------- | -------------------------------------------------------------------- |
| `EPC`                 | Simulation provided by the EPC contractor.                           |
| `Engineering Team`    | Simulation produced or validated by the internal engineering team.   |
| `Construction Team`   | Simulation or assumption provided by the internal construction team. |
| `Business Analytics`  | Internally structured or adjusted analytical reference.              |
| `External Consultant` | Simulation provided by an external technical partner.                |

---

### `meteorological_database`

Suggested accepted values:

| Value            | Meaning                                         |
| ---------------- | ----------------------------------------------- |
| `SolarGIS`       | Meteorological basis provided by SolarGIS.      |
| `Meteonorm`      | Meteorological basis from Meteonorm.            |
| `NASA`           | Meteorological basis from NASA datasets.        |
| `Other`          | Other meteorological reference.                 |
| `Not Applicable` | Not applicable to the specific generation type. |

---

## Business Rules

* Each simulation or benchmark version must be linked to a valid project.
* A project may have multiple simulation versions.
* Only one version should be flagged as `is_trusted_benchmark = true` for the same project and generation type, unless a specific business exception exists.
* Legacy versions should be preserved for traceability but should not be used as trusted benchmarks unless explicitly flagged.
* P50, P90 and P95 values should be stored in kWh and should follow the same unit convention used in the reporting layer.
* `datasource` should preserve enough information to trace the original file, model or simulation document.
* SolarGIS, Meteonorm, NASA or other meteorological references should be documented whenever available.
* When a new simulation becomes the official benchmark, the previous version should remain in the table but should no longer be flagged as the active trusted benchmark.
* Tableau reports should rely on `is_trusted_benchmark` or `is_active_version` to select the correct comparison scenario.

---

## Data Quality Checks

| Check                                 | Expected Result                                                                                                             |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `project_id` exists in `projects`     | Every simulation version must be linked to a valid project.                                                                 |
| `generation_type` is valid            | Every version should belong to an accepted generation type.                                                                 |
| No duplicate active benchmark         | The same project and generation type should not have more than one active trusted benchmark.                                |
| P-values are non-negative             | `p50_generation_kwh`, `p90_generation_kwh` and `p95_generation_kwh` should not be negative.                                 |
| P-value consistency                   | When available, P50 should usually be greater than or equal to P90, and P90 should usually be greater than or equal to P95. |
| Active versions have source reference | Active or trusted benchmark records should have a defined `datasource`.                                                     |
| Simulation date is valid              | Simulation dates should not be greater than the record creation date unless explicitly justified.                           |

---

## Notes

This table is the core of the project’s version control logic.

Its purpose is not only to store simulation values, but to make benchmark selection auditable, traceable and scalable. This was especially important because executive reporting depended on identifying the most reliable generation assumption for each asset.
