-- TASK-20260704-03 · S05_shipments.sql · 2026-07-04
-- PURPOSE: Silver shipments — DEF-011 delivered-date parse (mixed text formats -> DATE) plus
--          is_delivery_pending flag.
-- GROUNDING: DEF-011 (delivered-date parse rule, formats per CONTRACT D10); RULE-005 (grain
--            preserved), RULE-007 (no cleaning DEF for carrier D11 / tracking dupes D25 — raw)
-- RUN: Get-Content S05_shipments.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * DEF-011 verification target: parsed NULLs = raw NULL (1,840) + 'PENDING' (1,165) = 3,005
--   exactly; is_delivery_pending sums to 1,165.
-- * carrier casing (D11) and tracking_number duplicates (D25) have no cleaning DEF — raw
--   passthrough (RULE-007); D25 is discoverable dirt left visible.

CREATE OR REPLACE VIEW oakhaven_silver.shipments AS
SELECT
  s.shipment_id,
  s.order_id,
  s.carrier,                                            -- D11 casing dirt: no cleaning DEF — raw passthrough
  s.shipped_ts,
  -- DEF-011: delivered-date parse (lossy: keeps delivered_date_raw)
  CASE
    WHEN s.delivered_date_raw IS NULL OR s.delivered_date_raw = 'PENDING' THEN NULL
    WHEN s.delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN CAST(s.delivered_date_raw AS DATE)
    WHEN s.delivered_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN STR_TO_DATE(s.delivered_date_raw, '%m/%d/%Y')
    ELSE STR_TO_DATE(s.delivered_date_raw, '%b %e, %Y')
  END AS delivered_date,
  s.delivered_date_raw,
  CASE WHEN s.delivered_date_raw = 'PENDING' THEN 1 ELSE 0 END AS is_delivery_pending,  -- DEF-011 caveat
  s.tracking_number,                                    -- D25 dup values: no cleaning DEF — raw passthrough
  s.ship_cost
FROM oakhaven.shipments s;
