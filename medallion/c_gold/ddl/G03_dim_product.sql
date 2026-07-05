-- TASK-20260705-01 · G03_dim_product.sql · 2026-07-05 (amends TASK-20260704-04 version — additive)
-- PURPOSE: Gold dim_product — product dimension with category name + parent-category rollup
--          (report-spec R2 needs the rollup) and the D16 below-cost anomaly flag surfaced.
--          AMENDED: catalog_margin added per DEF-021 (catalog companion, list_price − unit_cost).
-- GROUNDING: medallion-spec §Gold rules (dim_product); DEF-009 (discontinued_flag, cleaned in
--            silver), DEF-017 (weight sentinel, cleaned in silver), DEF-021 v1.0 (catalog margin
--            companion — product grain, feeds the R2 price-vs-cost scatter);
--            RULE-008 (D16 below-cost list prices are a planted FEATURE — flagged, never fixed;
--            B06 census = 17 rows; catalog_margin < 0 for exactly those rows)
-- RUN: Get-Content G03_dim_product.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * parent_category_name/id: a top-level category (parent_category_id IS NULL) rolls up to
--   ITSELF — structural join on oakhaven_silver.product_categories, no business logic.
-- * unit_cost and list_price stay surfaced RAW; catalog_margin is the DEF-021 companion
--   measure (exact DECIMAL subtraction — both operands are exact 2dp, no rounding needed).
--   is_below_cost = 1 ⇔ catalog_margin < 0 (V07 cross-checks).
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
  p.unit_cost,                                          -- DEF-021 cost basis (current cost — stated limitation)
  p.list_price,                                         -- D16 below-cost values untouched (RULE-008)
  p.list_price - p.unit_cost AS catalog_margin,         -- DEF-021 (catalog companion, product grain)
  CASE WHEN p.list_price < p.unit_cost THEN 1 ELSE 0 END AS is_below_cost,  -- D16 planted anomaly flag (RULE-008; B06 = 17)
  p.weight_kg,                                          -- DEF-017 (sentinel already NULLed in silver)
  p.is_weight_sentinel,                                 -- DEF-017
  p.intro_date,
  p.discontinued_flag,                                  -- DEF-009 (normalized 0/1 in silver)
  p.color
FROM oakhaven_silver.products p
JOIN oakhaven_silver.product_categories pc ON pc.category_id = p.category_id
LEFT JOIN oakhaven_silver.product_categories pp ON pp.category_id = pc.parent_category_id;
