-- TASK-20260704-03 · S01_customers.sql · 2026-07-04
-- PURPOSE: Silver customers — email/phone/state/boolean normalization, birth-date sentinel policy,
--          and the DEF-014 near-dupe resolution map (helper view + canonical_customer_id).
-- GROUNDING: DEF-009 (marketing_opt_in), DEF-010 (phone), DEF-012 (state), DEF-014 (dupe map),
--            DEF-015 (email), DEF-017 (birth_date sentinels + is_age_outlier); RULE-005 (flag, never filter),
--            RULE-007 (explicit CASE lists, ELSE NULL tripwire), RULE-009 (window end constant '2026-06-30')
-- RUN: Get-Content S01_customers.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * Two CREATE statements: helper view `customer_dupe_map` (DEF-014 resolution, computed
--   deterministically from DEF-010/DEF-015 matching — no hardcoded id lists), then `customers`.
-- * Grain: 12,000 rows, 1:1 with bronze (RULE-005). The DEF-014 collapse happens in GOLD
--   dim_customer, not here — silver only carries canonical_customer_id + dupe_resolution.
-- * Columns with dirt but no cleaning DEF (city casing D4, loyalty_tier casing D6,
--   postal_code 4-digit) pass through raw — no invented logic (RULE-007).
-- * Planted anomaly "orders before signup_date" lives in orders vs signup_date and passes
--   through untouched (RULE-008); signup_date is copied verbatim.

-- ---------------------------------------------------------------------------
-- Helper: DEF-014 near-dupe resolution map (one row per candidate 11851–12000)
-- Rule 1: candidates = customer_id BETWEEN 11851 AND 12000 (CONTRACT D7, exactly 150 rows).
-- Rule 2: match to an original (id <= 11850) on normalized phone (DEF-010) when the
--         candidate's phone10 is non-NULL and that phone10 is UNIQUE among originals.
-- Rule 3: fallback — normalized email (DEF-015) local-part equality + same birth_date
--         (raw bronze birth_date equality, both non-NULL), requiring exactly one matching
--         original (ambiguity is never guessed).
-- Rule 4: unresolved -> canonical_customer_id = customer_id, dupe_resolution = 'unresolved'.
-- dupe_resolution vocabulary: 'phone' | 'email_birth_date' | 'unresolved' (candidates only).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW oakhaven_silver.customer_dupe_map AS
WITH
originals AS (
  SELECT customer_id,
         -- DEF-010 normalized phone
         CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone, ''), '[^0-9]', '')) >= 10
              THEN RIGHT(REGEXP_REPLACE(phone, '[^0-9]', ''), 10)
              ELSE NULL END AS phone10,
         -- DEF-015 normalized email
         CASE WHEN LOWER(TRIM(email)) IN ('n/a', 'none') OR TRIM(COALESCE(email, '')) = '' THEN NULL
              ELSE LOWER(TRIM(email)) END AS email_norm,
         birth_date
  FROM oakhaven.customers
  WHERE customer_id <= 11850
),
candidates AS (
  SELECT customer_id,
         -- DEF-010 normalized phone
         CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone, ''), '[^0-9]', '')) >= 10
              THEN RIGHT(REGEXP_REPLACE(phone, '[^0-9]', ''), 10)
              ELSE NULL END AS phone10,
         -- DEF-015 normalized email
         CASE WHEN LOWER(TRIM(email)) IN ('n/a', 'none') OR TRIM(COALESCE(email, '')) = '' THEN NULL
              ELSE LOWER(TRIM(email)) END AS email_norm,
         birth_date
  FROM oakhaven.customers
  WHERE customer_id BETWEEN 11851 AND 12000            -- DEF-014 rule 1
),
unique_orig_phone AS (                                  -- DEF-014 rule 2: phone unique among originals
  SELECT phone10, MIN(customer_id) AS original_id      -- MIN is cosmetic: HAVING guarantees 1 row
  FROM originals
  WHERE phone10 IS NOT NULL
  GROUP BY phone10
  HAVING COUNT(*) = 1
),
phone_match AS (
  SELECT c.customer_id, u.original_id
  FROM candidates c
  JOIN unique_orig_phone u ON u.phone10 = c.phone10
),
email_match AS (                                        -- DEF-014 rule 3 fallback
  SELECT c.customer_id, MIN(o.customer_id) AS original_id
  FROM candidates c
  JOIN originals o
    ON  o.email_norm IS NOT NULL AND c.email_norm IS NOT NULL
    AND SUBSTRING_INDEX(o.email_norm, '@', 1) = SUBSTRING_INDEX(c.email_norm, '@', 1)
    AND o.birth_date IS NOT NULL AND c.birth_date IS NOT NULL
    AND o.birth_date = c.birth_date
  WHERE c.customer_id NOT IN (SELECT customer_id FROM phone_match)
  GROUP BY c.customer_id
  HAVING COUNT(DISTINCT o.customer_id) = 1              -- exactly one match — never guess ambiguity
)
SELECT c.customer_id,
       COALESCE(pm.original_id, em.original_id, c.customer_id) AS canonical_customer_id,  -- DEF-014 rule 4
       CASE WHEN pm.original_id IS NOT NULL THEN 'phone'
            WHEN em.original_id IS NOT NULL THEN 'email_birth_date'
            ELSE 'unresolved' END AS dupe_resolution
