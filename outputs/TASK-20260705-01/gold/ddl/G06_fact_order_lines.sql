-- TASK-20260705-01 · G06_fact_order_lines.sql · 2026-07-05 (amends TASK-20260704-04 version — additive)
-- PURPOSE: Gold fact_order_lines — grain: order line, REVENUE LINES ONLY (DEF-003).
--          Line net revenue (DEF-001) with return quantity/value LEFT-joined on.
--          AMENDED: unit_margin added per DEF-021 (realized form), via a products join.
-- GROUNDING: DEF-001 (line net revenue, per-line rounding), DEF-003 (revenue-recognized statuses),
--            DEF-005 (returned value + return_date dating input), DEF-007 (quantity_returned input),
--            DEF-008 (refund vs revenue input), DEF-014 (canonical customer key),
--            DEF-021 v1.0 (unit margin — realized post-discount unit price − current unit_cost,
--            rounded 2dp BEFORE subtracting per the DEF-001 round-per-line law);
--            RULE-004 (round per line, never sum-then-round), RULE-008 (D17 penny prices and
--            realized below-cost margins untouched — features, never filtered)
-- RUN: Get-Content G06_fact_order_lines.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * Grain safety: DEF-007 caveat "a line can have at most one return row in this dataset" —
--   the LEFT JOIN cannot fan out; verified adversarially in V05 (duplicate-return probe = 0).
-- * The products join is an INNER join on the PK product_id (1:1 per line — B02 proves zero
--   orphan order_items.product_id), so the row count stays 151,818; V02 re-verifies.
-- * unit_margin cost basis is CURRENT products.unit_cost — no historical cost table exists,
--   so margins on old orders use today's cost (DEF-021 stated limitation). Realized below-cost
--   lines are a planted feature to surface, never filter (RULE-008; V07 censuses them).
-- * quantity_returned / refund_amount are COALESCEd to 0 (the DEF-005/007/008 canonical SQL
--   COALESCEs), so marts can SUM directly; return_date stays NULL when no return.
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
  ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost AS unit_margin,  -- DEF-021 (realized, line grain; current-cost basis)
  CASE WHEN r.return_id IS NOT NULL THEN 1 ELSE 0 END AS is_returned,
  r.return_id,
  COALESCE(r.quantity_returned, 0) AS quantity_returned,  -- DEF-007 numerator input
  COALESCE(r.refund_amount, 0) AS refund_amount,          -- DEF-005 / DEF-008 returned-value input
  r.return_date                                           -- DEF-005 dating input (trend marts date returns by this)
FROM oakhaven_silver.order_items oi
JOIN oakhaven_silver.orders o     ON o.order_id = oi.order_id
JOIN oakhaven_silver.customers c  ON c.customer_id = o.customer_id
JOIN oakhaven_silver.products p   ON p.product_id = oi.product_id   -- DEF-021 cost source (PK join, no fan-out)
LEFT JOIN oakhaven_silver.returns r ON r.order_item_id = oi.order_item_id
WHERE o.status IN ('completed', 'refunded');            -- DEF-003
