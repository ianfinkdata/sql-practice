-- TASK-20260704-01 · P05_orphan_transfers.sql · 2026-07-04
-- PURPOSE: Live count of orphan transfer_out rows (planted anomaly D-pattern, CONTRACT 3.14)
-- Transfers are linked via inventory_movements.reference (shared 'TR-xxxxxx' token between
-- a transfer_out and its matching transfer_in). An orphan = transfer_out whose reference
-- token has no corresponding transfer_in row.
SELECT '--transfer_out / transfer_in totals--' AS marker;
SELECT movement_type, COUNT(*) c FROM oakhaven.inventory_movements WHERE movement_type IN ('transfer_out','transfer_in') GROUP BY movement_type ORDER BY movement_type;

SELECT '--transfer_out rows with NULL reference--' AS marker;
SELECT COUNT(*) FROM oakhaven.inventory_movements WHERE movement_type = 'transfer_out' AND reference IS NULL;

SELECT '--orphan transfer_out count (reference has no matching transfer_in)--' AS marker;
SELECT COUNT(*) FROM oakhaven.inventory_movements t
WHERE t.movement_type = 'transfer_out'
  AND t.reference IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM oakhaven.inventory_movements i
    WHERE i.movement_type = 'transfer_in' AND i.reference = t.reference
  );

SELECT '--orphan transfer_out pct of all transfer_out--' AS marker;
SELECT ROUND(
  (SELECT COUNT(*) FROM oakhaven.inventory_movements t
   WHERE t.movement_type = 'transfer_out' AND t.reference IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM oakhaven.inventory_movements i WHERE i.movement_type = 'transfer_in' AND i.reference = t.reference))
  / (SELECT COUNT(*) FROM oakhaven.inventory_movements WHERE movement_type = 'transfer_out') * 100, 2) AS orphan_pct;

SELECT '--example orphan transfer_out rows--' AS marker;
SELECT t.movement_id, t.product_id, t.store_id, t.movement_ts, t.reference, t.quantity
FROM oakhaven.inventory_movements t
WHERE t.movement_type = 'transfer_out'
  AND t.reference IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM oakhaven.inventory_movements i
    WHERE i.movement_type = 'transfer_in' AND i.reference = t.reference
  )
ORDER BY t.movement_id LIMIT 3;
