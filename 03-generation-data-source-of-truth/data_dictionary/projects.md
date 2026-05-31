# Table: `projects`

## Description

`projects` is a dimension table used to store project-level attributes for each solar asset.

It provides the contextual information required to analyze generation performance by asset, location, installed capacity, project type and operational characteristics.

This table connects generation values and simulation benchmarks to the underlying physical and commercial characteristics of each project.

---

## Granularity

One row per project.

Each row represents a unique solar asset or distributed generation project in the company’s portfolio.

---

## Primary Key

Suggested primary key:

```text
project_id
```

---

## Relationships

| Column       | References                              | Relationship Type |
| ------------ | --------------------------------------- | ----------------- |
| `project_id` | `compiled_generation.project_id`        | One-to-many       |
| `project_id` | `generation_version_control.project_id` | One-to-many       |

---

## Columns

| Column                      | Type      | Nullable | Description                                          | Example               |
| --------------------------- | --------- | -------: | ---------------------------------------------------- | --------------------- |
| `project_id`                | string    |       No | Unique project identifier.                           | `PRJ_001`             |
| `project_name`              | string    |       No | Project or asset name.                               | `Solar Plant Alpha`   |
| `installed_capacity_kwp`    | numeric   |       No | Installed capacity of the project in kWp.            | `1250.00`             |
| `project_type`              | string    |      Yes | Technical or installation type of the project.       | `Ground-mounted`      |
| `asset_category`            | string    |      Yes | Business or operational category of the asset.       | `Remote Generation`   |
| `commercial_operation_date` | date      |      Yes | Date when the project started commercial operation.  | `2023-08-01`          |
| `state`                     | string    |      Yes | State where the project is located.                  | `MG`                  |
| `city`                      | string    |      Yes | City where the project is located.                   | `Uberlândia`          |
| `distributor`               | string    |      Yes | Electricity distributor associated with the project. | `Distributor A`       |
| `operational_status`        | string    |      Yes | Current operational status of the asset.             | `Operational`         |
| `created_at`                | timestamp |      Yes | Date and time when the record was created.           | `2024-01-10 09:00:00` |
| `updated_at`                | timestamp |      Yes | Date and time when the record was last updated.      | `2024-02-01 11:15:00` |

---

## Accepted Values

### `project_type`

Suggested accepted values:

| Value            | Meaning                                        |
| ---------------- | ---------------------------------------------- |
| `Ground-mounted` | Solar plant installed on the ground.           |
| `Roof-mounted`   | Solar system installed on a rooftop.           |
| `Carport`        | Solar system installed on a parking structure. |
| `Other`          | Other installation type.                       |

---

### `asset_category`

Suggested accepted values:

| Value                | Meaning                                                           |
| -------------------- | ----------------------------------------------------------------- |
| `Remote Generation`  | Distributed generation asset used for remote energy compensation. |
| `On-site Generation` | Asset installed directly at the consumption site.                 |
| `Shared Generation`  | Asset associated with shared generation arrangements.             |
| `Other`              | Other business category.                                          |

---

### `operational_status`

Suggested accepted values:

| Value                | Meaning                                |
| -------------------- | -------------------------------------- |
| `Operational`        | Asset is operating commercially.       |
| `Under Construction` | Asset is still under construction.     |
| `Commissioning`      | Asset is undergoing commissioning.     |
| `Inactive`           | Asset is not currently active.         |
| `Decommissioned`     | Asset has been removed from operation. |

---

## Business Rules

* Each project must have a unique `project_id`.
* `installed_capacity_kwp` must represent the project’s installed DC capacity.
* Every generation record in `compiled_generation` must be linked to a valid project.
* Every simulation version in `generation_version_control` must be linked to a valid project.
* `commercial_operation_date` should be populated for operational assets.
* Operational reports should use this table to segment generation performance by capacity, project type, location and distributor.
* Project metadata should be maintained separately from generation records to avoid duplicated information in the fact table.

---

## Data Quality Checks

| Check                           | Expected Result                                                                                            |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Unique `project_id`             | Each project must appear only once in the table.                                                           |
| Non-null project name           | Every project should have a defined name.                                                                  |
| Positive installed capacity     | `installed_capacity_kwp` should be greater than zero.                                                      |
| Valid operational status        | Status should belong to the accepted list.                                                                 |
| Valid commercial operation date | Operational assets should have a defined commercial operation date.                                        |
| Valid relationship coverage     | Projects referenced in generation or simulation tables should exist in this table.                         |
| No conflicting metadata         | The same project should not have conflicting capacity, location or distributor information across sources. |

---

## Notes

This table uses anonymized and simplified data for portfolio purposes.

In the original business context, project metadata was essential to connect generation performance with operational characteristics such as installed capacity, project type, location and distributor exposure.