FROM candidates c
LEFT JOIN phone_match pm ON pm.customer_id = c.customer_id
LEFT JOIN email_match em ON em.customer_id = c.customer_id;

-- ---------------------------------------------------------------------------
-- Silver customers (12,000 rows, 1:1 with oakhaven.customers)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW oakhaven_silver.customers AS
SELECT
  c.customer_id,
  c.first_name,
  c.middle_name,
  c.last_name,
  -- DEF-015: email normalization (lossy: keeps email_raw)
  CASE WHEN LOWER(TRIM(c.email)) IN ('n/a', 'none') OR TRIM(COALESCE(c.email, '')) = '' THEN NULL
       ELSE LOWER(TRIM(c.email)) END AS email,
  c.email AS email_raw,
  -- DEF-010: phone normalization (lossy: keeps phone_raw)
  CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(c.phone, ''), '[^0-9]', '')) >= 10
       THEN RIGHT(REGEXP_REPLACE(c.phone, '[^0-9]', ''), 10)
       ELSE NULL END AS phone,
  c.phone AS phone_raw,
  c.street_address,
  c.city,                                                -- D4 casing dirt: no cleaning DEF — raw passthrough (RULE-007)
  -- DEF-012 v1.1: state normalization (lossy: keeps state_raw; ELSE NULL = unmapped tripwire)
  CASE
    WHEN CHAR_LENGTH(TRIM(c.state)) = 2               THEN UPPER(TRIM(c.state))
    WHEN TRIM(c.state) IN ('Washington', 'Wash.')     THEN 'WA'
    WHEN TRIM(c.state) IN ('Oregon',     'Ore.')      THEN 'OR'
    WHEN TRIM(c.state) IN ('Idaho',      'Ida.')      THEN 'ID'
    WHEN TRIM(c.state) IN ('Montana',    'Mont.')     THEN 'MT'
    WHEN TRIM(c.state) IN ('California', 'Calif.')    THEN 'CA'
    ELSE NULL
  END AS state,
  c.state AS state_raw,
  c.postal_code,
  -- DEF-017: birth_date sentinel policy (window end constant '2026-06-30', RULE-009; keeps birth_date_raw)
  CASE WHEN c.birth_date = '1900-01-01' THEN NULL
       WHEN c.birth_date > '2026-06-30' THEN NULL
       ELSE c.birth_date END AS birth_date,
  c.birth_date AS birth_date_raw,
  CASE WHEN c.birth_date = '1900-01-01' THEN 1 ELSE 0 END AS is_birth_date_sentinel,    -- DEF-017
  CASE WHEN c.birth_date IS NOT NULL AND c.birth_date <> '1900-01-01'
            AND c.birth_date > '2026-06-30' THEN 1 ELSE 0 END AS is_birth_date_future,  -- DEF-017
  -- DEF-017 caveat: age > 95 as of 2026-06-30 is plausible-not-impossible — kept, flagged only.
  -- Predicate matches bronze B04 D5 probe exactly (TIMESTAMPDIFF(YEAR, ...) > 95).
  CASE WHEN c.birth_date IS NOT NULL AND c.birth_date <> '1900-01-01' AND c.birth_date <= '2026-06-30'
            AND TIMESTAMPDIFF(YEAR, c.birth_date, '2026-06-30') > 95 THEN 1 ELSE 0 END AS is_age_outlier,
  c.signup_date,                                        -- orders-before-signup anomaly untouched (RULE-008)
  c.loyalty_tier,                                       -- D6 casing dirt: no cleaning DEF — raw passthrough (RULE-007)
  -- DEF-009: boolean normalization (lossy: keeps marketing_opt_in_raw; ELSE NULL = unmapped tripwire)
  CASE WHEN UPPER(TRIM(c.marketing_opt_in)) IN ('Y', 'YES', '1', 'TRUE')  THEN 1
       WHEN UPPER(TRIM(c.marketing_opt_in)) IN ('N', 'NO', '0', 'FALSE') THEN 0
       ELSE NULL END AS marketing_opt_in,
  c.marketing_opt_in AS marketing_opt_in_raw,
  -- DEF-014: near-dupe resolution (silver flags; gold dim_customer collapses)
  COALESCE(m.canonical_customer_id, c.customer_id) AS canonical_customer_id,
  m.dupe_resolution                                     -- NULL for all non-candidates (ids <= 11850)
FROM oakhaven.customers c
LEFT JOIN oakhaven_silver.customer_dupe_map m ON m.customer_id = c.customer_id;
