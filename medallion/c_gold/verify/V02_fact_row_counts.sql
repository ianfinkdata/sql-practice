-- TASK-20260704-04 · V02_fact_row_counts.sql · 2026-07-05
-- PURPOSE: Prove fact grains: fact_order_lines = silver order_items restricted to DEF-003
--          orders; fact_orders = all 60,000 orders (B01); revenue-order counts match the B03
--          census (completed 55,917 + refunded 2,383 = 58,300); dim_product covers all 850.
-- GROUNDING: DEF-003 (revenue recognition); bronze captures B01 (row counts) and B03 (status
--            census) in medallion/a_bronze/EXPECTED_OUTPUTS.md; RULE-001, RULE-006
-- RUN: Get-Content V02_fact_row_counts.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 — fact_lines = silver_revenue_lines, is_match = 1.
--           RS2 — fact_orders = 60000; revenue_orders = fact_distinct_orders = mart_order_total = 58300 (B03-derived).
--           RS3 — dim_product = 850, mart_product_rows = 850 (LEFT JOIN keeps zero-sales products).

-- RS1: fact_order_lines row count vs the silver-derived DEF-003 line count
SELECT
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines) AS fact_lines,
  (SELECT COUNT(*)
   FROM oakhaven_silver.order_items oi
   JOIN oakhaven_silver.orders o ON o.order_id = oi.order_id
   WHERE o.status IN ('completed', 'refunded')) AS silver_revenue_lines,   -- DEF-003
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines) =
  (SELECT COUNT(*)
   FROM oakhaven_silver.order_items oi
   JOIN oakhaven_silver.orders o ON o.order_id = oi.order_id
   WHERE o.status IN ('completed', 'refunded')) AS is_match;

-- RS2: fact_orders grain + revenue-order accounting (B03: completed 55917 + refunded 2383 = 58300)
SELECT
  (SELECT COUNT(*) FROM oakhaven_gold.fact_orders) AS fact_orders_rows,
  (SELECT SUM(is_revenue_recognized) FROM oakhaven_gold.fact_orders) AS revenue_orders,       -- DEF-003
  (SELECT COUNT(DISTINCT order_id) FROM oakhaven_gold.fact_order_lines) AS fact_distinct_orders,
  (SELECT SUM(order_count) FROM oakhaven_gold.mart_monthly_sales) AS mart_order_total,        -- DEF-003
  (SELECT COUNT(*) FROM oakhaven_gold.fact_orders) = 60000 AS matches_b01,
  (SELECT SUM(is_revenue_recognized) FROM oakhaven_gold.fact_orders) = 58300 AS matches_b03;

-- RS3: dim_product / mart_product_performance cover all 850 products (B01)
SELECT
  (SELECT COUNT(*) FROM oakhaven_gold.dim_product) AS dim_product_rows,
  (SELECT COUNT(*) FROM oakhaven_gold.mart_product_performance) AS mart_product_rows,
  (SELECT COUNT(*) FROM oakhaven_gold.dim_product) = 850 AS matches_b01;
