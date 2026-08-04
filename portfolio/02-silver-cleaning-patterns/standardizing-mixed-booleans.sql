-- =============================================================================
-- PATTERN: Standardizing mixed-representation booleans
-- =============================================================================
-- PROBLEM
--   A "yes/no" column arrives as free-text from a source system (manual
--   entry, CSV import, loosely-typed API) with many literal spellings for
--   the same two logical values, plus NULLs that are genuinely unknown
--   (not a third value). You need a real 0/1 (or TRUE/FALSE) column you
--   can filter, aggregate, and join on with confidence.
--
-- WHEN TO REACH FOR IT
--   - Any TEXT column that's conceptually boolean but stores it as strings:
--     is_active, is_manager, is_discontinued, opted_in, subscribed, etc.
--   - Whenever the raw pool mixes case (Y/y), full words (yes/no,
--     true/false), and numeric-as-text (1/0) -- i.e. more than one
--     "dialect" of boolean in the same column, which is extremely common
--     when a column was hand-entered or merged from multiple sources.
--
-- HOW IT WORKS
--   LOWER(TRIM(x)) first to collapse casing/whitespace noise into one
--   comparison space, then a CASE/WHEN with IN-lists for the truthy and
--   falsy pools. Anything that doesn't match either pool (including NULL
--   and empty string) falls through to NULL -- do NOT default unmatched
--   values to 0 or 1; an unrecognized/missing value is a genuine unknown,
--   not evidence of falsehood.
--
-- REAL EXAMPLE (Oakhaven)
--   bronze_customers.is_active, bronze_employees.is_manager, and
--   bronze_products.is_discontinued all draw from the exact same
--   mixed-boolean text pool at generation time:
--     NULL, '0', '1', 'N', 'Y', 'false', 'n', 'no', 'true', 'y', 'yes'
--   (plus '' empty string in practice). All three silver views
--   (silver_customers.sql, silver_employees.sql, silver_products.sql) use
--   the identical CASE pattern shown below -- this is the textbook case of
--   "write the pattern once, reuse it verbatim across every boolean-ish
--   column in the warehouse."
--
-- SAMPLE OUTPUT (real data, bronze_customers.is_active)
--   raw    standardized
--   -----  ------------
--   (null)               <- NULL stays NULL
--   0      0
--   1      1
--   N      0
--   Y      1
--   false  0
--   n      0
--   no     0
--   true   1
--   y      1
--   yes    1
--
-- PORTABILITY
--   CASE/WHEN, LOWER, TRIM, and IN-lists are standard ANSI SQL --
--   identical on SQLite, Postgres, Snowflake, BigQuery, and Databricks.
--   Postgres/Snowflake/Databricks additionally have a native BOOLEAN type
--   you may prefer to cast into (e.g. `... THEN TRUE ... THEN FALSE ...`
--   with an output column typed BOOLEAN) instead of 0/1 INTEGER; SQLite
--   has no native boolean type (0/1 INTEGER is the idiomatic SQLite
--   convention, and is what this repo uses throughout for portability).
--   BigQuery also supports a native BOOL type with TRUE/FALSE literals.
-- =============================================================================

-- Distinct raw values actually present in this column (know your pool
-- before you write the CASE statement -- don't guess).
SELECT DISTINCT is_active FROM bronze_customers ORDER BY is_active;

-- The standardization pattern itself, shown against every raw value once
-- (GROUP BY collapses to one row per distinct raw value, so this doubles
-- as documentation of the mapping).
SELECT
    is_active AS raw,
    CASE
        WHEN LOWER(TRIM(is_active)) IN ('y', 'yes', 'true', '1') THEN 1
        WHEN LOWER(TRIM(is_active)) IN ('n', 'no', 'false', '0') THEN 0
        ELSE NULL
    END AS standardized
FROM bronze_customers
GROUP BY is_active
ORDER BY is_active;

-- The same pattern generalizes directly to is_manager (bronze_employees)
-- and is_discontinued (bronze_products) -- swap the column name only:
--
--   CASE
--       WHEN LOWER(TRIM(is_manager)) IN ('y', 'yes', 'true', '1') THEN 1
--       WHEN LOWER(TRIM(is_manager)) IN ('n', 'no', 'false', '0') THEN 0
--       ELSE NULL
--   END AS is_manager
--
-- See project/silver/silver_customers.sql, silver_employees.sql, and
-- silver_products.sql for the identical pattern applied three times.
