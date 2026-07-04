-- TASK-20260704-03 · S06_returns.sql · 2026-07-04
-- PURPOSE: Silver returns — structural passthrough; the dirty columns (reason D22,
--          condition_code vocabulary mix) have no cleaning DEF and stay raw.
-- GROUNDING: RULE-005 (grain preserved), RULE-007 (no invented mappings — reason/condition_code
--            pass through raw until a DEF exists); medallion-spec §Silver rules
-- RUN: Get-Content S06_returns.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * reason (D22: NULLs + casing dupes + free text) and condition_code (A/B/C/used/LIKE NEW
--   vocabulary mix) are dirty but have NO controlled-vocabulary DEF — mapping them would be
--   invented business logic (RULE-007). Raw passthrough; a future DEF can clean them.
-- * refund_amount/quantity_returned are structural (DEF-005/007/008 consume them in gold).

CREATE OR REPLACE VIEW oakhaven_silver.returns AS
SELECT
  r.return_id,
  r.order_item_id,
  r.return_date,
  r.quantity_returned,
  r.reason,                                             -- D22: no cleaning DEF — raw passthrough
  r.refund_amount,
  r.condition_code                                      -- vocabulary mix: no cleaning DEF — raw passthrough
FROM oakhaven.returns r;
