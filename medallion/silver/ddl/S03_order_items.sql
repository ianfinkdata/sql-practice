-- TASK-20260704-03 · S03_order_items.sql · 2026-07-04
-- PURPOSE: Silver order_items — trivial passthrough (scope amendment, Ian-approved 2026-07-04:
--          14th silver view so the layer is complete and self-sufficient).
-- GROUNDING: RULE-008 (D17 penny-price lines are a planted anomaly — pass through untouched);
--            medallion-spec §Silver rules (complete, self-sufficient layer)
-- RUN: Get-Content S03_order_items.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * The ONLY dirt here is D17 (297 penny-price lines, unit_price = 0.01) — a planted anomaly
--   that is a FEATURE (RULE-008): no transform, no flag, verbatim passthrough.
-- * This table is the numeric revenue backbone (DEF-001/DEF-002 operate directly on it).

CREATE OR REPLACE VIEW oakhaven_silver.order_items AS
SELECT
  oi.order_item_id,
  oi.order_id,
  oi.product_id,
  oi.quantity,
  oi.unit_price,                                        -- D17 penny prices untouched (RULE-008)
  oi.line_discount_pct
FROM oakhaven.order_items oi;
