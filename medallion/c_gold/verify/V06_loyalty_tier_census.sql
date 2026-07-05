-- TASK-20260705-01 · V06_loyalty_tier_census.sql · 2026-07-05
-- PURPOSE: Prove the DEF-020 loyalty-tier normalization applied in gold: full-base census hits
--          the B03-reconciled mapped totals (basic 7,296 · silver 2,583 · gold 1,491 ·
--          platinum 630 = 12,000) with ZERO NULL leaks, all 20 raw variants covered under a
--          NO PAD binary collation, and the gold dim_customer surface leak-free.
-- GROUNDING: DEF-020 v1.0 (canonical CASE + ordinal rank; B03 mapped totals; zero-NULL law),
--            DEF-014 (dim_customer is canonical grain — 11,866 rows, so the 12,000-total census
--            runs the gold expression over the full silver base); RULE-007 (ELSE NULL tripwire),
--            RULE-011 (census REQUIRES COLLATE utf8mb4_0900_bin — NO PAD — or trailing-space
--            variants silently merge), RULE-001, RULE-006
-- RUN: Get-Content V06_loyalty_tier_census.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 — 4 rows in rank order: basic 7,296 · silver 2,583 · gold 1,491 · platinum 630;
--           each tier covers 5 raw variants (20 total).
--           RS2 — mapped_total = silver_customers = 12,000; all four leak/mismatch counters = 0.
--           RS3 — raw_variants_binary = 20 (NO PAD binary collation, RULE-011).
--           RS4 — gold dim_customer census (canonical grain, sums to 11,866), zero NULLs —
--           derived live, informational: absorbed dupes keep their ORIGINAL's tier here, and one
--           absorbed dupe's own raw tier differs from its original's, so this census is NOT
--           expected to re-sum to the RS1 totals when weighted.

-- RS1: full-base census — the EXACT gold DEF-020 expression over all 12,000 silver customers
SELECT
  CASE UPPER(TRIM(c.loyalty_tier))
    WHEN 'BASIC'    THEN 'basic'
    WHEN 'SILVER'   THEN 'silver'
    WHEN 'GOLD'     THEN 'gold'
    WHEN 'PLATINUM' THEN 'platinum'
    ELSE NULL
  END AS tier,                                                        -- DEF-020
  CASE UPPER(TRIM(c.loyalty_tier))
    WHEN 'BASIC'    THEN 1
    WHEN 'SILVER'   THEN 2
    WHEN 'GOLD'     THEN 3
    WHEN 'PLATINUM' THEN 4
    ELSE NULL
  END AS tier_rank,                                                   -- DEF-020 (ordinal)
  COUNT(*) AS n_customers,                                            -- expect 7296/2583/1491/630
  COUNT(DISTINCT c.loyalty_tier COLLATE utf8mb4_0900_bin) AS n_raw_variants  -- RULE-011 (NO PAD)
FROM oakhaven_silver.customers c
GROUP BY tier, tier_rank
ORDER BY tier_rank;                                                   -- DEF-020: rank order, never alphabet

-- RS2: zero-NULL-leak + total accounting (DEF-020 caveat: mapped totals sum to 12,000)
SELECT
  (SELECT COUNT(*) FROM oakhaven_silver.customers) AS silver_customers,        -- expect 12000
  (SELECT COUNT(*) FROM oakhaven_silver.customers
    WHERE CASE UPPER(TRIM(loyalty_tier))
            WHEN 'BASIC' THEN 'basic' WHEN 'SILVER' THEN 'silver'
            WHEN 'GOLD' THEN 'gold' WHEN 'PLATINUM' THEN 'platinum'
            ELSE NULL END IS NOT NULL) AS mapped_total,                        -- DEF-020; expect 12000
  (SELECT COUNT(*) FROM oakhaven_silver.customers
    WHERE CASE UPPER(TRIM(loyalty_tier))
            WHEN 'BASIC' THEN 'basic' WHEN 'SILVER' THEN 'silver'
            WHEN 'GOLD' THEN 'gold' WHEN 'PLATINUM' THEN 'platinum'
            ELSE NULL END IS NULL) AS full_base_null_leaks,                    -- RULE-007 tripwire; expect 0
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer
    WHERE loyalty_tier IS NULL) AS dim_tier_null_leaks,                        -- expect 0
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer
    WHERE loyalty_tier_rank IS NULL) AS dim_rank_null_leaks,                   -- expect 0
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer
    WHERE (loyalty_tier, loyalty_tier_rank) NOT IN
          (('basic', 1), ('silver', 2), ('gold', 3), ('platinum', 4))) AS tier_rank_mismatches;  -- DEF-020 bijection; expect 0

-- RS3: raw-variant coverage under NO PAD binary collation (RULE-011 — utf8mb4_0900_bin so
-- trailing-space variants do NOT merge; B03 census = 20 variants)
SELECT
  COUNT(DISTINCT c.loyalty_tier COLLATE utf8mb4_0900_bin) AS raw_variants_binary,  -- expect 20
  COUNT(DISTINCT c.loyalty_tier) AS raw_variants_default_collation                 -- ai_ci+PAD: merges — shown for contrast
FROM oakhaven_silver.customers c;

-- RS4: the gold surface census — dim_customer (DEF-014 canonical grain, 11,866 rows)
SELECT
  d.loyalty_tier,                                                     -- DEF-020
  d.loyalty_tier_rank,                                                -- DEF-020
  COUNT(*) AS n_canonical_customers,
  SUM(d.n_source_ids) AS n_source_customers                           -- DEF-014 accounting (sums to 12,000 overall)
FROM oakhaven_gold.dim_customer d
GROUP BY d.loyalty_tier, d.loyalty_tier_rank
ORDER BY d.loyalty_tier_rank;                                         -- DEF-020: rank order
