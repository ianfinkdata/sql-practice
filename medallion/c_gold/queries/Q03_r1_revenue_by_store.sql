-- TASK-20260704-04 · Q03_r1_revenue_by_store.sql · 2026-07-05
-- PURPOSE: R1 Sales Explorer — breakdown: gross/net revenue by store (bar, sorted by measure).
-- GROUNDING: DEF-003 (order counts), DEF-004 (gross revenue), DEF-005 (net revenue,
--            return_date-dated per mart_monthly_sales policy); report-spec R1 breakdowns
-- RUN: Get-Content Q03_r1_revenue_by_store.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: 13 rows; ORDER BY measure DESC with store_id tie-break (RULE-001).

SELECT
  m.store_id,
  s.store_code,
  s.city,
  s.state,
  SUM(m.order_count) AS order_count,                    -- DEF-003
  SUM(m.gross_revenue) AS gross_revenue,                -- DEF-004
  SUM(m.net_revenue) AS net_revenue                     -- DEF-005
FROM oakhaven_gold.mart_monthly_sales m
JOIN oakhaven_gold.dim_store s ON s.store_id = m.store_id
GROUP BY m.store_id, s.store_code, s.city, s.state
ORDER BY gross_revenue DESC, m.store_id;
