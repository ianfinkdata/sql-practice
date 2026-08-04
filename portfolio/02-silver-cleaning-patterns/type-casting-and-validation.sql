-- =============================================================================
-- PATTERN: Parsing mixed date formats and dirty numeric-as-text columns
-- =============================================================================
-- PROBLEM
--   Two very common "typed as TEXT but not really text" problems:
--     1. A date column holds a mix of formats -- different upstream
--        systems, different export tools, or a schema-less source that
--        never enforced one -- and you need every value normalized to a
--        single ISO 8601 (YYYY-MM-DD) representation before it's usable
--        in date math, joins to a date dimension, or BETWEEN filters.
--     2. A numeric measurement column is stored as TEXT because some rows
--        carry a unit suffix (e.g. "1.2 kg") while others are bare numbers
--        ("1.2") -- CAST alone fails or silently truncates on the ones
--        with a suffix.
--
-- WHEN TO REACH FOR IT
--   - Any date/timestamp column typed TEXT (or VARCHAR) in the source,
--     especially from CSV imports, spreadsheets, or systems that changed
--     their date format at some point without backfilling history.
--   - Any "numeric" column typed TEXT where you spot unit suffixes, stray
--     whitespace, or inconsistent decimal formatting mixed with clean
--     values in the same column.
--
-- HOW IT WORKS (dates)
--   LIKE-pattern matching on the string shape (`__/__/____`,
--   `____-__-__ __:__:__`, `____-__-__`) to detect which of a small,
--   known set of formats a given row is in, then reassemble the
--   substrings into ISO order (YYYY-MM-DD) with `substr()` and string
--   concatenation. Requires knowing the finite set of formats in advance
--   (interrogate the raw data with DISTINCT / LIKE counts first) --
--   this pattern does NOT generically parse arbitrary date strings.
--
-- HOW IT WORKS (dirty numeric text)
--   CASE on a LIKE pattern that detects the unit suffix, strip it with
--   REPLACE/TRIM, then CAST to REAL. Bare numeric strings fall through to
--   a direct CAST.
--
-- REAL EXAMPLE (Oakhaven)
--   bronze_customers.signup_date, bronze_employees.hire_date /
--   termination_date, bronze_products.created_at, and
--   bronze_sales.order_date / ship_date all share the exact same 3-format
--   pool: `MM/DD/YYYY`, `YYYY-MM-DD HH:MM:SS`, and clean `YYYY-MM-DD`. The
--   same CASE pattern (below) appears verbatim, once per date column,
--   across every project/silver/*.sql file.
--
--   bronze_products.weight_kg is dirty TEXT: e.g. "1.2", "1.2 kg", or
--   NULL (~8%) -- silver_products.sql strips the " kg" suffix when
--   present before casting to REAL.
--
-- SAMPLE OUTPUT (real data)
--   -- Date parsing:
--   raw                  iso_date
--   2022-06-26 19:12:42  2022-06-26
--   12/01/2018           2018-12-01
--   01/14/2022           2022-01-14
--
--   -- weight_kg parsing:
--   raw      parsed
--   24.7 kg  24.7
--   5.3      5.3
--   3.43 kg  3.43
--   9.01     9.01
--
-- PORTABILITY
--   LIKE, substr()/SUBSTRING, REPLACE, TRIM, CAST are standard SQL, but
--   date parsing is the single most dialect-divergent area in SQL:
--     - SQLite: no native DATE type; dates are TEXT/INTEGER/REAL by
--       convention, parsed via strftime()/date() as shown. The
--       LIKE+substr reassembly approach here is portable but verbose.
--     - Postgres: `TO_DATE(col, 'MM/DD/YYYY')` / `TO_TIMESTAMP(...)`
--       handle format strings natively -- no manual substr needed once you
--       branch on which format a row is in.
--     - Snowflake: `TRY_TO_DATE(col, 'MM/DD/YYYY')` -- the TRY_ prefix
--       returns NULL instead of erroring on a bad match, which pairs well
--       with trying multiple formats via COALESCE(TRY_TO_DATE(col, fmt1),
--       TRY_TO_DATE(col, fmt2), ...).
--     - BigQuery: `PARSE_DATE('%m/%d/%Y', col)` / `SAFE.PARSE_DATE(...)`
--       for the non-erroring variant.
--     - Databricks (Spark SQL): `TO_DATE(col, 'MM/dd/yyyy')`, and
--       `TRY_TO_TIMESTAMP` for the non-erroring variant.
--   In all four non-SQLite engines, prefer the native TO_DATE/PARSE_DATE
--   family with an explicit format string over manual substr reassembly
--   -- it's shorter, clearer, and handles more format edge cases.
--   For numeric-with-suffix parsing, `TRY_CAST`/`SAFE_CAST` (Snowflake/
--   Databricks and BigQuery respectively) let you attempt the cast after
--   stripping the suffix without erroring the whole query on a row that
--   still doesn't parse; SQLite's CAST never errors (see the
--   recompute-dont-trust-the-total.sql file in this same directory for
--   why that's a footgun, not a feature).
-- =============================================================================

-- Confirm the three raw date-format shapes actually present (always look
-- before you branch -- don't assume the format pool from documentation
-- alone).
SELECT signup_date FROM bronze_customers WHERE signup_date LIKE '__/__/____' LIMIT 2;
SELECT signup_date FROM bronze_customers WHERE signup_date LIKE '____-__-__ __:__:__' LIMIT 2;
SELECT signup_date FROM bronze_customers WHERE signup_date LIKE '____-__-__' LIMIT 2;

-- The date-parsing pattern: detect the shape, reassemble to ISO.
SELECT
    signup_date AS raw,
    CASE
        WHEN signup_date IS NULL THEN NULL
        WHEN signup_date LIKE '__/__/____'
            THEN substr(signup_date, 7, 4) || '-' || substr(signup_date, 1, 2) || '-' || substr(signup_date, 4, 2)
        WHEN signup_date LIKE '____-__-__ __:__:__' THEN substr(signup_date, 1, 10)
        WHEN signup_date LIKE '____-__-__' THEN signup_date
        ELSE NULL
    END AS iso_date
FROM bronze_customers
WHERE signup_date LIKE '__/__/____' OR signup_date LIKE '____-__-__ __:__:__'
LIMIT 5;

-- This exact CASE shape recurs, unchanged, for every date-ish column in
-- the schema: hire_date, termination_date, created_at, order_date,
-- ship_date -- only the column name changes. Copy/paste-and-rename is the
-- right move here, not premature abstraction into a function (SQLite
-- views can't take parameters; a scalar UDF is possible via the Python
-- sqlite3 API but isn't portable SQL, so plain repeated CASE blocks are
-- the pragmatic, portable choice).

-- The dirty-numeric-as-text pattern: weight_kg is TEXT because some rows
-- carry a " kg" suffix.
SELECT DISTINCT weight_kg FROM bronze_products LIMIT 10;

SELECT
    weight_kg AS raw,
    CASE
        WHEN weight_kg IS NULL THEN NULL
        WHEN weight_kg LIKE '% kg' THEN CAST(TRIM(REPLACE(weight_kg, ' kg', '')) AS REAL)
        ELSE CAST(weight_kg AS REAL)
    END AS parsed
FROM bronze_products
LIMIT 8;
