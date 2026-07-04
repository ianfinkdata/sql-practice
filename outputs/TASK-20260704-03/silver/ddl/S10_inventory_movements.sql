-- TASK-20260704-03 · S10_inventory_movements.sql · 2026-07-04
-- PURPOSE: Silver inventory_movements — structural passthrough; reference junk (D23) has no
--          cleaning DEF, and the transfer anomalies are features (DEF-019 documents them).
-- GROUNDING: DEF-019 (transfer pairing is a gold-layer reconciliation concern — orphans and
--            reverse-orphans pass through untouched); RULE-005, RULE-007, RULE-008
-- RUN: Get-Content S10_inventory_movements.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * D23 reference mix (MIGRATION / PO-style / junk / NULL) has no cleaning DEF — raw
--   passthrough (RULE-007).
-- * Orphan transfer_outs (54) and reverse-orphan transfer_ins (38) per DEF-019, plus
--   movements-before-intro_date (31,093), are planted/discoverable anomalies — untouched
--   (RULE-008); gold inventory reconciliation handles pairing.

CREATE OR REPLACE VIEW oakhaven_silver.inventory_movements AS
SELECT
  m.movement_id,
  m.product_id,
  m.store_id,
  m.movement_ts,                                        -- before-intro anomaly untouched (RULE-008)
  m.movement_type,
  m.quantity,
  m.reference,                                          -- D23: no cleaning DEF — raw passthrough
  m.unit_cost_at_time
FROM oakhaven.inventory_movements m;
