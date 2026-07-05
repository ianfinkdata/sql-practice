-- TASK-20260704-04 · Q04_r1_promo_share.sql · 2026-07-05
-- PURPOSE: R1 Sales Explorer — breakdown: promo vs non-promo revenue share (structural slice
--          on orders.promo_id presence — an FK fact, not invented logic).
-- GROUNDING: DEF-003 (order counts), DEF-004 (gross revenue); report-spec R1 breakdowns
-- RUN: Get-Content Q04_r1_promo_share.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: 2 rows; ORDER BY the string-literal alias with pinned collation (RULE-012).

SELECT
  CASE WHEN f.promo_id IS NULL THEN 'no_promo' ELSE 'promo' END AS promo_flag,
  COUNT(DISTINCT f.order_id) AS order_count,            -- DEF-003
  SUM(f.line_net_revenue) AS gross_revenue,             -- DEF-004
  ROUND(SUM(f.line_net_revenue) / SUM(SUM(f.line_net_revenue)) OVER () * 100, 2) AS revenue_share_pct  -- DEF-004 share
FROM oakhaven_gold.fact_order_lines f
GROUP BY CASE WHEN f.promo_id IS NULL THEN 'no_promo' ELSE 'promo' END
ORDER BY promo_flag COLLATE utf8mb4_bin;
