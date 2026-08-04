-- =============================================================================
-- PATTERN: Date-spine LEFT JOIN to surface zero-activity days
-- =============================================================================
-- PROBLEM
--   A naive `GROUP BY order_date` over a transactions/events table only
--   produces rows for days that had at least one transaction. Days with
--   zero activity simply don't appear -- which silently breaks any
--   report, chart, or moving-average calculation that assumes a
--   contiguous daily series (a day missing from the output looks
--   identical to "no data was loaded for this range" rather than "zero
--   orders that day," and gaps break window functions like 7-day moving
--   averages that expect one row per day).
--
-- WHEN TO REACH FOR IT
--   - Any daily/weekly/monthly rollup where the business needs to see (or
--     chart) periods with zero activity, not have them silently vanish.
--   - Building the base result set for a moving average / rolling window
--     calculation, which requires a gap-free date series to be correct.
--   - Any "days since last order" / activity-streak calculation, which
--     needs every calendar day represented to compute gaps correctly.
--
-- HOW IT WORKS
--   Drive the query FROM the date dimension (or a generated date spine),
--   not from the fact table. LEFT JOIN the fact table onto the date
--   dimension (dimension on the left, facts on the right) so every date
--   dimension row survives regardless of whether it has matching fact
--   rows. Then wrap every fact-derived aggregate in COALESCE(..., 0) --
--   COUNT(fact_col) already returns 0 correctly for a day with no
--   matching rows, but SUM(fact_col) returns NULL for that day unless you
--   COALESCE it, since SUM of zero rows is NULL, not 0.
--
-- REAL EXAMPLE (Oakhaven)
--   project/gold/agg_daily_sales.sql builds a daily sales rollup that
--   starts FROM dim_date (not fact_sales), LEFT JOIN fact_sales ON
--   datekey, and filters to the operational window ('2021-01-01' to
--   '2026-06-30'). This surfaces exactly 54 real calendar days in that
--   window with zero order lines -- if the query had started from
--   fact_sales with an INNER JOIN instead, those 54 days would silently
--   not exist in the output at all, with no way to distinguish "zero
--   sales" from "day not in range."
--
--   Verified against project/oakhaven.db:
--     SELECT COUNT(*) FROM agg_daily_sales WHERE order_line_count = 0;
--   --> 54 (matches facts_sheet.md exactly)
--
-- SAMPLE OUTPUT (real data)
--   order_date  order_line_count  total_net_amount
--   2021-01-08  0                 0.0
--   2021-03-02  0                 0.0
--   2021-03-13  0                 0.0
--   2021-03-26  0                 0.0
--   2021-04-30  0                 0.0
--
-- PORTABILITY
--   LEFT JOIN + GROUP BY + COALESCE(SUM(...), 0) is standard ANSI SQL --
--   identical on SQLite, Postgres, Snowflake, BigQuery, and Databricks.
--   No dialect differences in the join/aggregation itself. Where engines
--   differ is only in how you'd generate the date-dimension side if you
--   didn't already have one materialized -- see
--   recursive-cte-calendar-generation.sql in this same directory for the
--   portability notes on that half of the pattern (WITH RECURSIVE vs.
--   GENERATE_DATE_ARRAY vs. generate_series).
-- =============================================================================

-- The date-spine LEFT JOIN pattern itself, matching agg_daily_sales.sql:
-- drive FROM the date dimension, LEFT JOIN the fact table onto it.
SELECT
    d.date AS order_date,
    d.year,
    d.month,
    d.day_name,
    d.is_weekend,
    COUNT(f.order_line_id) AS order_line_count,             -- COUNT already returns 0 with no matches
    ROUND(COALESCE(SUM(f.net_amount), 0), 2) AS total_net_amount  -- SUM needs an explicit COALESCE
FROM dim_date d
LEFT JOIN fact_sales f ON f.datekey = d.datekey
WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
GROUP BY d.date, d.year, d.month, d.day_name, d.is_weekend
ORDER BY d.date
LIMIT 10;

-- Prove the pattern actually surfaces zero-activity days rather than
-- dropping them -- these are real calendar days inside the operational
-- window with no order lines at all.
SELECT
    d.date AS order_date,
    COUNT(f.order_line_id) AS order_line_count,
    ROUND(COALESCE(SUM(f.net_amount), 0), 2) AS total_net_amount
FROM dim_date d
LEFT JOIN fact_sales f ON f.datekey = d.datekey
WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
GROUP BY d.date
HAVING COUNT(f.order_line_id) = 0
LIMIT 5;

-- Contrast: what you'd get (wrongly) starting FROM the fact table with an
-- inner join -- zero-activity days simply never appear as rows, and there
-- is no way downstream to tell "no data" apart from "day out of range."
-- (Illustrative only, not run here -- compare row counts yourself if
-- curious: SELECT COUNT(DISTINCT order_date) FROM fact_sales gives fewer
-- distinct days than SELECT COUNT(*) FROM agg_daily_sales.)
--
-- SELECT f.order_date, COUNT(*) AS order_line_count, SUM(f.net_amount) AS total_net_amount
-- FROM fact_sales f
-- WHERE f.order_date BETWEEN '2021-01-01' AND '2026-06-30'
-- GROUP BY f.order_date;
-- -> only produces rows for days that had at least one order line
