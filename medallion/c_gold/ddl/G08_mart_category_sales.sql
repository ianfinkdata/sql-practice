-- TASK-20260704-04 · G08_mart_category_sales.sql · 2026-07-05
-- PURPOSE: Gold mart_category_sales — month × category trend mart (units, gross revenue,
--          orders) with the parent-category rollup attributes report-spec R2 needs.
-- GROUNDING: DEF-003 (order count scope), DEF-004 (gross revenue)
-- RUN: Get-Content G08_mart_category_sales.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- DATING POLICY: this mart does NOT net returns — GROSS ONLY, dated by original order date
-- month. (Category-level return metrics live in mart_product_performance, which states the
-- original-order-date policy per the DEF-005 caveat.)
--
-- Grain: sales_month ('%Y-%m' of order date) × category_id.

CREATE OR REPLACE VIEW oakhaven_gold.mart_category_sales AS
SELECT
  DATE_FORMAT(f.order_date, '%Y-%m') AS sales_month,
  p.category_id,
  p.category_name,
  p.parent_category_id,
  p.parent_category_name,
  COUNT(*) AS line_count,                               -- DEF-003 scope lines
  COUNT(DISTINCT f.order_id) AS order_count,            -- DEF-003
  SUM(f.quantity) AS units_sold,                        -- DEF-003 scope units
  SUM(f.line_net_revenue) AS gross_revenue              -- DEF-004
FROM oakhaven_gold.fact_order_lines f
JOIN oakhaven_gold.dim_product p ON p.product_id = f.product_id
GROUP BY DATE_FORMAT(f.order_date, '%Y-%m'),
         p.category_id, p.category_name, p.parent_category_id, p.parent_category_name;
