-- TASK-20260705-01 · Q13_r1_revenue_by_tier.sql · 2026-07-05
-- PURPOSE: R1 Sales Explorer — breakdown: gross/net revenue by loyalty tier (bar, ordinal
--          axis — ordered by DEF-020 tier rank, never alphabet, per report-spec visual rules).
-- GROUNDING: DEF-020 v1.0 (loyalty tier + ordinal rank), DEF-003 (order counts), DEF-004
--            (gross revenue), DEF-005 (net revenue; full-window total so dating policy is moot),
--            DEF-014 (orders attribute to the CANONICAL customer's tier via canonical_customer_id);
--            report-spec R1 breakdowns
-- RUN: Get-Content Q13_r1_revenue_by_tier.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: 4 rows; ORDER BY loyalty_tier_rank (numeric, 1:1 with the tier per DEF-020) with the
--       tier itself as collation-pinned tie-break (RULE-001, RULE-012). Absorbed dupes' orders
--       count under their canonical customer's tier (DEF-014 collapse).

SELECT
  d.loyalty_tier,                                       -- DEF-020
  d.loyalty_tier_rank,                                  -- DEF-020 (ordinal: basic=1 … platinum=4)
  COUNT(DISTINCT f.order_id) AS order_count,            -- DEF-003
  SUM(f.line_net_revenue) AS gross_revenue,             -- DEF-004
  SUM(f.line_net_revenue) - SUM(f.refund_amount) AS net_revenue  -- DEF-005
FROM oakhaven_gold.fact_order_lines f
JOIN oakhaven_gold.dim_customer d ON d.customer_id = f.canonical_customer_id  -- DEF-014
GROUP BY d.loyalty_tier, d.loyalty_tier_rank
ORDER BY d.loyalty_tier_rank, d.loyalty_tier COLLATE utf8mb4_bin;
