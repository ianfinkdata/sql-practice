# Power BI Projects (PBIP) — Semantic Modeling & Logic Sprawl

This directory contains the Power BI infrastructure for **Oakhaven**: `.pbip` projects, TMDL metadata, Python tooling, and a pipeline lineage engine — all backed by the SQLite source database at `project/oakhaven.db`.

---

## 🎯 The Core Problem This Solves

Extracting raw SQL statements after they've been shredded through Power Query M, TMDL metadata, `.pbip` folder structures, and GitHub commits is a painful, time-consuming process.

**The Solution:** Maintain a clean **`sql_queries/`** directory where **each model gets exactly 1 master `.sql` file**.
- Clear, commented table headers (`-- TABLE: table_name`) delineate individual queries.
- SQL code can be version-controlled directly alongside PBIP models.
- AI agents and developers can inspect business logic instantly without wasting time or tokens parsing deep TMDL / M code structures.

---

## 📁 Directory Structure

```
pbip/
├── README.md                        ← You are here
├── pyscripts/                       ← Python tooling (TMDL parser, linter, report manager, lineage)
│   ├── parse_tmdl.py                ← TMDL AST parser & DDL compiler
│   ├── pbip_linter.py               ← Lint .pbip projects for path issues & logic drift
│   ├── pbip_report.py               ← Report inspector, impact analyzer, template injector
│   ├── pbip_to_db.py                ← Extract clean SQL views from TMDL metadata
│   ├── pipeline_lineage.py          ← End-to-end medallion → PBIP lineage report
│   └── build_tmdl_db.py             ← Stand up tmdl_catalog.db from parsed schema
├── csharp/                          ← Tabular Editor C# scripts (.csx)
│   ├── apply_bpa_standards.cs       ← Bulk-apply BPA rules to semantic models
│   └── batch_add_measures.cs        ← Batch-inject DAX measures into TMDL
├── bpa/                             ← Best Practice Analyzer rules (JSON)
├── projects/                        ← .pbip project folders (Flat, Star, Template variants)
├── sql_queries/                     ← Master SQL source files (1 per model)
│   ├── 01_flat_model.sql            ← One Flat Table paradigm (denormalized)
│   └── 02_star_schema_model.sql     ← Star Schema paradigm (1 Fact + 4 Dims)
├── templates/                       ← Reusable TMDL & PBIR report templates
├── web_app/                         ← Pipeline visualizer (static HTML)
├── tmdl_parsed_schema.json          ← Full TMDL AST (generated)
├── tmdl_schema_ddl.sql              ← DDL compilation of TMDL (generated)
├── tmdl_catalog.db                  ← TMDL catalog database (generated)
├── extracted_views.sql              ← Clean SQL views extracted from TMDL (generated)
├── ai_usage_guide.md                ← Token optimization strategies for AI workflows
└── PIPELINE_LINEAGE.md              ← End-to-end data flow & lineage report
```

---

## 📊 Models & SQL Table Index

### 1. [`01_flat_model.sql`](sql_queries/01_flat_model.sql) (One Flat Table Paradigm)
*Designed for self-service or direct reporting models where all customer, product, employee, and sales fields are flattened into single queries.*

| Table Header in `.sql` | Target Row Count | Purpose & Business Logic |
| :--- | :---: | :--- |
| `flat_sales_all` | 100 rows | Main denormalized query. Contains SQL pushdown logic for `gross_amount`, `net_amount`, and `discount_tier`. |
| `flat_sales_completed_variant` | 100 rows | Logic sprawl variant. Demonstrates a second model using the same base query with a hardcoded `WHERE order_status = 'Completed'` filter. |

---

### 2. [`02_star_schema_model.sql`](sql_queries/02_star_schema_model.sql) (Traditional Star Schema)
*Designed for enterprise Power BI models with 1 central fact table joined to 4 dimension tables via 1:N relationships.*

| Table Header in `.sql` | Target Row Count | Relationship Key | Purpose |
| :--- | :---: | :---: | :--- |
| `fact_sales` | 100 rows | `order_id`, `order_line_id` | Central transaction fact table with order metrics. |
| `dim_customer` | ~58 rows | `customer_id` | Customer demographics, state, and segment. |
| `dim_product` | ~71 rows | `product_id` | Product catalog, categories, brand, cost, and price. |
| `dim_employee` | ~24 rows | `employee_id` | Sales rep region and department. |
| `dim_date` | ~15 rows | `datekey` | Date dimension attributes (year, month, quarter, day). |

*Note: Dimension row counts are dynamically scoped to match the 100 fact table rows.*

---

## 🧪 Testing Logic Sprawl Across Models

With these SQL source files, you can build 3 distinct PBIP models inside `projects/`:

1. **`Flat_SQL_Pushdown.pbip`**: Reads from `01_flat_model.sql` (`flat_sales_all`). Business logic is executed on the database engine.
2. **`Flat_DAX_Logic.pbip`**: Reads raw sales columns and implements `Gross Sales`, `Net Sales`, and `Discount Tiers` via DAX Calculated Columns / Measures.
3. **`Star_Schema_Enterprise.pbip`**: Reads from `02_star_schema_model.sql` and wires standard 1:N relationships in the Power BI semantic model.

Comparing the Git diffs across these PBIP folders demonstrates exactly how business logic sprawl, M code variations, and TMDL metadata diverge across models over time.

---

## 🔧 Tooling

### Python (`pyscripts/`)

| Script | Purpose |
|---|---|
| `parse_tmdl.py` | Recursively parses TMDL definitions → JSON AST + DDL compilation |
| `pbip_linter.py` | Lints `.pbip` projects for un-sanitized Windows paths and logic drift |
| `pbip_report.py` | PBIR report inspector, impact analyzer, and template page injector |
| `pbip_to_db.py` | Extracts clean SQL views from TMDL metadata definitions |
| `pipeline_lineage.py` | Generates end-to-end medallion → PBIP lineage report |
| `build_tmdl_db.py` | Stands up `tmdl_catalog.db` from parsed TMDL schema |

### C# / Tabular Editor (`csharp/`)

| Script | Purpose |
|---|---|
| `apply_bpa_standards.cs` | Bulk-apply Best Practice Analyzer rules to semantic models |
| `batch_add_measures.cs` | Batch-inject DAX measures into TMDL table definitions |

---

## 📋 Backlog

### P2 — XMLA Deployment Workflow
**Status:** Backlog
Plan a repeatable workflow for deploying semantic models to Power BI Service / Microsoft Fabric workspaces via `te deploy` and XMLA endpoints. Cover auth options, dry-run validation, CI/CD integration, and secret management.

### P2 — Script-Based Model Changes (C# / .csx)
**Status:** Backlog
Build a library of reusable C# scripts for programmatic TMDL model modifications via `te script`. Candidate operations: bulk-set descriptions, apply formatting strings, add/update DAX measures, enforce naming conventions, stamp lineage tags.

### P2 — Windows 11 Local PBIP Developer Workflow Guide
**Status:** Backlog (tracked in [GitHub Issue #2](https://github.com/ianfinkdata/sql-practice/issues/2))
Document the complete Windows 11 local developer loop combining CLI tooling (`pbip_report.py` & Tabular Editor CLI) with native Power BI Desktop rendering.
