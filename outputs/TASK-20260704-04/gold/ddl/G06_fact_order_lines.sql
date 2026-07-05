-- TASK-20260704-04 · G06_fact_order_lines.sql · 2026-07-05
-- PURPOSE: Gold fact_order_lines — grain: order line, REVENUE LINES ONLY (DEF-003).
--          Line net revenue (DEF-001) with return quantity/value LEFT-joined on.
-- GROUNDING: DEF-001 (line net revenue, per-line rounding), DEF-003 (revenue-recognized statuses),
--            DEF-005 (returned value + return_date dating input), DEF-007 (quantity_returned input),
--            DEF-008 (refund vs revenue input), DEF-014 (canonical customer key);
--            RULE-004 (round per line, never sum-then-round), RULE-008 (D17 penny prices untouched)
-- RUN: Get-Content G06_fact_order_lines.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * Grain safety: DEF-007 caveat "a line can have at most one return row in this dataset" —
--   the LEFT JOIN cannot fan out; verified adversarially in V05 (duplicate-return probe = 0).
-- * quantity_returned / refund_amount are COALESCEd to 0 (the DEF-005/007/008 canonical SQL
--   COALESCEs), so marts can SUM directly; return_date stays NULL when no return.
-- * NO unit-margin column: "unit margin" has no DEF in grounding/definitions.md (escalated as
--   MISSING DEFINITION in the task handoff); unit_price is here and unit_cost is in dim_product,
--   so the measure can be added verbatim once a DEF exists.
-- * Expected row count = silver order_items restricted to DEF-003 orders (verified in V02).

CREATE OR REPLACE VIEW oakhaven_gold.fact_order_lines AS
SELECT
  oi.order_item_id,
  oi.order_id,
  o.order_ts,
  DATE(o.order_ts) AS order_date,
  o.status AS order_status,
  o.channel,
  o.store_id,
  o.promo_id,
  o.customer_id,
  c.canonical_customer_id,                              -- DEF-014 (dim_customer join key)
  oi.product_id,
  oi.quantity,
  oi.unit_price,                                        -- D17 penny prices untouched (RULE-008)
  oi.line_discount_pct,
  ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2) AS line_net_revenue,  -- DEF-001
  CASE WHEN r.return_id IS NOT NULL THEN 1 ELSE 0 END AS is_returned,
  r.return_id,
  COALESCE(r.quantity_returned, 0) AS quantity_returned,  -- DEF-007 numerator input
  COALESCE(r.refund_amount, 0) AS refund_amount,          -- DEF-005 / DEF-008 returned-value input
  r.return_date                                           -- DEF-005 dating input (trend marts date returns by this)
FROM oakhaven_silver.order_items oi
JOIN oakhaven_silver.orders o     ON o.order_id = oi.order_id
JOIN oakhaven_silver.customers c  ON c.customer_id = o.customer_id
LEFT JOIN oakhaven_silver.returns r ON r.order_item_id = oi.order_item_id
WHERE o.status IN ('completed', 'refunded');            -- DEF-003
