# Generation Data Source of Truth

## Overview

![Header](assets/header.png)

This project was developed after I was promoted to work more closely with the company’s C-Level, especially the COO. At that point, generation data had become one of the most important operational and strategic datasets in the company, but it was still being managed through a highly manual Google Sheets file.

The original spreadsheet combined monthly generation data from solar assets, simulation outputs from PVSyst and the financial model, and meteorological assumptions from SolarGIS. Although this file was treated as the final reference for generation values, it had several structural issues: poor optimization, limited scalability, weak version control, and no reliable way to identify which simulation should be considered the most recent or trustworthy for each asset.

After an incorrect data point was reported to the COO, the need for a more robust structure became clear. This project was my first deep exposure to SQL and relational data modeling. I studied SQL intensively, redesigned the logic behind the spreadsheet, and created a structured data model to improve reliability, traceability, and analytical visibility.

The final output was a set of three core tables that became the company’s source of truth for generation data and were later used to feed Tableau reports for executive and operational analysis.

![Overview](assets/summary.png)

---

## Business Context

The company needed a reliable way to compare actual solar generation against different simulation scenarios across its distributed generation portfolio.

Before this project, the process depended on a complex spreadsheet that attempted to consolidate several different data sources:

* Actual monthly generation from operating assets
* PVSyst simulation outputs
* Financial model generation assumptions
* SolarGIS meteorological data
* Project metadata and installed capacity information
* Different simulation versions for the same asset

The main challenge was not only consolidating the data, but also defining which simulation should be used as the reliable benchmark for each project.

In many cases, the same asset had more than one PVSyst study, more than one financial model assumption, or updated meteorological inputs. Without version control, the risk of reporting outdated or inconsistent values was high.

---

## Problem

The original process had several limitations:

* No formal version control for simulations
* Multiple PVSyst or financial model references for the same project
* Low traceability of simulation assumptions
* High risk of using outdated generation benchmarks
* Poor scalability as the asset portfolio grew
* Manual checks distributed across a poorly optimized spreadsheet
* Limited visibility into the reliability of each simulation source
* Difficulty comparing actual generation against trusted benchmarks

Because the spreadsheet was used as the final reference for generation values, any inconsistency could directly affect executive reporting, operational prioritization, and decision-making.

---

## Objective

The objective was to transform a fragile spreadsheet-based process into a structured analytical data model capable of:

* Consolidating monthly generation data
* Controlling simulation versions by project
* Identifying the most reliable generation benchmark available
* Connecting actual generation to PVSyst, financial model, and SolarGIS assumptions
* Supporting Tableau reports used by leadership
* Improving data reliability, scalability, and traceability
* Creating a single source of truth for generation analysis

---

## Data Model

The solution was structured around three main tables:

1. `compiled_generation`
2. `generation_version_control`
3. `projects`

Together, these tables created a simple but scalable model for generation analysis.

---

## Tables

### `compiled_generation`

Fact table used to store monthly generation values.

**Granularity:** one row per project per month.

This table centralized the actual generation data used for performance analysis and comparison against simulation benchmarks.

Main purpose:

* Store monthly generation values
* Support actual vs expected generation analysis
* Enable historical tracking of asset performance
* Feed Tableau dashboards with consolidated generation data

Example fields may include:

* Project ID
* Reference month
* Generation Type (PVSyst, SGIS, Actual, Modeled)
* Generation Value (in kWh)
* Generation Version Control ID

---

### `generation_version_control`

Dimension table used to control simulation parameters and generation benchmark versions.

This was one of the most important parts of the project, because it allowed the company to track which simulation assumptions were being used for each asset and why.

The table was updated on demand whenever new simulations became available.

Main purpose:

* Track PVSyst simulation versions
* Track financial model assumptions
* Control P50, P90, and P95 values
* Identify who was responsible for the simulation
* Distinguish between EPC, internal construction team, and engineering team inputs
* Store SolarGIS meteorological basis
* Improve traceability of benchmark selection
* Support the selection of the most reliable simulation for each project

