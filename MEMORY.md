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

### 2. GitHub Pages Site Generator (`build_pages.py`)
- **Dynamic Link Resolution Fix**: Updated `convert_link_path` to dynamically resolve markdown relative targets against the repository root (`REPO_ROOT`). Only references pointing to root `README.md` map to `index.html`, fixing 404 errors on subfolder README navigation links (e.g. `curriculum/00-orientation/README.html` -> `curriculum/README.html`).

### 3. Home Page & Documentation Adjustments
- **Deprioritized Python Database Generation**: Rewrote [`README.md`](file:///home/ian/github/sql-practice/README.md) / [`docs/index.html`](file:///home/ian/github/sql-practice/docs/index.html) to emphasize that `project/oakhaven.db` is pre-built and ready to open with zero setup. Replaced inline bash generation blocks with a closing footnote linking to the [Python Database Generation Guide](curriculum/00-orientation/03-tools-and-setup.md#building-the-database-yourself-optional) and referencing the built-in [`setup-database`](.agents/skills/setup-database/SKILL.md) skill.

### 4. Core Conventions Established
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

*Last Updated: 2026-08-09 | Branch: `main`*
