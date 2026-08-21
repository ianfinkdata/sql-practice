# Workspace Memory & Session State

This document maintains a persistent log of ongoing session context, project architecture decisions, and current work state across chat sessions.

---

## 📌 Project Overview
- **Repository**: [`sql-practice`](https://github.com/ianfinkdata/sql-practice)
- **Main Practice Database**: [`project/oakhaven.db`](project/oakhaven.db) (SQLite, 12k sales records, pre-built Medallion pipeline: Bronze → Silver → Gold).
- **PBIP Directory**: [`pbip/`](pbip/README.md)

---

## 🛠️ Current State & Completed Work

### 1. Power BI Project (PBIP) Setup
Dedicated directory structure for Power BI `.pbip` models, TMDL metadata, and Git diff workflows:

- **[`pbip/README.md`](pbip/README.md)**: Main PBIP documentation, table index, directory map, and backlog.
- **[`pbip/ai_usage_guide.md`](pbip/ai_usage_guide.md)**: Token optimization strategies and AI usage guide.
- **[`pbip/sql_queries/01_flat_model.sql`](pbip/sql_queries/01_flat_model.sql)**: One-Flat-Table reporting queries with embedded SQL logic (`gross_amount`, `net_amount`, `discount_tier`) and business logic sprawl variants.
- **[`pbip/sql_queries/02_star_schema_model.sql`](pbip/sql_queries/02_star_schema_model.sql)**: 1 Fact table (`fact_sales`) + 4 Dimension tables (`dim_customer`, `dim_product`, `dim_employee`, `dim_date`).
- **[`pbip/projects/`](pbip/projects/)**: Power BI Desktop `.pbip` project folders with native relative `.pbip` root launchers.

### 2. Validated PBIP & TMDL Engineering Rules
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
   - Native root JSON `.pbip` files in `pbip/projects/` point relatively to `subfolder/subfolder.Report`.

### 3. Model Alignment Status
- [x] **`pbip/projects/flat_sales_all/`**: Explicit `Int64` dtypes, scoped `_measures.tmdl`, absolute SQLite path, verified working in Power BI Desktop.
- [x] **`pbip/projects/flat_sales_completed/`**: Explicit `Int64` dtypes, scoped `_measures.tmdl`, absolute SQLite path, verified working.
- [x] **`pbip/projects/oakhaven template/`**: Explicit `Int64` dtypes across all partitions, scoped `_measures.tmdl`, aligned column types (`int64`, `double`, `dateTime`), verified working.
- [x] **`pbip/projects/duplicated oakhaven template/`**: Explicit `Int64` dtypes across all partitions, scoped `_measures.tmdl`, aligned column types (`int64`, `double`, `dateTime`), verified working.

### 4. Workflow Concepts & Architecture Patterns

#### 💡 Drive Projects $\rightarrow$ Gemini Notebook (NotebookLM) Sandbox & Versioning
- **Phase 1 (Sandbox & Refinement in Drive Projects)**:
  - Use **Google Drive Projects** to organize folders and Google Docs as living scratchpads.
  - Sandbox, iterate, and refine source documentation, query snippets, and agent findings directly in Docs/Drive.
- **Phase 2 (Deep Synthesis in Gemini Notebook / NotebookLM)**:
  - Ingest finalized Google Docs/files into **Gemini Notebook (NotebookLM)** to leverage grounded Q&A, synthesis, cross-document analysis, and audio overviews.
- **Phase 3 (Version Control Lite for Assets)**:
  - The notebook serves as a lightweight snapshot and version-control layer for generated assets and documentation revisions as newer iterations emerge.

---

## 🔮 Next Steps & Actionable Backlog

### 🚀 Enhancements Backlog
- [ ] **Parameterize SQLite source path in Power Query M**:
  - Dynamically inject the `oakhavendatabasepath` parameter into `Python.Execute` scripts (using `""" & Text.Replace(oakhavendatabasepath, "\", "\\") & """` or M concatenation) so users can customize the SQLite database path via Power BI Desktop's *Edit Parameters* UI without modifying individual table partition queries.

### 📚 General Backlog
- [ ] Install/configure Beekeeper Studio for interactive SQLite querying against `project/oakhaven.db`.
- [ ] Compare TMDL & Git diffs across SQL Pushdown vs DAX vs Power Query M implementations.
- [ ] Explore automated CI validation of TMDL schemas and AST parser checks on PR.

---

*Last Updated: 2026-08-20 | Branch: `main`*

