-- TASK-20260704-04 · G05_fact_orders.sql · 2026-07-05
-- PURPOSE: Gold fact_orders — grain: order (all 60,000). True total (DEF-002), revenue-recognition
--          flag (DEF-003), order-level fulfillment days (DEF-018).
-- GROUNDING: DEF-001 (per-line rounding inside the DEF-002 sum), DEF-002 (order true total),
--            DEF-003 (revenue recognition), DEF-014 (canonical customer key), DEF-018 (fulfillment);
--            RULE-003 (order_total_text is NEVER a revenue source), RULE-004 (round per line)
-- RUN: Get-Content G05_fact_orders.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * ALL orders (completed/cancelled/refunded/pending) are kept at this grain;
--   is_revenue_recognized carries DEF-003 so marts/queries filter explicitly.
-- * The INNER JOIN on the line-total subquery is safe: bronze B05 proved orders_missing_items = 0.
-- * fulfillment_days = DEF-018 at order level ("MAX over its shipments"). Interpretation
--   (stated, not silent): if the order has NO shipment or ANY undelivered shipment, the true
--   MAX is not yet known → NULL (DEF-018 "NULL while pending"), with n_shipments /
--   n_undelivered_shipments surfaced so nothing is hidden. Anchor = order date (DEF-018
--   canonical DATEDIFF(delivered_date, DATE(order_ts))); DATEDIFF(MAX(d), x) = MAX(DATEDIFF(d, x)).

CREATE OR REPLACE VIEW oakhaven_gold.fact_orders AS
SELECT
  o.order_id,
  o.customer_id,
  c.canonical_customer_id,                              -- DEF-014 (dim_customer join key)
  o.store_id,
  o.employee_id,
  o.promo_id,
  o.channel,
  o.order_ts,
  DATE(o.order_ts) AS order_date,
  o.status,
  t.order_true_total,                                   -- DEF-002 (sum of DEF-001 per-line rounded amounts)
  CASE WHEN o.status IN ('completed', 'refunded') THEN 1 ELSE 0 END AS is_revenue_recognized,  -- DEF-003
  COALESCE(sh.n_shipments, 0) AS n_shipments,
  COALESCE(sh.n_undelivered_shipments, 0) AS n_undelivered_shipments,
  CASE WHEN sh.order_id IS NULL OR sh.n_undelivered_shipments > 0 THEN NULL
       ELSE DATEDIFF(sh.last_delivered_date, DATE(o.order_ts))
  END AS fulfillment_days                               -- DEF-018 (order level = MAX over shipments; NULL while pending)
FROM oakhaven_silver.orders o
JOIN oakhaven_silver.customers c ON c.customer_id = o.customer_id
JOIN (
  SELECT oi.order_id,
         SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)) AS order_true_total  -- DEF-001 inside DEF-002
  FROM oakhaven_silver.order_items oi
  GROUP BY oi.order_id
) t ON t.order_id = o.order_id
LEFT JOIN (
  SELECT s.order_id,
         COUNT(*) AS n_shipments,
         SUM(CASE WHEN s.delivered_date IS NULL THEN 1 ELSE 0 END) AS n_undelivered_shipments,  -- DEF-011 parsed date
         MAX(s.delivered_date) AS last_delivered_date
  FROM oakhaven_silver.shipments s
  GROUP BY s.order_id
) sh ON sh.order_id = o.order_id;
