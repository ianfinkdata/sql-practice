---
name: scan-db-sql-files
description: >-
  Use when the user wants to scan, list, catalog, or inspect all SQLite database (.db) and SQL source (.sql)
  files across the repository — phrases like "scan db and sql files", "list sql files", "catalog databases",
  "show all .db and .sql files", "get list of sql files", or "fire open db and sql catalog in a new terminal".
  Provides CLI filtering, JSON/CSV exports, and opens an ANSI-formatted dashboard in a new placed Ptyxis terminal.
---

# Repository Database (.db) & SQL (.sql) Catalog

This skill provides an automated scanner and complete inventory of all SQLite database files (`.db`) and SQL scripts/views (`.sql`) across the repository. It categorizes files by architectural layer (Medallion bronze/silver/gold, portfolio patterns, PBIP models), verifies schema metadata, and launches on-screen terminal dashboards.

---

## 🎯 When to Use This Skill

Activate this skill when:
- Gathering an up-to-date inventory of all SQLite databases and SQL scripts in the repository.
- Inspecting the schema layout, row counts, table names, and views of `project/oakhaven.db` or `pbip/tmdl_catalog.db`.
- Locating specific SQL patterns in `portfolio/` or Medallion view definitions in `project/`.
- Launching an interactive catalog terminal window placed on-screen alongside your IDE.

---

## 🚀 CLI Commands & Workflows

Always run commands from the repository root:

### 1. View Formatted Catalog in Current Terminal
```bash
./scripts/scan-db-sql.sh --render
```
*(Or invoke the Python engine directly: `python3 scripts/scan_db_sql.py --render`)*

### 2. Launch in a Dedicated Placed Terminal Window
To open a new 105×45 Ptyxis window (positioned at top-left via [`scripts/lib/ptyxis-place.sh`](../../scripts/lib/ptyxis-place.sh)) and drop into an interactive shell:
```bash
./scripts/scan-db-sql-terminal.sh
```
*(Or simply run `./scripts/scan-db-sql.sh` without arguments).*

### 3. Filter by File Type or Architectural Layer
```bash
# Only SQLite databases
./scripts/scan-db-sql.sh --type db

# Only SQL files
./scripts/scan-db-sql.sh --type sql

# Filter by Medallion layer or pattern category
./scripts/scan-db-sql.sh --layer gold
./scripts/scan-db-sql.sh --layer silver
./scripts/scan-db-sql.sh --layer bronze
./scripts/scan-db-sql.sh --layer portfolio
./scripts/scan-db-sql.sh --layer pbip
```

### 4. Machine-Readable Export (JSON & CSV)
```bash
# Structured JSON for automated tooling or agent parsing
./scripts/scan-db-sql.sh --json

# CSV format for spreadsheets or reporting
./scripts/scan-db-sql.sh --csv > sql_db_catalog.csv
```

---

## 📦 Verified Database Files (`.db`) — 2 Files

| Database File | Size | Schema Summary |
| :--- | :---: | :--- |
| [`project/oakhaven.db`](../../project/oakhaven.db) | 1.36 MB | **5 physical tables, 13 views, 20,455 total records**. Main practice database with Medallion architecture (Bronze tables, Silver cleaning views, Gold star-schema views). *(Read-only)* |
| [`pbip/tmdl_catalog.db`](../../pbip/tmdl_catalog.db) | 20.21 MB | **50 physical tables, 265,757 total records**. Catalog database indexing Power BI TMDL schemas, measures, and visual query AST bindings. |

---

## 📄 Verified SQL Source & View Files (`.sql`) — 38 Files

### 1. Medallion Project Views (`project/`)

#### Bronze Layer (Raw Ingestion & DDL)
* [`project/bronze/schema.sql`](../../project/bronze/schema.sql) *(74L, 2.1 KB)* — DDL defining bronze tables (`bronze_customers`, `bronze_employees`, `bronze_products`, `bronze_sales`, `bronze_calendar`).
* [`project/bronze/calendar_recursive_cte.sql`](../../project/bronze/calendar_recursive_cte.sql) *(23L, 684 B)* — Recursive CTE generating the raw calendar date spine (2018–2026).

