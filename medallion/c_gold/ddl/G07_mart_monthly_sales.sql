-- TASK-20260704-04 · G07_mart_monthly_sales.sql · 2026-07-05
-- PURPOSE: Gold mart_monthly_sales — month × store × channel trend mart: gross revenue, orders,
--          AOV, and net revenue after returns.
-- GROUNDING: DEF-003 (order count scope), DEF-004 (gross revenue), DEF-005 (net revenue),
--            DEF-006 (AOV); DEF-014 not needed at this grain
-- RUN: Get-Content G07_mart_monthly_sales.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- DATING POLICY (DEF-005 caveat — this mart NETS RETURNS): this is a TREND mart, so returned
-- value is dated by RETURN_DATE month (cash-timing view). Gross measures are dated by the
-- original ORDER date month. A return therefore nets against the month it came back in, at the
-- original order line's store/channel dimensions. Reconciliation guard: any return-side cell
-- (return-month × store × channel) with no gross-side cell would be dropped by the LEFT JOIN —
-- V01 proves that count is 0 on live data.
--
-- Grain: sales_month ('%Y-%m' of order date) × store_id × channel.

CREATE OR REPLACE VIEW oakhaven_gold.mart_monthly_sales AS
WITH gross AS (
  SELECT DATE_FORMAT(f.order_date, '%Y-%m') AS sales_month,
         f.store_id,
         f.channel,
         COUNT(DISTINCT f.order_id) AS order_count,     -- DEF-003 (revenue-recognized orders)
         SUM(f.quantity) AS units_sold,                 -- DEF-003 scope units
         SUM(f.line_net_revenue) AS gross_revenue,      -- DEF-004
         ROUND(SUM(f.line_net_revenue) / COUNT(DISTINCT f.order_id), 2) AS aov  -- DEF-006
  FROM oakhaven_gold.fact_order_lines f
  GROUP BY DATE_FORMAT(f.order_date, '%Y-%m'), f.store_id, f.channel
),
ret AS (
  SELECT DATE_FORMAT(f.return_date, '%Y-%m') AS return_month,   -- DEF-005 trend-mart dating: return_date
         f.store_id,
         f.channel,
         SUM(f.quantity_returned) AS units_returned,    -- DEF-007 input
         SUM(f.refund_amount) AS returned_value         -- DEF-005 returned_value
  FROM oakhaven_gold.fact_order_lines f
  WHERE f.is_returned = 1
  GROUP BY DATE_FORMAT(f.return_date, '%Y-%m'), f.store_id, f.channel
)
SELECT
  g.sales_month,
  g.store_id,
  g.channel,
  g.order_count,                                        -- DEF-003
  g.units_sold,
  g.gross_revenue,                                      -- DEF-004
  g.aov,                                                -- DEF-006
  COALESCE(r.units_returned, 0) AS units_returned,      -- DEF-007 input
  COALESCE(r.returned_value, 0) AS returned_value,      -- DEF-005
  g.gross_revenue - COALESCE(r.returned_value, 0) AS net_revenue  -- DEF-005
FROM gross g
LEFT JOIN ret r
  ON r.return_month = g.sales_month
 AND r.store_id     = g.store_id
 AND r.channel      = g.channel;
