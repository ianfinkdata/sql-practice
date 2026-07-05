-- TASK-20260705-01 · V07_margin_reconciliation.sql · 2026-07-05
-- PURPOSE: Spot-reconcile the DEF-021 margin columns: hand-computable example lines recomputed
--          straight off BRONZE vs fact_order_lines.unit_margin; below-cost censuses (realized
--          and catalog — RULE-008 features); full-population consistency probes (0 mismatches).
-- GROUNDING: DEF-021 v1.0 (realized unit margin = ROUND(unit_price·(1−disc/100), 2) − unit_cost,
--            rounded BEFORE subtracting; catalog companion = list_price − unit_cost; live census
--            3,534 realized below-cost lines over ALL order lines / 17 catalog below-cost
--            products), DEF-003 (fact scope — the revenue-scope subset of the 3,534 is smaller,
--            derived live in RS2), RULE-008 (below-cost + D17 penny lines are features);
--            RULE-001, RULE-006
-- RUN: Get-Content V07_margin_reconciliation.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 — 3 deterministic (MIN-PK) example lines, each with is_match = 1 (bronze
--           ingredients shown so the margin is hand-checkable with a calculator).
--           RS2 — below_cost_all_lines = 3,534 (DEF-021 caveat census, ALL 156,190 lines);
--           below_cost_revenue_lines + below_cost_out_of_scope = 3,534 (the fact only carries
--           DEF-003 revenue lines — same scope split as the D17 penny lines, Q11);
--           catalog_below_cost = 17 = SUM(is_below_cost) = B06 D16 census.
--           RS3 — all four mismatch counters = 0 (full-population recompute off bronze).

-- RS1: hand-computable spot checks — MIN-PK line overall, MIN-PK realized-below-cost line,
--      MIN-PK D17 penny line; bronze ingredients + DEF-021 recompute vs the fact column
SELECT which, order_item_id, unit_price, line_discount_pct, unit_cost,
       bronze_recomputed_margin, fact_unit_margin,
       bronze_recomputed_margin = fact_unit_margin AS is_match
FROM (
  SELECT * FROM (
    SELECT 'overall_min_pk' AS which, f.order_item_id, oi.unit_price, oi.line_discount_pct,
           p.unit_cost,
           ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost AS bronze_recomputed_margin,  -- DEF-021
           f.unit_margin AS fact_unit_margin
    FROM oakhaven_gold.fact_order_lines f
    JOIN oakhaven.order_items oi ON oi.order_item_id = f.order_item_id
    JOIN oakhaven.products p     ON p.product_id = oi.product_id
    ORDER BY f.order_item_id LIMIT 1
  ) ex1
  UNION ALL
  SELECT * FROM (
    SELECT 'below_cost_min_pk', f.order_item_id, oi.unit_price, oi.line_discount_pct,
           p.unit_cost,
           ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost,              -- DEF-021
           f.unit_margin
    FROM oakhaven_gold.fact_order_lines f
    JOIN oakhaven.order_items oi ON oi.order_item_id = f.order_item_id
    JOIN oakhaven.products p     ON p.product_id = oi.product_id
    WHERE f.unit_margin < 0                                                                       -- RULE-008 feature
    ORDER BY f.order_item_id LIMIT 1
  ) ex2
  UNION ALL
  SELECT * FROM (
    SELECT 'penny_line_min_pk', f.order_item_id, oi.unit_price, oi.line_discount_pct,
           p.unit_cost,
           ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost,              -- DEF-021
           f.unit_margin
    FROM oakhaven_gold.fact_order_lines f
    JOIN oakhaven.order_items oi ON oi.order_item_id = f.order_item_id
    JOIN oakhaven.products p     ON p.product_id = oi.product_id
    WHERE f.unit_price = 0.01                                                                     -- D17 (RULE-008 feature)
    ORDER BY f.order_item_id LIMIT 1
  ) ex3
) examples
ORDER BY which COLLATE utf8mb4_bin;                                   -- RULE-012 (literal alias, pinned collation)

-- RS2: below-cost censuses (RULE-008 — surfaced, never filtered)
SELECT
  (SELECT COUNT(*)
   FROM oakhaven.order_items oi
   JOIN oakhaven.products p ON p.product_id = oi.product_id
   WHERE ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost < 0)
    AS below_cost_all_lines,                                          -- DEF-021 caveat census; expect 3534
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines
   WHERE unit_margin < 0) AS below_cost_revenue_lines,                -- DEF-003 scope subset (derived live)
  (SELECT COUNT(*)
   FROM oakhaven.order_items oi
   JOIN oakhaven.products p ON p.product_id = oi.product_id
   JOIN oakhaven.orders o   ON o.order_id = oi.order_id
   WHERE ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost < 0
     AND o.status NOT IN ('completed', 'refunded'))
    AS below_cost_out_of_scope,                                       -- cancelled/pending remainder
  (SELECT COUNT(*) FROM oakhaven_gold.dim_product
   WHERE catalog_margin < 0) AS catalog_below_cost,                   -- DEF-021 companion; expect 17 (B06 D16)
  (SELECT SUM(is_below_cost) FROM oakhaven_gold.dim_product) AS is_below_cost_flag_total;  -- must equal previous

-- RS3: full-population consistency probes — recompute both DEF-021 forms off bronze; 0 mismatches
SELECT
  (SELECT COUNT(*)
   FROM oakhaven_gold.fact_order_lines f
   JOIN oakhaven.order_items oi ON oi.order_item_id = f.order_item_id
   JOIN oakhaven.products p     ON p.product_id = oi.product_id
   WHERE f.unit_margin <> ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost)
    AS fact_unit_margin_mismatches,                                   -- DEF-021 realized; expect 0
  (SELECT COUNT(*)
   FROM oakhaven_gold.dim_product d
   JOIN oakhaven.products p ON p.product_id = d.product_id
   WHERE d.catalog_margin <> p.list_price - p.unit_cost)
    AS dim_catalog_margin_mismatches,                                 -- DEF-021 companion; expect 0
  (SELECT COUNT(*)
   FROM oakhaven_gold.mart_product_performance m
   JOIN oakhaven_gold.dim_product d ON d.product_id = m.product_id
   WHERE m.catalog_margin <> d.catalog_margin)
    AS mart_catalog_margin_mismatches,                                -- mart carries the dim value; expect 0
  (SELECT COUNT(*)
   FROM oakhaven_gold.dim_product
   WHERE is_below_cost <> (catalog_margin < 0))
    AS below_cost_flag_mismatches;                                    -- D16 flag ⇔ negative catalog margin; expect 0
