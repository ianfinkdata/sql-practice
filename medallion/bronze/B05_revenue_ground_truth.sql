-- TASK-20260704-02 · B05_revenue_ground_truth.sql · 2026-07-04
-- PURPOSE: Gross revenue ground truth (total + by year) and the DEF-016 text-vs-true reconciliation.
--          These are the reference numbers every later silver/gold layer reconciles back to.
-- GROUNDING: DEF-001 (line net revenue), DEF-002 (order true total), DEF-003 (revenue-recognized
--            statuses), DEF-004 (gross revenue scope = DEF-001 lines over DEF-003 orders), DEF-016
--            (order_total_text cast, reconciliation only — never a revenue source, RULE-003)
-- RUN: Get-Content B05_revenue_ground_truth.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- NOTE: 3 result sets — (1) total gross revenue, (2) gross revenue by order year, (3) DEF-016 reconciliation.

-- 1. Gross revenue total — DEF-004
SELECT SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)) AS gross_revenue  -- DEF-001
FROM oakhaven.order_items oi
JOIN oakhaven.orders o ON o.order_id = oi.order_id
WHERE o.status IN ('completed', 'refunded');  -- DEF-003

-- 2. Gross revenue by order year — DEF-004, sliced by YEAR(order_ts)
SELECT YEAR(o.order_ts) AS order_year,
       SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)) AS gross_revenue  -- DEF-001
FROM oakhaven.order_items oi
JOIN oakhaven.orders o ON o.order_id = oi.order_id
WHERE o.status IN ('completed', 'refunded')  -- DEF-003
GROUP BY YEAR(o.order_ts)
ORDER BY order_year;

-- 3. DEF-016 reconciliation: CAST(order_total_text) must equal DEF-002 true total for all 60,000 orders
WITH true_totals AS (
  SELECT oi.order_id,
         SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)) AS true_total  -- DEF-002 (via DEF-001)
  FROM oakhaven.order_items oi
  GROUP BY oi.order_id
)
SELECT
  COUNT(*) AS total_orders,
  SUM(CASE WHEN tt.true_total IS NULL THEN 1 ELSE 0 END) AS orders_missing_items,
  SUM(CASE WHEN tt.true_total IS NOT NULL
           AND CAST(REPLACE(REPLACE(TRIM(o.order_total_text), '$', ''), ',', '') AS DECIMAL(10,2)) <> tt.true_total  -- DEF-016
      THEN 1 ELSE 0 END) AS mismatches
FROM oakhaven.orders o
LEFT JOIN true_totals tt ON tt.order_id = o.order_id;
