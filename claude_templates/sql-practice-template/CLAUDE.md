# CLAUDE.md — SQL Practice Template

This file tells AI assistants how to work with this project. Read it before suggesting any SQL or file changes.

---

## What this project is

A MySQL SQL learning project following a **medallion architecture** (Bronze → Silver → Gold). The learner builds tables, enriches data, and progressively constructs analytical views. The goal is hands-on SQL skill development, not production deployment.

**Schemas:**
- `[your_schema]` — replace with the learner's chosen schema name throughout all files
- `common_db` — shared infrastructure (calendar table, utility sequences); must be built before exercises start

---

## How to help the learner

1. **Check where they are** — Ask which numbered exercise file they are on before suggesting anything.
2. **Don't skip ahead** — Each SQL file depends on the previous one. Later views require earlier views to exist.
3. **Validate schema state first** — Before writing ALTER TABLE or CREATE VIEW, confirm the current table/view structure with an `information_schema` query.
4. **Prefer incremental hints** — The exercises are designed to teach. Offer a hint or a partial skeleton before the full answer unless the learner asks for the complete solution.
5. **Match the project's SQL style** (see Style Rules below).

---

## Schema setup

Before any exercises run, the learner must:

1. Create both schemas in MySQL:
   ```sql
   CREATE SCHEMA IF NOT EXISTS [your_schema];
   CREATE SCHEMA IF NOT EXISTS common_db;
   ```
2. Run `common_db/date_recursion.sql` to build `dim_date`
3. Run `common_db/weekstart_adds.sql` to add week/month columns to `dim_date`
4. Run `1-DDL_AND_DML/SQL/01-schema-setup.sql` to create and seed the core tables

---

## dim_date column reference

The `common_db.dim_date` table after setup has these columns:

| Column | Type | Notes |
|--------|------|-------|
| DateKey | INT | Computed: `CAST(Date AS UNSIGNED)` |
| Date | DATE | The calendar date |
| Year | INT | |
| MonthNum | INT | 1–12 |
| Month | VARCHAR | 3-letter abbreviation |
| Quarter | INT | 1–4 |
| WeekDay | INT | MySQL WEEKDAY() — 0=Monday |
| WeekDayName | VARCHAR | 'Mon', 'Tue', etc. |
| IsWeekend | TINYINT | 1 if Sat/Sun |
| WeekStart | DATE | Sunday of the week |
| ISOWeekStart | DATE | Monday of the ISO week |
| month_start_date | computed | Use: `DATE_SUB(Date, INTERVAL (DAY(Date)-1) DAY)` — NOT a stored column; calculate inline or add as generated column |

---

## SQL style rules for this project

- **CTEs over subqueries** in the FROM clause — use `WITH name AS (...)` 
- **`COALESCE(SUM(...), 0)`** when LEFT JOINs may produce NULLs in aggregates
- **`CREATE OR REPLACE VIEW`** — never `DROP VIEW IF EXISTS` + `CREATE VIEW`
- **`IFNULL(x, 0)`** is fine for scalar nullable expressions
- **No trailing semicolons inside CTEs** — only at the very end of the statement
- **Lowercase SQL keywords** are acceptable; consistency within a file is more important than case
- **Add a `select * from view_name;`** after each `CREATE OR REPLACE VIEW` so the learner can immediately see the result

---

## Medallion layers

| Layer | Naming pattern | Source |
|-------|---------------|--------|
| Bronze | raw tables (`sp_*`) | Direct INSERT/UPDATE |
| Silver | `silver_*` views | Join + enrich Bronze |
| Gold | `gold_*` views | Aggregate Silver |
| Time Intel | `time_intel_*` views | Window + calendar joins on Bronze or Silver |

Never build a Gold view that queries Bronze directly — always go through Silver.

---

## Common mistakes to catch

- Using `GROUP BY` column aliases instead of expressions (MySQL allows it, but mention it's non-standard)
- Forgetting `COALESCE` after a `LEFT JOIN` aggregate — silent 0 vs NULL difference
- Hardcoding a month/year in a rolling window — always use `CURRENT_DATE` with `INTERVAL`
- Using `WEEK()` instead of `ISOWeekStart` when week boundaries matter across year-ends
- Missing `WHERE region IS NOT NULL` in region cross-joins (can produce a NULL region row)

---

## When the learner asks for data generation

- Use `RAND() * range + min` for sale amounts; wrap in `ROUND(..., 2)` for currency
- Use `UPDATE ... SET col = CASE WHEN id = 1 THEN ... END WHERE id BETWEEN x AND y` — the pattern already in this project
- Offer to seed `RAND()` with a fixed value if reproducibility is needed: `RAND(42)`

---

## File naming convention

```
[exercise-number]-[short-description].sql
DONE-[exercise-number]-[short-description].sql   ← completed solution
```

Keep `DONE-` files in the same folder as the exercise — they are reference answers, not clutter.
