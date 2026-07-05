-- TASK-20260704-04 · G10_mart_fulfillment.sql · 2026-07-05
-- PURPOSE: Gold mart_fulfillment — month × channel shipment-grain fulfillment mart:
--          delivered/undelivered counts and DEF-018 fulfillment-day stats.
-- GROUNDING: DEF-018 (fulfillment days; ANCHOR = ORDER DATE, the canonical
--            DATEDIFF(delivered_date, DATE(order_ts)) — the ship-to-deliver alternative is NOT
--            used here, stated per the DEF-018 caveat), DEF-011 (delivered_date parse + pending flag)
-- RUN: Get-Content G10_mart_fulfillment.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * This mart does not net returns — no DEF-005 dating policy applies. Time key = ORDER month
--   (DEF-018 anchor), not ship month.
-- * Grain: order_month × channel over SHIPMENTS (an order may have 2 shipments — DEF-018 grain
--   note; order-level MAX lives in fact_orders.fulfillment_days). All shipments are included
--   regardless of order status (fulfillment is operational, not revenue-scoped).
-- * avg/min/max fulfillment days aggregate DELIVERED shipments only (DATEDIFF is NULL while
--   pending — DEF-011/018; AVG/MIN/MAX ignore NULLs). avg is ROUNDed to 2dp explicitly
--   (medallion-spec §Reproducibility rule 3).

CREATE OR REPLACE VIEW oakhaven_gold.mart_fulfillment AS
SELECT
  DATE_FORMAT(o.order_ts, '%Y-%m') AS order_month,      -- DEF-018 anchor month
  o.channel,
  COUNT(*) AS n_shipments,
  SUM(CASE WHEN s.delivered_date IS NOT NULL THEN 1 ELSE 0 END) AS n_delivered,   -- DEF-011 parsed date
  SUM(CASE WHEN s.delivered_date IS NULL THEN 1 ELSE 0 END) AS n_undelivered,     -- DEF-011 (raw NULL + PENDING)
  SUM(s.is_delivery_pending) AS n_pending_flag,         -- DEF-011 caveat flag ('PENDING' raws only)
  ROUND(AVG(DATEDIFF(s.delivered_date, DATE(o.order_ts))), 2) AS avg_fulfillment_days,  -- DEF-018
  MIN(DATEDIFF(s.delivered_date, DATE(o.order_ts))) AS min_fulfillment_days,            -- DEF-018
  MAX(DATEDIFF(s.delivered_date, DATE(o.order_ts))) AS max_fulfillment_days             -- DEF-018
FROM oakhaven_silver.shipments s
JOIN oakhaven_silver.orders o ON o.order_id = s.order_id
GROUP BY DATE_FORMAT(o.order_ts, '%Y-%m'), o.channel;
