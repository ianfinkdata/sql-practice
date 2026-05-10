# Squirrelpractice — MySQL SQL Practice Project

A progressive, hands-on MySQL exercise series built around a fictional sales company. The project covers DDL/DML fundamentals through advanced analytical views, using a medallion-style data layering pattern (Bronze → Silver → Gold).

---

## Prerequisites

- MySQL 8.0+ (window functions and `JSON_TABLE` required)
- Two schemas must exist before starting:
  - `squirrelpractice` — primary working schema
  - `common_db` — shared infrastructure (calendar table, utility sequences)
- Build `common_db` first using the files in `common_db/`

---

## Data Model

Three core tables live in the `squirrelpractice` schema:

```
sp_customers
  customer_id   INT (PK)
  contact_details JSON  -- array of {type, value} objects
  customer_name VARCHAR(50)
  region        VARCHAR(50)

sp_sales
  sale_id       INT
  sale_date     DATE
  customer_id   INT
  rep_id        INT
  sale_amount   DECIMAL(10,2)

sp_sales_rep
  rep_id        INT
  rep_name      VARCHAR(50)
  commission_rate DECIMAL(4,2)
```

CSV snapshots of each table's final state live in `1-DDL_AND_DML/Data/`.

---

## Project Structure

```
squirrelpractice/
├── common_db/                         # Shared infrastructure — build first
│   ├── date_recursion.sql             # Builds dim_date calendar table (2019–2031)
│   ├── number_recursion.sql           # Builds a 1–100 integer sequence table
│   └── weekstart_adds.sql             # Adds WeekStart columns to dim_date
│
├── 1-DDL_AND_DML/                     # Exercise 1: Build the schema from scratch
│   ├── Data/                          # CSV snapshots of final table states
│   │   ├── 1_sp_customers.csv
│   │   ├── 1_sp_sales.csv
│   │   └── 1_sp_sales_rep.csv
│   └── SQL/
│       ├── 1-DatabaseEnrichment.sql   # Starting point — minimal tables, one query
│       └── DONE-1-DatabaseEnrichment.sql  # Completed solution
│
└── 2-Advanced_Transformations/        # Exercise 2: Progressive view-building
    ├── data/                          # Expected output CSVs per step
    └── SQL/
        ├── 2-1_JSON_CTE_EmailAddress.sql        # Step 1: Extract emails from JSON
        ├── 2-2_Sale_Month_Column.sql             # Step 2: Add sale_month with interval math
        ├── 2-3_CASE_WINDOW.sql                   # Step 3: Deal size + RANK()
        ├── 2-4_Final_View.sql                    # Step 4: CREATE OR REPLACE VIEW silver_sales_pipeline
        ├── 2-view_silver_sales_pipeline.sql      # Placeholder / alternate silver view stub
        ├── 3-view_gold_rep_performance.sql        # Gold layer: rep monthly summary + cumulative sales
        ├── 4-1_view_time_intel_joins.sql          # Tier 1 time intel: self-join, no window functions
        ├── 4-2_view_time_intel_windows.sql        # Tier 2 time intel: LAG + YTD with window functions
        ├── 4-3_view_silver_rolling_three_month_daily_sales.sql  # Daily sales joined to calendar
        └── 4-3_view_time_intel_sliding.sql        # Final Boss: rolling 3-month regional avg (ROWS BETWEEN)
```

---

## Exercise Sequence

Work through the exercises in numbered order. Each step's output is validated against the matching CSV in the `data/` folder.

### Step 0 — Build common_db Infrastructure

Run in `common_db` schema:
1. `date_recursion.sql` — generates `dim_date` spanning 2019–2031
2. `weekstart_adds.sql` — enriches `dim_date` with `WeekStart` and `ISOWeekStart`
3. `number_recursion.sql` — optional utility sequence table

### Step 1 — DDL & DML (`1-DDL_AND_DML/`)

