-- =============================================================================
-- PATTERN: Generating a date spine with a recursive CTE
-- =============================================================================
-- PROBLEM
--   You need a row for every calendar day across some range (a date
--   dimension, a spine for zero-activity-day reporting, a scaffold for
--   time-series gap-filling) but you don't want to maintain that as
--   static loaded data, and there's no built-in "generate N rows" table
--   function on every engine you might target.
--
-- WHEN TO REACH FOR IT
--   - Building a date/calendar dimension from scratch, in pure SQL, with
--     no external ETL step or loop in application code.
--   - Any time you need "every day between X and Y" as an actual set of
--     rows to LEFT JOIN against (see date-spine-left-join-zero-activity-
--     days.sql in this same directory for why that matters).
--   - Generating any other kind of numeric/date sequence where the
--     engine's native sequence generator (if any) isn't available or
--     isn't portable to where this code needs to run next.
--
-- HOW IT WORKS
--   A recursive CTE has two parts unioned together: an anchor (the
--   starting row) and a recursive term that refers back to the CTE's own
--   name, generating the next row from the previous one, until a WHERE
--   condition in the recursive term stops the recursion. Here the anchor
--   is the start date; the recursive term adds one day and stops once it
--   would pass the end date.
--
-- REAL EXAMPLE (Oakhaven)
--   project/bronze/calendar_recursive_cte.sql builds bronze_calendar --
--   one row per day, 2018-01-01 through 2038-12-31 inclusive (~7,670
--   rows) -- entirely via this pattern, then derives datekey (YYYYMMDD
--   integer) from each generated date. No Python loop, no hardcoded date
--   list: the whole spine is produced by one INSERT ... WITH RECURSIVE
--   statement.
--
--   Verified against project/oakhaven.db (SELECT-only re-derivation,
--   compared against the actual populated table):
--     recursive CTE (recomputed):  7670 rows, 2018-01-01 .. 2038-12-31
--     bronze_calendar (populated): 7670 rows, 2018-01-01 .. 2038-12-31
--   -- identical, confirming the CTE is a faithful, re-runnable spec of
--   how the table was built.
--
-- SAMPLE OUTPUT (real data)
--   n     min_d       max_d
--   7670  2018-01-01  2038-12-31
--
-- PORTABILITY
--   `WITH RECURSIVE` is standard ANSI SQL and works with this exact
--   syntax on SQLite, Postgres, and Databricks (Spark SQL). Snowflake
--   supports WITH RECURSIVE too, syntax is compatible. BigQuery has no
--   WITH RECURSIVE at all -- for a date spine on BigQuery use the built-in
--   `GENERATE_DATE_ARRAY(start_date, end_date)` table function instead,
--   which returns an array you UNNEST:
--     SELECT day FROM UNNEST(GENERATE_DATE_ARRAY('2018-01-01', '2038-12-31')) AS day;
--   Postgres has an equivalent non-recursive option too:
--     SELECT generate_series('2018-01-01'::date, '2038-12-31'::date, '1 day')::date;
--   So in practice: use WITH RECURSIVE when you need one query that works
--   unmodified across SQLite/Postgres/Databricks/Snowflake; use each
--   engine's native series generator when you're committed to one engine
--   and want simpler, often faster SQL. There is also a recursion-depth
--   limit to be aware of on every recursive-CTE engine (SQLite has none
--   by default but very deep recursion can be slow; Postgres/Snowflake/
--   Databricks may need session-level recursion-limit settings raised for
--   very long spines -- 20 years of daily dates, as here, is comfortably
--   fine everywhere).
-- =============================================================================

-- The date-spine generation itself (SELECT-only re-derivation -- the real
-- table-populating INSERT lives in project/bronze/calendar_recursive_cte.sql,
-- run once at build time, not against the shared read-only oakhaven.db here).
WITH RECURSIVE dates(d) AS (
    SELECT date('2018-01-01')
    UNION ALL
    SELECT date(d, '+1 day')
    FROM dates
    WHERE d < date('2038-12-31')
)
SELECT
    CAST(strftime('%Y%m%d', d) AS INTEGER) AS datekey,
    d AS date
FROM dates
LIMIT 5;

-- Sanity-check the full spine's size and bounds match what's actually
-- populated in bronze_calendar (confirms the CTE is a correct, re-runnable
-- description of how that table was built).
WITH RECURSIVE dates(d) AS (
    SELECT date('2018-01-01')
    UNION ALL
    SELECT date(d, '+1 day') FROM dates WHERE d < date('2038-12-31')
)
SELECT COUNT(*) AS n, MIN(d) AS min_d, MAX(d) AS max_d FROM dates;
-- -> 7670 | 2018-01-01 | 2038-12-31

-- Illustrative only -- do NOT execute this CREATE/INSERT against the
-- shared oakhaven.db. This is exactly the statement used at build time:
--
-- DROP TABLE IF EXISTS bronze_calendar;
-- CREATE TABLE bronze_calendar (datekey INTEGER, date TEXT);
--
-- INSERT INTO bronze_calendar (datekey, date)
-- WITH RECURSIVE dates(d) AS (
--     SELECT date('2018-01-01')
--     UNION ALL
--     SELECT date(d, '+1 day') FROM dates WHERE d < date('2038-12-31')
-- )
-- SELECT CAST(strftime('%Y%m%d', d) AS INTEGER) AS datekey, d AS date
-- FROM dates;

-- GENERALIZING: to reuse this template for a different range or grain,
-- change only the anchor value and the recursive term's step/bound:
--   - Different range: swap '2018-01-01' / '2038-12-31'.
--   - Monthly spine instead of daily: swap '+1 day' for '+1 month' and
--     seed the anchor with date('2018-01-01','start of month').
--   - Hourly spine: swap '+1 day' for '+1 hour' -- watch row-count growth
--     (24x) and consider whether a recursive CTE is still the fastest
--     option at that grain versus a native generator function.
