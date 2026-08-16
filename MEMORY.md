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
- **[`pbip_poc/projects/`](file:///C:/Github/sql-practice/pbip_poc/projects/)**: Destination directory for Power BI Desktop `.pbip` project folders with native relative `.pbip` root launchers.

### 2. Validated PBIP & TMDL Engineering Rules (from `flat_sales_all`)
1. **TMDL Documentation Syntax**:
   - Descriptions on measures, columns, and tables **must** use triple-slash doc comments (`/// comment`) immediately preceding the declaration. Property `description: ...` is invalid in TMDL and triggers `UnknownKeyword`.
   - Never use multi-line indented `//` comment blocks inside table definitions; the TMDL scanner flags them as `Invalid indentation`. If a measure is disabled or not applicable, omit it entirely from the `.tmdl` file.
2. **Pandas Nullable Integer Casting (`pd.read_sql_query`)**:
   - SQLite tables contain NULLs for integers (e.g. `employee_id` for unassigned reps, `quantity`). Pandas defaults to `float64` (`3.0`, `NaN`), which causes VertiPaq type mismatch errors on startup.
   - **Rule**: All Python M partitions must pass explicit `dtype={'<col>': 'Int64', ...}` into `pd.read_sql_query` to return native nullable `Int64` vectors.
3. **Table Reference Registration**:
   - Every `.tmdl` table in `definition/tables/` (including `_measures.tmdl`) must have a corresponding `ref table <tableName>` declared in `definition/model.tmdl`.
4. **Local Cache & Settings Exclusion**:
   - `.pbi/cache.abf`, `.pbi/localSettings.json`, and `.pbi/editorSettings.json` are excluded via `.gitignore` to prevent stale VertiPaq binary deserialization failures across machines.
5. **Cross-Platform `.pbip` Launchers**:
   - Native root JSON `.pbip` files in `pbip_poc/projects/` point relatively to `subfolder/subfolder.Report`.

---

## 🔮 Next Steps & Actionable Backlog

### 🎯 Next Session Priority: Align Remaining PBIP Models
Apply the validated 4-step fix pattern from `flat_sales_all` to the remaining PBIP projects:

- [ ] **`pbip_poc/projects/flat_sales_completed/`**:
  - Update M partitions with explicit pandas `Int64` dtypes (`dtype={'...': 'Int64'}`).
  - Scope `_measures.tmdl` to only tables/columns available in this model.
  - Verify `definition/model.tmdl` table references.
  - Delete any local `.pbi/cache.abf` files and test in Power BI Desktop.
- [ ] **`pbip_poc/projects/oakhaven template/`**:
  - Apply `Int64` pandas dtypes across all M partitions (`fact_sales`, `dim_customer`, `dim_product`, `dim_employee`, `dim_calendar`).
  - Align column data types in `.tmdl` files (`int64`, `double`, `dateTime`).
  - Ensure measure dependencies match exact table names (e.g. `dim_product` vs `sql_dim_product`).
  - Test opening in Power BI Desktop.
- [ ] **`pbip_poc/projects/duplicated oakhaven template/`**:
  - Apply same schema & M dtype alignments.
  - Clean local `.pbi/cache.abf` and test.

### 📚 General Backlog
- [ ] Install/configure Beekeeper Studio for interactive SQLite querying against `project/oakhaven.db`.
- [ ] Compare TMDL & Git diffs across SQL Pushdown vs DAX vs Power Query M implementations.
- [ ] **Cross-Repo Porting**: Bring over anti-bloat & session memory strategies from external repos.

---

*Last Updated: 2026-08-16 | Branch: `main`*