Example fields may include:

* Project ID
* Generation Type (PVSyst, SGIS, Actual, Modeled)
* Model Type (As-built,  Legacy, etc)
* Model Version (Used for referencing the Financial Model)
* Meteorological Database (MeteoNORM, NASA, SolarGIS, etc)
* Datasource (Referencing PVSyst files)
* P50 Generation (in kWh)
* P90 Generation (in kWh)

---

### `projects`

Dimension table containing project-level attributes.

This table provided the contextual information needed to analyze generation performance across different types of assets.

Main purpose:

* Store project metadata
* Connect generation data to asset characteristics
* Enable segmentation by project type, location, and installed capacity
* Support executive reporting and operational analysis

Example fields may include:

* Project ID
* Project name
* Installed capacity
* Project type
* Asset category
* Commercial operation date

---

## Reporting Layer

The structured tables were used to feed Tableau reports focused on asset performance and generation reliability.

The reports compared actual generation against the most reliable simulation benchmarks available for each project.

Main analyses included:

* Actual generation vs trusted simulation scenarios
* Generation deviations by project
* Portfolio-level generation performance
* Identification of underperforming assets
* Comparison between expected and realized generation
* Operational prioritization for O&M actions
* Visibility into potential distributor-related issues
* Availability and performance remediation opportunities

Although the reports were mainly directed to the COO and had limited company-wide distribution, they played an important role in executive analysis and operational decision-making.

---

## Business Impact

This project created a more reliable foundation for generation analysis across the company.

The main impact was not only the Tableau reporting layer, but the creation of a structured data model that became the source of truth for generation data.

Key results:

* Replaced a fragile spreadsheet process with a structured data model
* Created version control for generation simulations
* Improved traceability of PVSyst, financial model, and SolarGIS assumptions
* Reduced the risk of reporting outdated or incorrect generation benchmarks
* Enabled consistent actual vs expected generation analysis
* Supported executive decision-making for asset performance
* Helped identify projects with potential O&M, availability, or distributor-related issues
* Created a scalable structure for future portfolio growth

![Key-results](assets/key_results.png)

---

## Tools & Technologies

* SQL
* Google Sheets
* Tableau
* PVSyst
* SolarGIS
* Financial model data
* Relational data modeling
* Business analytics

---

## Project Outcomes

| Area                 | Outcome                                                                   |
| -------------------- | ------------------------------------------------------------------------- |
| Data Reliability     | Created a structured source of truth for generation data                  |
| Version Control      | Enabled tracking of multiple simulation versions by project               |
| Executive Reporting  | Supported Tableau reports used by the COO                                 |
| Operational Analysis | Helped identify underperforming assets and remediation priorities         |
| Scalability          | Replaced a manual spreadsheet logic with a more scalable data model       |
| Business Positioning | Strengthened the connection between analytics, leadership, and operations |

---

## What This Project Demonstrates

This project demonstrates my ability to:

* Translate an executive pain point into a structured data solution
* Learn and apply SQL to solve a real business problem
* Design analytical tables with clear business logic
* Build a source of truth for high-value operational data
* Connect technical implementation with decision-making needs
* Create visibility for asset performance and generation reliability
* Work across leadership, engineering, operations, and external data providers
* Improve processes under pressure after a reporting failure

---

## Repository Structure

```text
.
├── README.md
├── data_dictionary/
│   ├── compiled_generation.md
│   ├── generation_version_control.md
│   └── projects.md
├── sample_tables/
│   ├── compiled_generation_sample.csv
│   ├── generation_version_control_sample.csv
│   └── projects_sample.csv
└── assets/
    └── tableau_report_preview.png
```

---

## Disclaimer

The data used in this repository is anonymized and simplified for portfolio purposes.

The original project was developed in a business environment where generation data had direct relevance for executive reporting, asset performance analysis, and operational decision-making.
