-- TASK-20260704-04 · Q01_r1_sales_kpis.sql · 2026-07-05
-- PURPOSE: R1 Sales Explorer — KPI row: gross revenue, net revenue, order count, AOV,
--          revenue return rate (full window, report-spec R1).
-- GROUNDING: DEF-003 (order count scope), DEF-004 (gross revenue), DEF-005 (net revenue;
--            full-window total so dating policy is moot — all returns net), DEF-006 (AOV),
--            DEF-008 (revenue return rate); report-spec R1 KPIs
-- RUN: Get-Content Q01_r1_sales_kpis.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: single-row aggregate — trivially deterministic (RULE-001).

SELECT
  SUM(f.line_net_revenue) AS gross_revenue,                                       -- DEF-004
  SUM(f.refund_amount) AS returned_value,                                         -- DEF-005 input
  SUM(f.line_net_revenue) - SUM(f.refund_amount) AS net_revenue,                  -- DEF-005
  COUNT(DISTINCT f.order_id) AS order_count,                                      -- DEF-003
  ROUND(SUM(f.line_net_revenue) / COUNT(DISTINCT f.order_id), 2) AS aov,          -- DEF-006
  ROUND(SUM(f.refund_amount) / SUM(f.line_net_revenue) * 100, 2) AS revenue_return_rate_pct  -- DEF-008
FROM oakhaven_gold.fact_order_lines f;
