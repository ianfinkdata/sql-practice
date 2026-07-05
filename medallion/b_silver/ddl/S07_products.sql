-- TASK-20260704-03 · S07_products.sql · 2026-07-04
-- PURPOSE: Silver products — DEF-009 discontinued_flag normalization + DEF-017 weight_kg
--          sentinel policy (-999 -> NULL + flag).
-- GROUNDING: DEF-009 (discontinued_flag), DEF-017 (weight_kg = -999 -> NULL + is_weight_sentinel);
--            RULE-005 (grain preserved), RULE-007 (explicit CASE list, ELSE NULL tripwire),
--            RULE-008 (D16 below-cost list prices pass through untouched)
-- RUN: Get-Content S07_products.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * D16 below-cost list prices (17 rows) are a planted anomaly — untouched (RULE-008).
-- * product_name spacing/casing (D15), sku legacy format, color casing have no cleaning DEF —
--   raw passthrough (RULE-007).
-- * is_weight_sentinel must sum to 9 (bronze B04 D13 census); NULL weight (51 rows) stays
--   NULL with flag 0 (missing, not sentinel).

CREATE OR REPLACE VIEW oakhaven_silver.products AS
SELECT
  p.product_id,
  p.sku,
  p.product_name,                                       -- D15: no cleaning DEF — raw passthrough
  p.category_id,
  p.supplier_id,
  p.unit_cost,
  p.list_price,                                         -- D16 below-cost untouched (RULE-008)
  -- DEF-017: -999 sentinel -> NULL + flag (keeps weight_kg_raw)
  CASE WHEN p.weight_kg = -999 THEN NULL ELSE p.weight_kg END AS weight_kg,
  p.weight_kg AS weight_kg_raw,
  CASE WHEN p.weight_kg = -999 THEN 1 ELSE 0 END AS is_weight_sentinel,   -- DEF-017
  p.intro_date,                                         -- movements-before-intro anomaly untouched (RULE-008)
  -- DEF-009: boolean normalization (lossy: keeps discontinued_flag_raw; ELSE NULL = unmapped tripwire)
  CASE WHEN UPPER(TRIM(p.discontinued_flag)) IN ('Y', 'YES', '1', 'TRUE')  THEN 1
       WHEN UPPER(TRIM(p.discontinued_flag)) IN ('N', 'NO', '0', 'FALSE') THEN 0
       ELSE NULL END AS discontinued_flag,
  p.discontinued_flag AS discontinued_flag_raw,
  p.color                                               -- casing mix: no cleaning DEF — raw passthrough
FROM oakhaven.products p;
