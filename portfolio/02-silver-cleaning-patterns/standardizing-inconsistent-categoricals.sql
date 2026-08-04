-- =============================================================================
-- PATTERN: Standardizing inconsistent categorical values
-- =============================================================================
-- PROBLEM
--   A categorical/enum-like TEXT column has a small, known set of true
--   values, but the raw data contains many surface variants of each --
--   different casing, stray trailing spaces, "&" spelled out as "and",
--   split-vs-joined compound words. GROUP BY / DISTINCT on the raw column
--   silently over-counts categories that are logically identical.
--
-- WHEN TO REACH FOR IT
--   - Any TEXT column with a small fixed vocabulary populated by manual
--     entry, multiple upstream systems, or free-text form fields:
--     category, state/region, department, status, payment method.
--   - Whenever `SELECT COUNT(DISTINCT col)` returns a suspiciously large
--     number relative to how many categories the business actually has --
--     that gap is exactly the messiness this pattern collapses.
--
-- HOW IT WORKS
--   1. Normalize into one comparison space: LOWER + TRIM, and collapse
--      known noise (REPLACE to fold "  " -> " ", "and" -> "&", etc.) so
--      that variants converge onto the same key.
--   2. CASE/WHEN mapping the normalized key to the canonical display
--      value. Anything unrecognized falls through to NULL rather than
--      being silently mapped to a wrong bucket or left in its dirty raw
--      form -- an unmapped value is a data-quality signal worth surfacing,
--      not hiding.
--   3. For a lookup table with many entries (e.g. full US state names),
--      prefer a VALUES-based mapping table joined via COALESCE over two
--      lookup attempts (see the state normalization pattern in
--      project/silver/silver_customers.sql) instead of a giant CASE.
--
-- REAL EXAMPLE (Oakhaven)
--   bronze_products.category has 40 distinct raw strings in this build,
--   all mapping down to just 8 canonical categories: Footwear, Apparel,
--   Camping & Hiking, Climbing, Water Sports, Winter Sports, Accessories,
--   Nutrition & Hydration. The variants include upper/lower/title casing,
--   a trailing space, "and" spelled out instead of "&", and a split
--   compound word ("Foot Wear" vs "Footwear"). silver_products.sql
--   collapses this with LOWER(TRIM(REPLACE(category, '  ', ' '))) as the
--   normalization key, then a CASE mapping to canonical names.
--
--   Verified against project/oakhaven.db:
--     SELECT COUNT(DISTINCT category) FROM bronze_products;             --> 40
--     SELECT COUNT(DISTINCT <normalized+CASE'd category>) FROM ...;      --> 8
--
-- SAMPLE OUTPUT (real data, subset of the 40 raw variants)
--   category
--   ------------------------
--   ACCESSORIES
--   Accessories
--   accessories
--   CAMPING & HIKING
--   CAMPING AND HIKING
--   Camping and Hiking
--   FOOT WEAR
--   Foot Wear
--   FOOTWEAR
--   Footwear
--   ... (40 total, all collapsing to 8 canonical values)
--
-- PORTABILITY
--   LOWER, TRIM, REPLACE, CASE/WHEN are standard ANSI SQL -- identical on
--   SQLite, Postgres, Snowflake, BigQuery, and Databricks. For the
--   lookup-table variant (many-to-one mapping via a VALUES table + JOIN or
--   COALESCE subqueries, as silver_customers.sql does for the 50-state
--   name-to-abbreviation map), all five engines support `VALUES (...) AS
--   t(col1, col2)` / a literal inline table -- syntax is effectively
--   identical, though Snowflake/BigQuery prefer this pattern be wrapped in
--   a CTE (`WITH t AS (SELECT * FROM (VALUES ...) AS t(a,b))`) for
--   maximum clarity, which also works everywhere else.
-- =============================================================================

-- The raw mess: how many distinct literal strings actually exist for
-- "category" in this build?
SELECT DISTINCT category FROM bronze_products ORDER BY category;
-- -> 40 distinct raw strings

SELECT COUNT(DISTINCT category) AS raw_variants FROM bronze_products;
-- -> 40

-- The standardization pattern: normalize whitespace/casing to a key, then
-- CASE to canonical names. Both "&" and "and" spellings, both split and
-- joined "Foot Wear"/"Footwear", all fold to the same canonical value.
SELECT
    COUNT(DISTINCT CASE LOWER(TRIM(REPLACE(category, '  ', ' ')))
        WHEN 'footwear'                  THEN 'Footwear'
        WHEN 'foot wear'                 THEN 'Footwear'
        WHEN 'apparel'                   THEN 'Apparel'
        WHEN 'camping & hiking'          THEN 'Camping & Hiking'
        WHEN 'camping and hiking'        THEN 'Camping & Hiking'
        WHEN 'climbing'                  THEN 'Climbing'
        WHEN 'water sports'              THEN 'Water Sports'
        WHEN 'winter sports'             THEN 'Winter Sports'
        WHEN 'accessories'               THEN 'Accessories'
        WHEN 'nutrition & hydration'     THEN 'Nutrition & Hydration'
        WHEN 'nutrition and hydration'   THEN 'Nutrition & Hydration'
        ELSE NULL
    END) AS canonical_categories
FROM bronze_products;
-- -> 8

-- Full worked view of the mapping, matching project/silver/silver_products.sql:
SELECT
    product_id,
    category AS category_raw,
    CASE LOWER(TRIM(REPLACE(category, '  ', ' ')))
        WHEN 'footwear'                  THEN 'Footwear'
        WHEN 'foot wear'                 THEN 'Footwear'
        WHEN 'apparel'                   THEN 'Apparel'
        WHEN 'camping & hiking'          THEN 'Camping & Hiking'
        WHEN 'camping and hiking'        THEN 'Camping & Hiking'
        WHEN 'climbing'                  THEN 'Climbing'
        WHEN 'water sports'              THEN 'Water Sports'
        WHEN 'winter sports'             THEN 'Winter Sports'
        WHEN 'accessories'               THEN 'Accessories'
        WHEN 'nutrition & hydration'     THEN 'Nutrition & Hydration'
        WHEN 'nutrition and hydration'   THEN 'Nutrition & Hydration'
        ELSE NULL
    END AS category
FROM bronze_products
LIMIT 10;

-- For a larger vocabulary (e.g. 50 US states x 4 casing variants + dotted
-- abbreviations, as in bronze_customers.state), a VALUES-based lookup
-- table beats a 200-branch CASE. See silver_customers.sql:
--
-- WITH state_map(name_key, abbr) AS (
--     VALUES ('california', 'CA'), ('calif.', 'CA'), ('new york', 'NY'), ...
-- )
-- SELECT COALESCE(
--     (SELECT abbr FROM state_map WHERE name_key = LOWER(state_raw)),
--     (SELECT abbr FROM state_map WHERE abbr = UPPER(state_raw))
-- ) AS state
-- FROM bronze_customers;
