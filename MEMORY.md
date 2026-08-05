# Workspace Memory & Session State

This document maintains a persistent log of ongoing session context, project architecture decisions, and current work state across chat sessions.

---

## 📌 Project Overview
- **Repository**: [`sql-practice`](file:///C:/Github/sql-practice) (`https://github.com/ianfinkdata/sql-practice.git`)
- **Main Practice Database**: [`project/oakhaven.db`](file:///C:/Github/sql-practice/project/oakhaven.db) (SQLite, 12k sales records, pre-built Medallion pipeline: Bronze → Silver → Gold).
- **PoC Working Directory**: [`pbip_poc/`](file:///C:/Github/sql-practice/pbip_poc/readme_pbip_poc.md)

---

## 🛠️ Current State & Completed Work

### 1. Power BI Project (PBIP) Proof of Concept Setup
Created a dedicated directory structure for testing Power BI `.pbip` models, TMDL metadata, and Git diff workflows:

- **[`pbip_poc/readme_pbip_poc.md`](file:///C:/Github/sql-practice/pbip_poc/readme_pbip_poc.md)**: Main PoC documentation, table index, and directory map.
- **[`pbip_poc/ai_usage_guide.md`](file:///C:/Github/sql-practice/pbip_poc/ai_usage_guide.md)**: Token optimization strategies and AI usage guide.
- **[`pbip_poc/sql_queries/01_flat_model.sql`](file:///C:/Github/sql-practice/pbip_poc/sql_queries/01_flat_model.sql)**: Single SQL file containing One-Flat-Table reporting queries with embedded SQL logic (`gross_amount`, `net_amount`, `discount_tier`) and business logic sprawl variants.
- **[`pbip_poc/sql_queries/02_star_schema_model.sql`](file:///C:/Github/sql-practice/pbip_poc/sql_queries/02_star_schema_model.sql)**: Single SQL file containing 1 Fact table (`fact_sales`) + 4 Dimension tables (`dim_customer`, `dim_product`, `dim_employee`, `dim_date`).
- **[`pbip_poc/projects/`](file:///C:/Github/sql-practice/pbip_poc/projects/)**: Destination directory for Power BI Desktop `.pbip` project folders.

### 2. Core Conventions Established
- **Single SQL File Per Model**: Keep model SQL consolidated in 1 `.sql` file with commented headers (`-- TABLE: table_name`) to prevent token bloat from parsing raw TMDL/PBIP metadata.
- **Capped Row Counts**: Capped PoC query datasets to 100 rows for fast testing and small payloads.
- **Git Strategy**: Committing directly to `main` for simple, streamlined progress without extra branch noise.

---

## 🔮 Next Steps & Ideas Log
- [ ] Install/configure Beekeeper Studio for interactive SQLite querying against `project/oakhaven.db`.
- [ ] Create PBIP models in Power BI Desktop and save into `pbip_poc/projects/`.
- [ ] Compare TMDL & Git diffs across SQL Pushdown vs DAX vs Power Query M implementations.
- [ ] **Cross-Repo Porting**: Bring over anti-bloat & session memory strategies from external repos.

---

*Last Updated: 2026-08-04 | Branch: `main`*
