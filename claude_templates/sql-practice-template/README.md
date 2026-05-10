# SQL Practice Template

A MySQL SQL learning project template. Clone or copy this folder, rename placeholders, and work through the exercises in order. The project follows a **medallion architecture** (Bronze → Silver → Gold) and covers DDL, DML, JSON handling, CTEs, and window functions.

---

## Quick Start

1. Open MySQL Workbench (or your preferred client)
2. Create your schemas:
   ```sql
   CREATE SCHEMA IF NOT EXISTS your_schema_name;
   CREATE SCHEMA IF NOT EXISTS common_db;
   ```
3. Build shared infrastructure — run these in order:
   - `common_db/date_recursion.sql`
   - `common_db/weekstart_adds.sql`
4. Start the exercises at `1-DDL_AND_DML/SQL/01-schema-setup.sql`

> **Find and replace:** Search for `[your_schema]` across all `.sql` files and replace with your actual schema name before running anything.

---

## Prerequisites

- MySQL 8.0 or higher (window functions, `JSON_TABLE`, and recursive CTEs required)
- A MySQL client (MySQL Workbench, DBeaver, DataGrip, or CLI)
- The `common_db` schema must be set up before any exercises run

---

## Data Model

You will build and enrich these three Bronze tables:

```
[your_schema].customers
  customer_id      INT (PK)
  contact_details  JSON        -- [{type, value}, ...] array
  customer_name    VARCHAR(50)
  region           VARCHAR(50)

[your_schema].sales
  sale_id          INT
  sale_date        DATE
  customer_id      INT
  rep_id           INT
  sale_amount      DECIMAL(10,2)

[your_schema].sales_rep
  rep_id           INT
  rep_name         VARCHAR(50)
  commission_rate  DECIMAL(4,2)
```

---

## Project Structure

```
sql-practice-template/
├── CLAUDE.md                        # AI assistant instructions (read before asking for help)
├── README.md                        # This file
├── .gitignore
│
├── common_db/                       # Shared infrastructure — build FIRST
│   ├── date_recursion.sql           # dim_date calendar table (2019–2031)
│   ├── weekstart_adds.sql           # Add week/month columns to dim_date
│   └── number_recursion.sql         # Optional: integer sequence utility table
│
├── 1-DDL_AND_DML/                   # Exercise 1: Build your schema from scratch
│   ├── Data/                        # Drop your CSV snapshots here for reference
│   └── SQL/
│       ├── 01-schema-setup.sql      # Create tables and insert seed data
│       └── 02-enrichment.sql        # Rename, add columns, populate with UPDATE CASE
│
├── 2-Transformations/               # Exercise 2: Build Silver views step by step
│   ├── data/                        # Expected output CSVs per step
│   └── SQL/
│       ├── 01-json-cte.sql          # Extract structured data from JSON column
│       ├── 02-join-enrich.sql       # Join tables, add derived columns
│       ├── 03-case-window.sql       # CASE statements + RANK() window function
│       ├── 04-silver-view.sql       # CREATE OR REPLACE VIEW silver_*
│       └── 05-gold-view.sql         # Aggregate Silver into gold_* view
│
└── 3-Time_Intelligence/             # Exercise 3: Time-aware analytics
    ├── data/                        # Expected output CSVs
    └── SQL/
        ├── 01-self-join-prior-month.sql    # Prior month via self-join (no window functions)
        ├── 02-window-lag-ytd.sql           # LAG() + YTD with PARTITION BY YEAR
        ├── 03-calendar-join-daily.sql      # Join to dim_date, fill zero-sales days
        └── 04-rolling-avg-regional.sql     # ROWS BETWEEN + regional partition
```

---

## Exercise Guide

### Exercise 1 — DDL & DML

Goal: Build three tables and make them useful.

| Phase | Task | SQL Feature |
|-------|------|-------------|
| 1 | Rename columns to meaningful names | `ALTER TABLE ... RENAME COLUMN` |
| 2 | Add missing columns with correct types | `ALTER TABLE ... ADD COLUMN` |
| 3 | Populate rows using conditional logic | `UPDATE ... SET ... CASE WHEN` |

### Exercise 2 — Advanced Transformations

Goal: Build a Silver view layer incrementally. Each file adds one concept.

| Step | Concept added |
|------|--------------|
| 01 | `JSON_TABLE` to flatten contact details |
| 02 | `LEFT JOIN` + interval math for `sale_month` |
| 03 | `CASE` for deal category + `RANK() OVER(PARTITION BY)` |
| 04 | Wrap in `CREATE OR REPLACE VIEW silver_*` |
| 05 | Aggregate Silver into `gold_*` with `SUM OVER(PARTITION BY)` |

### Exercise 3 — Time Intelligence

Goal: Answer "how does this period compare to last period?" three different ways.

| File | Approach | Constraint |
|------|----------|-----------|
| 01 | Self-join on date column | No window functions |
| 02 | `LAG()` + YTD cumulative | No self-joins |
| 03 | Calendar table join | Fill zero-sales days |
| 04 | `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | Regional partition |

---

## Key Concepts by File

| Concept | Where practiced |
|---------|----------------|
| `ALTER TABLE` (rename, add, modify) | Exercise 1, Phase 1–2 |
| `UPDATE ... CASE WHEN` | Exercise 1, Phase 3 |
| `JSON_TABLE` + `CROSS JOIN` | Exercise 2, Step 01 |
| Recursive CTEs | `common_db/date_recursion.sql` |
| Interval month math | Exercise 2, Step 02 |
| `RANK()` window function | Exercise 2, Step 03 |
| `CREATE OR REPLACE VIEW` | Exercise 2, Steps 04–05 |
| Self-join for prior period | Exercise 3, File 01 |
| `LAG()`, `SUM OVER PARTITION BY YEAR` | Exercise 3, File 02 |
| Calendar table join with gap-fill | Exercise 3, File 03 |
| `ROWS BETWEEN` frame clause | Exercise 3, File 04 |

---

## Validating Your Work

Each `data/` folder contains CSV files with expected output. After running a query, export your result and compare — columns, row count, and values should match.

---

## For AI Assistants

Read `CLAUDE.md` first. It has the full context you need: schema conventions, style rules, dim_date column reference, common mistakes to catch, and guidance on how to pace hints vs. full solutions.