#### Silver Layer (Data Cleaning & Quality)
* [`project/silver/silver_calendar.sql`](../../project/silver/silver_calendar.sql) *(12L, 435 B)* — Date dimension cleaning view.
* [`project/silver/silver_customers.sql`](../../project/silver/silver_customers.sql) *(87L, 4.7 KB)* — Standardized customer emails, phone formats, and categorical states.
* [`project/silver/silver_employees.sql`](../../project/silver/silver_employees.sql) *(63L, 2.5 KB)* — Cleaned employee hierarchy, commission tiers, and statuses.
* [`project/silver/silver_products.sql`](../../project/silver/silver_products.sql) *(66L, 2.5 KB)* — Standardized product pricing, unit costs, and categories.
* [`project/silver/silver_sales.sql`](../../project/silver/silver_sales.sql) *(82L, 3.3 KB)* — Recomputed `net_amount`, date parsing, and orphan tracking flags.

#### Gold Layer (Star Schema & Aggregations)
* [`project/gold/dim_customer.sql`](../../project/gold/dim_customer.sql) *(19L, 456 B)* — Conformed customer dimension.
* [`project/gold/dim_date.sql`](../../project/gold/dim_date.sql) *(27L, 1.3 KB)* — Calendar dimension with derived fiscal offsets.
* [`project/gold/dim_employee.sql`](../../project/gold/dim_employee.sql) *(18L, 432 B)* — Sales rep dimension.
* [`project/gold/dim_product.sql`](../../project/gold/dim_product.sql) *(19L, 398 B)* — Product catalog dimension.
* [`project/gold/fact_sales.sql`](../../project/gold/fact_sales.sql) *(31L, 1.0 KB)* — Star-schema sales fact table view.
* [`project/gold/agg_customer_ltv.sql`](../../project/gold/agg_customer_ltv.sql) *(19L, 722 B)* — Customer lifetime value rollup.
* [`project/gold/agg_daily_sales.sql`](../../project/gold/agg_daily_sales.sql) *(25L, 977 B)* — Daily sales rollup with zero-activity day filling.
* [`project/gold/agg_monthly_sales_by_category.sql`](../../project/gold/agg_monthly_sales_by_category.sql) *(21L, 837 B)* — Monthly category performance aggregation.

---

### 2. Portfolio Patterns (`portfolio/`)

#### 01-bronze-ingestion-patterns
* [`portfolio/01-bronze-ingestion-patterns/deduplication-with-row-number.sql`](../../portfolio/01-bronze-ingestion-patterns/deduplication-with-row-number.sql) *(121L, 5.5 KB)* — Deduplication with `ROW_NUMBER()`.
* [`portfolio/01-bronze-ingestion-patterns/detecting-orphan-foreign-keys.sql`](../../portfolio/01-bronze-ingestion-patterns/detecting-orphan-foreign-keys.sql) *(99L, 5.0 KB)* — Orphan detection using `LEFT JOIN ... WHERE ... IS NULL`.

#### 02-silver-cleaning-patterns
* [`portfolio/02-silver-cleaning-patterns/recompute-dont-trust-the-total.sql`](../../portfolio/02-silver-cleaning-patterns/recompute-dont-trust-the-total.sql) *(141L, 7.5 KB)* — Recomputing derived measures over untrustworthy stored totals.
* [`portfolio/02-silver-cleaning-patterns/standardizing-inconsistent-categoricals.sql`](../../portfolio/02-silver-cleaning-patterns/standardizing-inconsistent-categoricals.sql) *(135L, 6.4 KB)* — Normalizing mixed casing and abbreviations.
* [`portfolio/02-silver-cleaning-patterns/standardizing-mixed-booleans.sql`](../../portfolio/02-silver-cleaning-patterns/standardizing-mixed-booleans.sql) *(92L, 4.1 KB)* — Normalizing boolean variations (`1/0`, `T/F`, `Y/N`).
* [`portfolio/02-silver-cleaning-patterns/type-casting-and-validation.sql`](../../portfolio/02-silver-cleaning-patterns/type-casting-and-validation.sql) *(134L, 6.5 KB)* — Parsing dirty numeric strings and mixed date formats.

