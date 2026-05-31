# Table: `compiled_generation`

## Description

`compiled_generation` is the fact table used to store monthly generation records for each project. 

The table follows a long-format analytical design, where actual and benchmark scenarios are stored as generation records distinguished by generation_type.

It consolidates actual and simulated generation values in a structured format, allowing the company to compare realized generation against different benchmark scenarios such as PVSyst, SolarGIS and financial model assumptions.

This table was designed to replace spreadsheet-based generation controls and support Tableau reports used for executive and operational analysis.

---

## Granularity

One row per:

* Project
* Reference month
* Generation type
* Generation version, when applicable

In practical terms, each row represents a monthly generation value for a given project and generation scenario.

Examples:

* Actual generation for Project A in January 2024
* PVSyst P50 generation for Project A in January 2024
* SolarGIS-based expected generation for Project B in March 2024

---

## Primary Key

Primary key:

```text
id
```

The `id` column was created specifically as a row-level identifier and is populated using a row number logic, ensuring that each record has a unique primary key.

Business uniqueness can still be represented by the following combination of fields:

```text
project_id + reference_month + generation_type + generation_version_control_id
```

---

## Relationships

| Column                          | References                                                 | Relationship Type |
| ------------------------------- | ---------------------------------------------------------- | ----------------- |
| `project_id`                    | `projects.project_id`                                      | Many-to-one       |
| `generation_version_control_id` | `generation_version_control.generation_version_control_id` | Many-to-one       |

---

## Columns

| Column                          | Type      | Nullable | Description                                                                                         | Example               |
| ------------------------------- | --------- | -------- | --------------------------------------------------------------------------------------------------- | --------------------- |
| `id`                            | integer   | No       | Primary key generated using a row number. Unique identifier for each record.                        | `1`                   |
| `project_id`                    | string    | No       | Unique identifier of the project.                                                                   | `PRJ_001`             |
| `reference_month`               | date      | No       | Month related to the generation value. Usually stored as the first day of the month.                | `2024-01-01`          |
| `generation_type`               | string    | No       | Type of generation record. Used to distinguish actual generation from different simulation sources. | `Actual`              |
| `generation_value_kwh`          | numeric   | No       | Monthly generation value in kWh.                                                                    | `154320.75`           |
| `generation_version_control_id` | string    | Yes      | Reference to the simulation or benchmark version used for the generation value.                     | `GVC_0001`            |
| `created_at`                    | timestamp | Yes      | Date and time when the record was created.                                                          | `2024-02-05 10:35:00` |
| `updated_at`                    | timestamp | Yes      | Date and time when the record was last updated.                                                     | `2024-02-06 15:20:00` |

---

## Accepted Values

### `generation_type`

Suggested accepted values:

| Value             | Meaning                                                    |
| ----------------- | ---------------------------------------------------------- |
| `Actual`          | Real generation measured from the asset.                   |
| `PVSyst`          | Simulated generation based on a PVSyst study.              |
| `SolarGIS`        | Expected generation based on SolarGIS meteorological data. |
| `Modeled`         | Internally modeled or adjusted generation scenario.        |

---

## Business Rules

* The `id` column must be unique for every record and serves as the table primary key.
* Actual generation records should represent measured generation from operating assets.
* Simulated generation records should be linked to a valid `generation_version_control_id`.
* `generation_value_kwh` must always be stored in kWh.
* `reference_month` should be normalized as a monthly date, preferably using the first day of the month.
* For actual generation, `generation_version_control_id` may be null if no simulation benchmark is directly associated with the record.
* For PVSyst, SolarGIS, financial model or internally modeled scenarios, `generation_version_control_id` should not be null.
* A project may have multiple generation records for the same month if they represent different generation types or simulation versions.
* Tableau reports should use this table as the central fact table for actual vs expected generation analysis.

---

## Data Quality Checks

| Check                                  | Expected Result                                                                                    |
| -------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Unique `id`                            | Every record must have a unique primary key value.                                                 |
| `project_id` exists in `projects`      | Every generation record must be linked to a valid project.                                         |
| `generation_value_kwh >= 0`            | Generation values should not be negative.                                                          |
| `reference_month` is valid             | Every record must be associated with a valid month.                                                |
| `generation_type` is valid             | Values should belong to the accepted list of generation types.                                     |
| Simulated records have version control | PVSyst, SolarGIS, financial model and modeled records should reference a valid simulation version. |
| No unintended duplicates               | The same project, month, generation type and version should not be duplicated.                     |

---

## Notes

This table uses anonymized and simplified data for portfolio purposes.

The structure mirrors the business logic of the original project, where generation data became a source of truth for executive reporting and asset performance analysis.
