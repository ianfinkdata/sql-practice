-- TASK-20260704-04 · Q07_r2_monthly_units_top5_categories.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — trend: monthly units sold for the top-5 categories
--          by total units (line / small-multiple source).
-- GROUNDING: DEF-003 (scope units), DEF-004 (gross revenue included for context);
--            report-spec R2 trend
-- RUN: Get-Content Q07_r2_monthly_units_top5_categories.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: top-5 cut is deterministic (units DESC, category_id tie-break — RULE-001); output is
--       450 rows (90 months × 5 categories), captured in full in EXPECTED_OUTPUTS.md
--       (TASK-20260705-02).

WITH category_totals AS (
  SELECT m.category_id,
         SUM(m.units_sold) AS total_units
  FROM oakhaven_gold.mart_category_sales m
  GROUP BY m.category_id
),
top5 AS (
  SELECT category_id
  FROM category_totals
  ORDER BY total_units DESC, category_id
  LIMIT 5
)
SELECT
  m.sales_month,
  m.category_id,
  m.category_name,
  m.units_sold,                                         -- DEF-003 scope units
  m.gross_revenue                                       -- DEF-004
FROM oakhaven_gold.mart_category_sales m
JOIN top5 t ON t.category_id = m.category_id
ORDER BY m.sales_month, m.category_id;