#### 03-date-dimension-patterns
* [`portfolio/03-date-dimension-patterns/date-spine-left-join-zero-activity-days.sql`](../../portfolio/03-date-dimension-patterns/date-spine-left-join-zero-activity-days.sql) *(107L, 5.2 KB)* — Continuous date spine left joins.
* [`portfolio/03-date-dimension-patterns/fiscal-calendar-derivations.sql`](../../portfolio/03-date-dimension-patterns/fiscal-calendar-derivations.sql) *(123L, 6.6 KB)* — Deriving fiscal years, quarters, and offsets.
* [`portfolio/03-date-dimension-patterns/recursive-cte-calendar-generation.sql`](../../portfolio/03-date-dimension-patterns/recursive-cte-calendar-generation.sql) *(118L, 5.6 KB)* — Generating date ranges dynamically.

#### 04-dimensional-modeling-patterns
* [`portfolio/04-dimensional-modeling-patterns/conformed-dimension-scd-type-1.sql`](../../portfolio/04-dimensional-modeling-patterns/conformed-dimension-scd-type-1.sql) *(112L, 5.8 KB)* — SCD Type 1 overwrite pattern.
* [`portfolio/04-dimensional-modeling-patterns/scd-type-2-history-tracking.sql`](../../portfolio/04-dimensional-modeling-patterns/scd-type-2-history-tracking.sql) *(128L, 7.0 KB)* — SCD Type 2 effective date range tracking.
* [`portfolio/04-dimensional-modeling-patterns/star-schema-fact-table-template.sql`](../../portfolio/04-dimensional-modeling-patterns/star-schema-fact-table-template.sql) *(129L, 6.8 KB)* — Fact table transformation template.
* [`portfolio/04-dimensional-modeling-patterns/surrogate-key-generation.sql`](../../portfolio/04-dimensional-modeling-patterns/surrogate-key-generation.sql) *(106L, 5.6 KB)* — Deterministic surrogate key hashing and sequences.

#### 05-analytical-query-patterns
* [`portfolio/05-analytical-query-patterns/cohort-analysis.sql`](../../portfolio/05-analytical-query-patterns/cohort-analysis.sql) *(134L, 6.2 KB)* — Monthly user retention matrix.
* [`portfolio/05-analytical-query-patterns/customer-lifetime-value.sql`](../../portfolio/05-analytical-query-patterns/customer-lifetime-value.sql) *(102L, 5.4 KB)* — RFM and cumulative LTV rollups.
* [`portfolio/05-analytical-query-patterns/period-over-period-with-lag.sql`](../../portfolio/05-analytical-query-patterns/period-over-period-with-lag.sql) *(91L, 4.4 KB)* — MoM / YoY growth calculations using `LAG()`.
* [`portfolio/05-analytical-query-patterns/running-totals-and-moving-averages.sql`](../../portfolio/05-analytical-query-patterns/running-totals-and-moving-averages.sql) *(100L, 4.5 KB)* — Rolling window calculations.
* [`portfolio/05-analytical-query-patterns/top-n-per-group.sql`](../../portfolio/05-analytical-query-patterns/top-n-per-group.sql) *(97L, 4.6 KB)* — Group ranking with `DENSE_RANK()`.

#### 05-bi-integration
* [`portfolio/05-bi-integration/sql-pushdown-vs-dax.sql`](../../portfolio/05-bi-integration/sql-pushdown-vs-dax.sql) *(55L, 2.5 KB)* — SQL Pushdown views vs DAX semantic measures.

---

### 3. Power BI & TMDL Integration (`pbip/`)
* [`pbip/extracted_views.sql`](../../pbip/extracted_views.sql) *(770L, 22.1 KB)* — Consolidated semantic views pushdown script.
* [`pbip/sql_queries/01_flat_model.sql`](../../pbip/sql_queries/01_flat_model.sql) *(71L, 2.5 KB)* — One-Flat-Table staging queries.
* [`pbip/sql_queries/02_star_schema_model.sql`](../../pbip/sql_queries/02_star_schema_model.sql) *(110L, 3.2 KB)* — Star-schema relational queries.
* [`pbip/tmdl_schema_ddl.sql`](../../pbip/tmdl_schema_ddl.sql) *(3,117L, 136.7 KB)* — Auto-generated catalog schema and metadata tables.
