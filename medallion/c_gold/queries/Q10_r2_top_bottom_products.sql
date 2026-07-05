-- TASK-20260704-04 · Q10_r2_top_bottom_products.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — detail table: top 15 (RS1) and bottom 15 (RS2)
--          products by gross revenue, with return rates.
-- GROUNDING: DEF-004 (gross revenue), DEF-007 (unit return rate), DEF-008 (revenue return
--            rate); report-spec R2 detail
-- RUN: Get-Content Q10_r2_top_bottom_products.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: LIMIT 15 with deterministic ORDER BY revenue + product_id tie-break (RULE-001).

-- RS1: top 15 products by gross revenue
SELECT
  m.product_id, m.sku, m.product_name, m.category_name,
  m.units_sold,
  m.gross_revenue,                                      -- DEF-004
  m.unit_return_rate_pct,                               -- DEF-007
  m.revenue_return_rate_pct                             -- DEF-008
FROM oakhaven_gold.mart_product_performance m
ORDER BY m.gross_revenue DESC, m.product_id
LIMIT 15;

-- RS2: bottom 15 products by gross revenue
SELECT
  m.product_id, m.sku, m.product_name, m.category_name,
  m.units_sold,
  m.gross_revenue,                                      -- DEF-004
  m.unit_return_rate_pct,                               -- DEF-007
  m.revenue_return_rate_pct                             -- DEF-008
FROM oakhaven_gold.mart_product_performance m
ORDER BY m.gross_revenue ASC, m.product_id
LIMIT 15;
