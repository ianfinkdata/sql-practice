-- TASK-20260704-04 · Q06_r2_product_kpis.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — KPI row: active products, units sold, gross
--          revenue, unit return rate.
-- GROUNDING: DEF-003 (scope), DEF-004 (gross revenue), DEF-007 (unit return rate),
--            DEF-009 (active = discontinued_flag 0, normalized in silver); report-spec R2 KPIs
-- RUN: Get-Content Q06_r2_product_kpis.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: single-row aggregate — trivially deterministic (RULE-001).
-- OMITTED: "median unit margin" (report-spec R2) — "unit margin" has NO DEF in
--          grounding/definitions.md; escalated as MISSING DEFINITION in the task handoff.

SELECT
  (SELECT COUNT(*) FROM oakhaven_gold.dim_product WHERE discontinued_flag = 0) AS active_products,  -- DEF-009
  (SELECT COUNT(*) FROM oakhaven_gold.dim_product) AS total_products,
  SUM(f.quantity) AS units_sold,                                                  -- DEF-003 scope units
  SUM(f.line_net_revenue) AS gross_revenue,                                       -- DEF-004
  ROUND(SUM(f.quantity_returned) / SUM(f.quantity) * 100, 2) AS unit_return_rate_pct  -- DEF-007
FROM oakhaven_gold.fact_order_lines f;
