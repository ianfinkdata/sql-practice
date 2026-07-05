-- TASK-20260704-04 · Q08_r2_category_revenue_rollup.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — breakdown: category revenue bar with
--          parent-category rollup (RS1 = parent rollup, RS2 = leaf-category detail).
-- GROUNDING: DEF-003 (order counts), DEF-004 (gross revenue); report-spec R2 breakdowns
-- RUN: Get-Content Q08_r2_category_revenue_rollup.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: ORDER BY measure DESC with id/name tie-breaks (RULE-001); parent_category_id is the
--       numeric tie-break so no literal-collation risk (RULE-012 n/a).

-- RS1: parent-category rollup
SELECT
  m.parent_category_id,
  m.parent_category_name,
  SUM(m.units_sold) AS units_sold,                      -- DEF-003 scope units
  SUM(m.gross_revenue) AS gross_revenue                 -- DEF-004
FROM oakhaven_gold.mart_category_sales m
GROUP BY m.parent_category_id, m.parent_category_name
ORDER BY gross_revenue DESC, m.parent_category_id;

-- RS2: leaf-category detail under the rollup
SELECT
  m.parent_category_name,
  m.category_id,
  m.category_name,
  SUM(m.units_sold) AS units_sold,                      -- DEF-003 scope units
  SUM(m.gross_revenue) AS gross_revenue                 -- DEF-004
FROM oakhaven_gold.mart_category_sales m
GROUP BY m.parent_category_name, m.category_id, m.category_name
ORDER BY gross_revenue DESC, m.category_id;