Start with the stub in `1-DatabaseEnrichment.sql`. The tables exist but are bare-bones. Your goal:
- Rename columns to meaningful names (Phase 1)
- Add missing columns with correct data types (Phase 2)
- Populate data using `UPDATE ... SET ... CASE` (Phase 3)
- Reference `DONE-1-DatabaseEnrichment.sql` if stuck

### Step 2 — Advanced Transformations (`2-Advanced_Transformations/`)

Build incrementally — each file is a stepping stone toward the final view:

| File | Concept | Output |
|------|---------|--------|
| `2-1` | `JSON_TABLE` + CTE | Customer emails extracted from JSON |
| `2-2` | JOIN + interval month math | Sale-level rows with `sale_month` |
| `2-3` | `CASE` + `RANK() OVER(PARTITION BY)` | Deal categories + ranked sales |
| `2-4` | `CREATE OR REPLACE VIEW` | `silver_sales_pipeline` view |
| `3` | Aggregate CTE + `SUM OVER` | `gold_rep_performance` view |
| `4-1` | Self-join for prior month | `time_intel_joins` (no window functions) |
| `4-2` | `LAG()` + `SUM OVER PARTITION BY YEAR` | `time_intel_joins_windows` with YTD |
| `4-3 daily` | Calendar join + `COALESCE` | Rolling daily sales with no gaps |
| `4-3 sliding` | `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` | Regional rolling 3-month average |

---

## Key SQL Concepts Covered

- `ALTER TABLE`: rename columns, add columns, modify types, add primary keys
- `UPDATE ... SET ... CASE WHEN`: conditional bulk updates
- `JSON_TABLE` with `CROSS JOIN`: flattening JSON arrays into relational rows
- CTEs (`WITH`): building named result sets for readability and reuse
- Interval math: `sale_date - INTERVAL (DAY(sale_date)-1) DAY` for month normalization
- Window functions: `RANK()`, `LAG()`, `SUM() OVER(PARTITION BY ... ORDER BY ...)`, `AVG() OVER(ROWS BETWEEN ...)`
- Self-joins on date columns for prior-period comparison
- Recursive CTEs for generating calendar and number sequences
- `CREATE OR REPLACE VIEW` for reusable query layers

---

## Medallion Architecture Pattern

The views follow a Bronze → Silver → Gold layering convention:

- **Bronze**: Raw source tables (`sp_sales`, `sp_customers`, `sp_sales_rep`)
- **Silver**: Cleaned, joined, enriched views (`silver_sales_pipeline`, `silver_rolling_three_month_daily_sales`)
- **Gold**: Aggregated, business-ready views (`gold_rep_performance`, `time_intel_*`)

---

## For AI Assistants

**Context you need:**
- Target database: MySQL 8.0+, schema = `squirrelpractice`, shared infra in `common_db`
- The `dim_date` table in `common_db` has columns: `DateKey`, `Date`, `WeekStart`, `ISOWeekStart`, `Year`, `MonthNum`, `Month`, `Quarter`, `WeekDay`, `WeekDayName`, `IsWeekend`, and a computed `month_start_date` derived from `DATE_SUB(Date, INTERVAL (DAY(Date)-1) DAY)`
- Do NOT use `week_start_date` or `month_start_date` as actual column names unless the user has confirmed they added them — check `weekstart_adds.sql` for what was actually added
- The `silver_sales_pipeline` view must exist before `gold_rep_performance` can be built
- When generating INSERT/UPDATE data, use `RAND()` seeded values for reproducibility or ask the user for specific values
- When the user asks for "the next step," check which numbered SQL file they are on and suggest the next one

**Preferred patterns in this project:**
- CTEs over subqueries in the FROM clause
- `COALESCE(SUM(...), 0)` over bare `SUM` when NULLs from LEFT JOINs are expected
- `CREATE OR REPLACE VIEW` over `DROP VIEW IF EXISTS` + `CREATE VIEW`
- `IFNULL(x, 0)` is acceptable for scalar nullable expressions
- Exercise files are cumulative: later files build on earlier views — never drop earlier views to solve a later problem
