-- =============================================================================
-- PATTERN: Deriving calendar attributes (and fiscal-year offsets) for a date dimension
-- =============================================================================
-- PROBLEM
--   A date dimension's raw column is just a date/datekey -- you need
--   business-friendly derived attributes (year, month name, quarter,
--   day-of-week name, weekend flag) computed consistently once, in the
--   dimension itself, rather than recomputed ad hoc (and inconsistently)
--   in every downstream query.
--
-- WHEN TO REACH FOR IT
--   - Building or extending any date dimension (dim_date) that BI tools,
--     dashboards, or analysts will filter/group by calendar attributes.
--   - Any time you catch yourself writing `strftime('%Y', ...)` or
--     equivalent inline in a reporting query instead of joining to a
--     dimension that already has the year column.
--   - Adding a fiscal calendar on top of a standard (Jan-Dec) calendar
--     dimension, for businesses whose fiscal year doesn't align to the
--     calendar year.
--
-- HOW IT WORKS
--   Every attribute is a pure function of the date column:
--     - year/month/day: strftime('%Y'/'%m'/'%d', date), CAST to INTEGER.
--     - month_name/day_name: CASE on the integer month/day-of-week.
--     - quarter: ((month - 1) / 3) + 1 -- integer division buckets
--       months 1-3 -> 1, 4-6 -> 2, 7-9 -> 3, 10-12 -> 4.
--     - day_of_week: strftime('%w', date) -- 0=Sunday..6=Saturday in
--       SQLite specifically (see portability note -- this numbering is
--       NOT the same across all four other engines).
--     - is_weekend: day_of_week IN (0, 6) -> 1 else 0.
--
-- REAL EXAMPLE (Oakhaven)
--   project/gold/dim_date.sql derives exactly this set of attributes from
--   silver_calendar (the passthrough over the recursive-CTE-generated
--   bronze_calendar spine): year, month, month_name, quarter,
--   day_of_month, day_of_week, day_name, is_weekend. This dimension does
--   NOT currently include a fiscal-year offset -- Oakhaven's calendar is
--   assumed to run Jan-Dec -- but the derivation is a one-column addition
--   to the same view, shown below as an extension.
--
-- SAMPLE OUTPUT (real data, 2026-06-30 -- note this repo's SNAPSHOT_DATE)
--   datekey   date        year  month  month_name  quarter  day_of_week  day_name  is_weekend
--   20260630  2026-06-30  2026  6      June        2        2            Tuesday   0
--
-- PORTABILITY
--   strftime() is SQLite-specific syntax; every other engine has its own
--   date-part extraction function, though the underlying concept
--   (extract year/month/day-of-week from a date) is universal:
--     - Postgres: EXTRACT(YEAR FROM date_col), EXTRACT(DOW FROM date_col)
--       (0=Sunday..6=Saturday, matching SQLite's %w numbering) or
--       `TO_CHAR(date_col, 'Day')` for a weekday name.
--     - Snowflake: YEAR(date_col), MONTH(date_col), DAYOFWEEK(date_col)
--       (0=Sunday..6=Saturday by default, matching), DAYNAME(date_col)
--       for the name directly (no CASE needed).
--     - BigQuery: EXTRACT(YEAR FROM date_col), EXTRACT(DAYOFWEEK FROM
--       date_col) -- **1=Sunday..7=Saturday**, i.e. off-by-one from
--       SQLite/Postgres/Snowflake's 0-indexed numbering. FORMAT_DATE('%A',
--       date_col) gives the weekday name directly.
--     - Databricks (Spark SQL): YEAR(date_col), DAYOFWEEK(date_col)
--       (1=Sunday..7=Saturday, same BigQuery-style off-by-one), or
--       date_format(date_col, 'EEEE') for the weekday name.
--   Takeaway: day-of-week numbering is the single most common silent bug
--   when porting a date dimension across engines -- always verify the
--   numbering convention (0-indexed-from-Sunday vs. 1-indexed-from-Sunday
--   vs. ISO 1-indexed-from-Monday) against a known date before trusting
--   an is_weekend or "start of week" calculation on a new engine. Every
--   engine listed also has a direct month-name/day-name function
--   (DAYNAME, FORMAT_DATE('%A', ...), date_format(..., 'EEEE'),
--   TO_CHAR(..., 'Day')) that's simpler than SQLite's manual CASE, since
--   SQLite has no locale-aware date-formatting function built in.
--
-- FISCAL YEAR OFFSET (not currently in this schema -- extension pattern)
--   For a business whose fiscal year starts in a month other than
--   January (e.g. FY starts October 1st, common in US government/some
--   retail), add a fiscal_year and fiscal_quarter column: shift the
--   calendar month by the fiscal start offset before computing the year/
--   quarter bucket. For an October-start fiscal year, October of
--   calendar year Y becomes fiscal month 1 of FY(Y+1):
--
--     CASE WHEN month >= 10 THEN year + 1 ELSE year END AS fiscal_year,
--     ((((month - 10 + 12) % 12)) / 3) + 1 AS fiscal_quarter
--
--   Generalize by parameterizing the offset (10 above) as a single
--   constant everywhere it appears -- keep it in one place (a config
--   table, or a documented constant at the top of the view) so a fiscal
--   calendar change is a one-line edit, not a hunt-and-replace.
-- =============================================================================

-- The core derivation pattern, matching project/gold/dim_date.sql exactly:
SELECT
    datekey,
    date,
    CAST(strftime('%Y', date) AS INTEGER) AS year,
    CAST(strftime('%m', date) AS INTEGER) AS month,
    CASE CAST(strftime('%m', date) AS INTEGER)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    ((CAST(strftime('%m', date) AS INTEGER) - 1) / 3) + 1 AS quarter,
    CAST(strftime('%d', date) AS INTEGER) AS day_of_month,
    CAST(strftime('%w', date) AS INTEGER) AS day_of_week,  -- 0=Sunday..6=Saturday (SQLite convention)
    CASE CAST(strftime('%w', date) AS INTEGER)
        WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    CASE WHEN CAST(strftime('%w', date) AS INTEGER) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend
FROM dim_date
WHERE date = '2026-06-30';

-- Extension: adding a fiscal_year/fiscal_quarter column for a hypothetical
-- October-start fiscal year, layered on top of the same dimension:
SELECT
    date,
    year AS calendar_year,
    month AS calendar_month,
    CASE WHEN month >= 10 THEN year + 1 ELSE year END AS fiscal_year,
    ((((month - 10 + 12) % 12)) / 3) + 1 AS fiscal_quarter
FROM dim_date
WHERE date IN ('2026-09-30', '2026-10-01', '2026-12-31', '2027-01-01')
ORDER BY date;
