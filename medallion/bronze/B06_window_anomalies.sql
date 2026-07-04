-- TASK-20260704-02 · B06_window_anomalies.sql · 2026-07-04
-- PURPOSE: Date-window MIN/MAX sanity (contract §6 criterion 6) + counts of the 5 planted anomalies
--          named in the brief: orders before signup, movements before intro_date, penny lines,
--          below-cost products, orphan transfer_outs. These are FEATURES, not bugs (RULE-008) —
--          bronze states their presence, never removes them.
-- GROUNDING: RULE-008 (planted anomalies surfaced, never cleaned); DEF-017 (sentinel/anomaly framing);
--            oakhaven/DATA_CONTRACT.md §3.14 (transfer_out/transfer_in pairing), §6 criterion 6 (window)
-- RUN: Get-Content B06_window_anomalies.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- ASSUMPTION (flagged, not a formal DEF): transfer_out/transfer_in pairing key. The schema has no
--   explicit column linking a transfer_out to its transfer_in; DATA_CONTRACT §3.14 only says quantity
--   sign differs. Empirically verified in this session: inventory_movements.reference carries a shared
--   'TR-######' token on both sides of a genuine transfer pair (all 3,600 transfer_out rows have a
--   TR-pattern reference; 3,584 of 3,600 transfer_in rows do too, the other 16 transfer_in rows have
--   NULL reference and are unrelated single-sided receipts). Matching transfer_out.reference =
--   transfer_in.reference yields exactly 54 orphans = 1.500% of 3,600 transfer_out rows, matching the
--   contract's stated ~1.5% quota exactly -- treated as confirmation this is the intended pairing key.

-- 1. Date-window MIN/MAX across the four timestamped fact tables
SELECT 'order_ts' AS ts_column, MIN(order_ts) AS min_ts, MAX(order_ts) AS max_ts FROM oakhaven.orders
UNION ALL
SELECT 'payment_ts', MIN(payment_ts), MAX(payment_ts) FROM oakhaven.payments
UNION ALL
SELECT 'shipped_ts', MIN(shipped_ts), MAX(shipped_ts) FROM oakhaven.shipments
UNION ALL
SELECT 'movement_ts', MIN(movement_ts), MAX(movement_ts) FROM oakhaven.inventory_movements
ORDER BY ts_column;

-- 2. Planted anomaly counts (5 named in the brief)
SELECT 'orders before signup (DATE(order_ts) < signup_date)' AS anomaly, COUNT(*) AS n
FROM oakhaven.orders o
JOIN oakhaven.customers c ON c.customer_id = o.customer_id
WHERE DATE(o.order_ts) < c.signup_date
UNION ALL
SELECT 'movements before intro_date (DATE(movement_ts) < intro_date)', COUNT(*)
FROM oakhaven.inventory_movements im
JOIN oakhaven.products p ON p.product_id = im.product_id
WHERE DATE(im.movement_ts) < p.intro_date
UNION ALL
SELECT 'penny lines (order_items.unit_price = 0.01)', COUNT(*)
FROM oakhaven.order_items
WHERE unit_price = 0.01
UNION ALL
SELECT 'below-cost products (list_price < unit_cost)', COUNT(*)
FROM oakhaven.products
WHERE list_price < unit_cost
UNION ALL
SELECT 'orphan transfer_out (no transfer_in sharing its reference)', COUNT(*)
FROM oakhaven.inventory_movements tout
WHERE tout.movement_type = 'transfer_out'
  AND NOT EXISTS (
    SELECT 1 FROM oakhaven.inventory_movements tin
    WHERE tin.movement_type = 'transfer_in' AND tin.reference = tout.reference
  )
ORDER BY anomaly;
