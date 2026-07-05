-- TASK-20260704-04 · G09_mart_product_performance.sql · 2026-07-05
-- PURPOSE: Gold mart_product_performance — per-product whole-window performance: units, gross
--          revenue, unit return rate (DEF-007), revenue return rate (DEF-008).
-- GROUNDING: DEF-003 (scope), DEF-004 (gross revenue), DEF-005 (refund value input),
--            DEF-007 (unit return rate), DEF-008 (revenue return rate), DEF-009 (discontinued_flag)
-- RUN: Get-Content G09_mart_product_performance.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- DATING POLICY (DEF-005 caveat — this mart NETS RETURNS into rates): this is a PRODUCT-LEVEL
-- RETURN-RATE mart, so returns attribute to the ORIGINAL order line (original order date
-- basis), NOT return_date. The mart is whole-window (no time slice), so every return of a
-- revenue line is counted against its product regardless of when it came back.
--
-- NOTES:
-- * Grain: product — LEFT JOIN from dim_product so ALL 850 products appear; a product with no
--   revenue lines shows zero counts and NULL rates (0/0 division → NULL, deliberate).
-- * No margin measure: "unit margin" has no DEF (escalated as MISSING DEFINITION in the task
--   handoff); unit_cost/list_price/is_below_cost are attributes for the R2 scatter instead.

CREATE OR REPLACE VIEW oakhaven_gold.mart_product_performance AS
SELECT
  p.product_id,
  p.sku,
  p.product_name,
  p.category_id,
  p.category_name,
  p.parent_category_name,
  p.discontinued_flag,                                  -- DEF-009 (normalized in silver)
  p.unit_cost,
  p.list_price,
  p.is_below_cost,                                      -- D16 planted anomaly flag (RULE-008)
  COUNT(f.order_item_id) AS line_count,                 -- DEF-003 scope lines
  COUNT(DISTINCT f.order_id) AS order_count,            -- DEF-003
  COALESCE(SUM(f.quantity), 0) AS units_sold,           -- DEF-003 scope units
  COALESCE(SUM(f.line_net_revenue), 0) AS gross_revenue, -- DEF-004
  COALESCE(SUM(f.quantity_returned), 0) AS units_returned,  -- DEF-007 numerator
  ROUND(SUM(f.quantity_returned) / SUM(f.quantity) * 100, 2) AS unit_return_rate_pct,  -- DEF-007
  COALESCE(SUM(f.refund_amount), 0) AS refund_value,    -- DEF-005 returned_value input
  ROUND(SUM(f.refund_amount) / SUM(f.line_net_revenue) * 100, 2) AS revenue_return_rate_pct  -- DEF-008
FROM oakhaven_gold.dim_product p
LEFT JOIN oakhaven_gold.fact_order_lines f ON f.product_id = p.product_id
GROUP BY p.product_id, p.sku, p.product_name, p.category_id, p.category_name,
         p.parent_category_name, p.discontinued_flag, p.unit_cost, p.list_price, p.is_below_cost;
