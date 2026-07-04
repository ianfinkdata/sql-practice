-- TASK-20260704-03 · S02_orders.sql · 2026-07-04
-- PURPOSE: Silver orders — passthrough of the clean header columns plus the DEF-016 numeric cast
--          of order_total_text (reconciliation-grade ONLY, never a revenue source).
-- GROUNDING: DEF-016 (order_total_text cast); RULE-003 (never derive money from order_total_text —
--            DEF-002 is the only order-total truth), RULE-005 (grain preserved), RULE-008
--            (orders-before-signup anomaly passes through untouched)
-- RUN: Get-Content S02_orders.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * order_total is RECONCILIATION-GRADE ONLY (DEF-016 caveat / RULE-003): bronze B05 proved
--   CAST(order_total_text) = DEF-002 true total for all 60,000 orders; gold uses DEF-002
--   exclusively. The raw text is retained verbatim as order_total_raw (spec §Silver column
--   conventions: <name> + <name>_raw; renamed from order_total_text per Ian, 2026-07-04).
-- * channel/status are clean enums; order_notes (D9) has no cleaning DEF — raw passthrough.

CREATE OR REPLACE VIEW oakhaven_silver.orders AS
SELECT
  o.order_id,
  o.customer_id,
  o.store_id,
  o.employee_id,
  o.promo_id,
  o.channel,
  o.order_ts,
  o.status,
  -- DEF-016: reconciliation-grade cast ONLY — never a revenue source (RULE-003)
  CAST(REPLACE(REPLACE(TRIM(o.order_total_text), '$', ''), ',', '') AS DECIMAL(10,2)) AS order_total,
  o.order_total_text AS order_total_raw,                -- raw retained (D8 formatting practice column)
  o.order_notes                                         -- D9: no cleaning DEF — raw passthrough (RULE-007)
FROM oakhaven.orders o;
