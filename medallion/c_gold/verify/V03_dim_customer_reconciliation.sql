-- TASK-20260704-04 · V03_dim_customer_reconciliation.sql · 2026-07-05
-- PURPOSE: Prove the DEF-014 collapse: dim_customer = 12,000 silver customers − collapsed
--          dupes, reconciled against oakhaven_silver.customer_dupe_map (not hardcoded), and
--          that every fact canonical key resolves to a dim row.
-- GROUNDING: DEF-014 v1.1 (near-dupe resolution; live split 134 phone-resolved + 16 unresolved);
--            silver capture medallion/b_silver/EXPECTED_OUTPUTS.md V06; RULE-001, RULE-006
-- RUN: Get-Content V03_dim_customer_reconciliation.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 — dim_customers = silver_customers − collapsed_dupes (12,000 − 134 = 11,866),
--           both collapse measures agree, is_match = 1.
--           RS2 — source-id accounting: SUM(n_source_ids) = 12,000; SUM(n_source_ids − 1) = 134;
--           survivor count = distinct originals from the dupe map.
--           RS3 — zero fact canonical ids missing from dim_customer (both facts).

-- RS1: the collapse arithmetic, derived from the DEF-014 helper view (never hardcoded)
SELECT
  (SELECT COUNT(*) FROM oakhaven_silver.customers) AS silver_customers,
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer) AS dim_customers,
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map
    WHERE dupe_resolution <> 'unresolved') AS collapsed_dupes,                    -- DEF-014
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map
    WHERE canonical_customer_id <> customer_id) AS collapsed_by_canonical,        -- DEF-014 (must equal previous)
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer) =
  (SELECT COUNT(*) FROM oakhaven_silver.customers) -
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map
    WHERE dupe_resolution <> 'unresolved') AS is_match;

-- RS2: n_source_ids accounting (DEF-014: every silver row lands in exactly one dim row)
SELECT
  (SELECT SUM(n_source_ids) FROM oakhaven_gold.dim_customer) AS sum_source_ids,          -- expect 12000
  (SELECT SUM(n_source_ids - 1) FROM oakhaven_gold.dim_customer) AS absorbed_dupes,      -- expect 134
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer WHERE is_dupe_survivor = 1) AS dupe_survivors,
  (SELECT COUNT(DISTINCT canonical_customer_id) FROM oakhaven_silver.customer_dupe_map
    WHERE dupe_resolution <> 'unresolved') AS distinct_originals_in_map;                 -- expect = dupe_survivors

-- RS3: referential closure — every canonical key used by the facts exists in dim_customer
SELECT
  (SELECT COUNT(*) FROM (SELECT DISTINCT canonical_customer_id FROM oakhaven_gold.fact_orders) f
    LEFT JOIN oakhaven_gold.dim_customer d ON d.customer_id = f.canonical_customer_id
    WHERE d.customer_id IS NULL) AS fact_orders_missing_canonicals,
  (SELECT COUNT(*) FROM (SELECT DISTINCT canonical_customer_id FROM oakhaven_gold.fact_order_lines) f
    LEFT JOIN oakhaven_gold.dim_customer d ON d.customer_id = f.canonical_customer_id
    WHERE d.customer_id IS NULL) AS fact_lines_missing_canonicals;
