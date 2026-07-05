-- TASK-20260704-04 · G03_dim_product.sql · 2026-07-05
-- PURPOSE: Gold dim_product — product dimension with category name + parent-category rollup
--          (report-spec R2 needs the rollup) and the D16 below-cost anomaly flag surfaced.
-- GROUNDING: medallion-spec §Gold rules (dim_product); DEF-009 (discontinued_flag, cleaned in
--            silver), DEF-017 (weight sentinel, cleaned in silver); RULE-008 (D16 below-cost
--            list prices are a planted FEATURE — flagged, never fixed; B06 census = 17 rows)
-- RUN: Get-Content G03_dim_product.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * parent_category_name/id: a top-level category (parent_category_id IS NULL) rolls up to
--   ITSELF — structural join on oakhaven_silver.product_categories, no business logic.
-- * unit_cost and list_price are surfaced RAW. No unit-margin measure is derived here:
--   "unit margin" has NO DEF in grounding/definitions.md (escalated as MISSING DEFINITION
--   in the task handoff — medallion-spec §Gold names it, the registry does not define it).
-- * Grain: 850 rows, 1:1 with silver/bronze products (verified in V02).

CREATE OR REPLACE VIEW oakhaven_gold.dim_product AS
SELECT
  p.product_id,
  p.sku,
  p.product_name,
  p.category_id,
  pc.category_name,
  COALESCE(pp.category_id,   pc.category_id)   AS parent_category_id,
  COALESCE(pp.category_name, pc.category_name) AS parent_category_name,
  p.supplier_id,
  p.unit_cost,                                          -- raw input; no margin DEF exists (see NOTES)
  p.list_price,                                         -- D16 below-cost values untouched (RULE-008)
  CASE WHEN p.list_price < p.unit_cost THEN 1 ELSE 0 END AS is_below_cost,  -- D16 planted anomaly flag (RULE-008; B06 = 17)
  p.weight_kg,                                          -- DEF-017 (sentinel already NULLed in silver)
  p.is_weight_sentinel,                                 -- DEF-017
  p.intro_date,
  p.discontinued_flag,                                  -- DEF-009 (normalized 0/1 in silver)
  p.color
FROM oakhaven_silver.products p
JOIN oakhaven_silver.product_categories pc ON pc.category_id = p.category_id
LEFT JOIN oakhaven_silver.product_categories pp ON pp.category_id = pc.parent_category_id;
