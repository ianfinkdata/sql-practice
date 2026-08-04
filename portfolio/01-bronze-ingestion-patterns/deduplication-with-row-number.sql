-- =============================================================================
-- PATTERN: Deduplication with ROW_NUMBER()
-- =============================================================================
-- PROBLEM
--   A source table has near-duplicate rows for the same real-world entity
--   (e.g. a customer who signed up twice, an upstream system that emits a
--   new row on every touch instead of upserting) and you need to pick a
--   single "canonical" row per entity without a hard uniqueness key to
--   GROUP BY on directly.
--
-- WHEN TO REACH FOR IT
--   - You have a natural/business key that survives light normalization
--     (lowercasing, trimming) even though the raw values differ in casing,
--     whitespace, or formatting.
--   - You need to choose ONE row per key using a tiebreaker (oldest,
--     newest, "most complete", lowest surrogate id, etc.) rather than just
--     counting or discarding blindly.
--   - You want the decision to be auditable: every row keeps its rank, so
--     you can inspect what was dropped before you commit to dropping it.
--
-- HOW IT WORKS
--   1. Normalize the candidate key the same way you'd want a human to
--      compare it (LOWER + TRIM is usually enough; collapse internal
--      whitespace if names/addresses are involved).
--   2. ROW_NUMBER() OVER (PARTITION BY normalized_key ORDER BY <tiebreak>)
--      assigns 1..N within each duplicate group.
--   3. Keep rn = 1 for "one row per entity"; keep rn > 1 to inspect/report
--      what would be dropped (never silently discard in bronze/silver --
--      surface it, let a downstream consumer decide).
--
-- REAL EXAMPLE (Oakhaven)
--   bronze_customers has 600 rows, but customer_ids 571-600 are 30
--   intentional near-duplicates of 30 of the base 1-570 rows: same person
--   (same email once you LOWER+TRIM it) re-entered with different name
--   casing/whitespace, phone, state, signup_date, is_active, and segment
--   values -- exactly what "customer filled out the signup form twice"
--   looks like in a real CRM export. This query finds those duplicate
--   groups and ranks the rows within each group by customer_id, so
--   downstream you can decide "keep the earliest signup" (rn = 1) vs. flag
--   the rest for merge/review.
--
--   Verified against project/oakhaven.db:
--     SELECT COUNT(*) FROM (
--       SELECT LOWER(TRIM(email)) AS norm_email FROM bronze_customers
--       WHERE email IS NOT NULL AND TRIM(email) <> ''
--       GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1
--     );
--   --> 29 duplicate email groups found (of the ~30 documented near-dupes;
--       one near-dupe pair does not share a matching email after
--       normalization -- a reminder that dedup keys are never 100% clean
--       even by design, so always spot-check the miss rate).
--
-- SAMPLE OUTPUT (first 6 rows of the working query below, real data)
--   customer_id  first_name  last_name  email                       rn
--   -----------  ----------  ---------  --------------------------  --
--   165          ALEXANDRA   Wang       alexandra.wang@yahoo.com    1
--   581          ALEXANDRA   Wang       alexandra.wang@yahoo.com    2
--   439          Andrew      Anderson   andrew.anderson@icloud.com  1
--   598           ANDREW     ANDERSON   ANDREW.ANDERSON@ICLOUD.COM  2
--   234          ashley      Moore      ashley.moore@hotmail.com    1
--   586          Ashley      moore      ASHLEY.MOORE@HOTMAIL.COM    2
--
-- PORTABILITY
--   ROW_NUMBER() is standard ANSI SQL window function syntax -- identical
--   on SQLite, Postgres, Snowflake, BigQuery, and Databricks. No dialect
--   differences here. The only thing that varies across engines is how you
--   *act* on the ranked result: SQLite/Postgres/Databricks can DELETE
--   using a CTE or subquery; BigQuery favors `QUALIFY ROW_NUMBER() OVER
--   (...) = 1` to filter in the same statement instead of wrapping in a
--   subquery (Snowflake and Databricks SQL support QUALIFY too; Postgres
--   and SQLite do not, so on those two you wrap in a CTE/subquery as done
--   below).
-- =============================================================================

-- Step 1: identify duplicate groups by normalized key, with a rank within
-- each group. `rn = 1` is the row you'd keep if you must pick exactly one.
WITH ranked AS (
    SELECT
        customer_id,
        first_name,
        last_name,
        email,
        LOWER(TRIM(email)) AS norm_email,
        ROW_NUMBER() OVER (
            PARTITION BY LOWER(TRIM(email))
            ORDER BY customer_id            -- tiebreak: keep the earliest-assigned id
        ) AS rn
    FROM bronze_customers
    WHERE email IS NOT NULL AND TRIM(email) <> ''
)
SELECT customer_id, first_name, last_name, email, rn
FROM ranked
WHERE norm_email IN (
    SELECT LOWER(TRIM(email))
    FROM bronze_customers
    GROUP BY LOWER(TRIM(email))
    HAVING COUNT(*) > 1
)
ORDER BY norm_email, rn;

-- Step 2 (illustrative -- do not run against the shared oakhaven.db): once
-- you trust the tiebreak, materializing a deduplicated table/view is just
-- filtering to rn = 1:
--
-- CREATE VIEW customers_deduped AS
-- WITH ranked AS (
--     SELECT c.*,
--            ROW_NUMBER() OVER (
--                PARTITION BY LOWER(TRIM(email))
--                ORDER BY customer_id
--            ) AS rn
--     FROM bronze_customers c
--     WHERE email IS NOT NULL AND TRIM(email) <> ''
-- )
-- SELECT * FROM ranked WHERE rn = 1;
--
-- On BigQuery the equivalent is a single pass with QUALIFY, no wrapping
-- CTE needed:
--   SELECT *
--   FROM bronze_customers
--   QUALIFY ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) = 1;
