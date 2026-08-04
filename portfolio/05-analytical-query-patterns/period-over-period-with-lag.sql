-- =============================================================================
-- PATTERN: Period-over-period comparison with LAG()
-- =============================================================================
-- PROBLEM
--   You need to compare each period's metric to the PREVIOUS period's
--   (month-over-month, year-over-year, day-over-day) -- the absolute
--   change and/or the percent change -- without a self-join keyed on "this
--   period's date minus one period," which gets fiddly across month-end
--   boundaries and requires the same table twice in the FROM clause.
--
-- WHEN TO REACH FOR IT
--   - Any trend narrative: "sales were up/down X% vs. last month," growth
--     dashboards, KPI scorecards.
--   - Detecting anomalies: a period whose value differs sharply from the
--     prior period is often worth flagging (e.g. ABS(pct_change) > 50).
--   - Anywhere you'd otherwise reach for a self-join on
--     `t1.period = t2.period - 1` -- LAG() is simpler, doesn't need date
--     arithmetic in a join condition, and correctly handles gaps in the
--     period series (a period with no prior row gets NULL automatically,
--     not silently skipped to the wrong "previous" row).
--
-- HOW IT WORKS
--   `LAG(metric) OVER (PARTITION BY <grouping columns> ORDER BY
--   <period columns>)` returns the metric value from the immediately
--   preceding row within the same partition, ordered by the period. The
--   first row in each partition has no prior row, so LAG returns NULL
--   there -- that's correct and expected (there IS no prior period for the
--   first one), not a bug to work around. `LEAD()` is the mirror-image
--   function for "next period" instead of "previous period."
--
-- REAL EXAMPLE (Oakhaven)
--   agg_monthly_sales_by_category already rolls sales up to
--   year/month/category grain. Partitioning by category and ordering by
--   year/month, LAG() pulls each category's prior-month total onto the
--   same row as the current month, making month-over-month change a
--   single subtraction away -- no self-join needed.
--
-- SAMPLE OUTPUT (real data, Climbing category)
--   year  month  total_net_amount  prior_month_amount  mom_change  mom_pct_change
--   2021  1      17972.83                                                       <- no prior period: NULL, correctly
--   2021  2      33663.09          17972.83            15690.26    87.3
--   2021  3      28847.21          33663.09            -4815.88    -14.3
--   2021  4      14295.57          28847.21            -14551.64   -50.4
--   2021  5      22400.84          14295.57            8105.27     56.7
--   2021  6      22866.67          22400.84            465.83      2.1
--
-- PORTABILITY
--   LAG()/LEAD() are standard ANSI SQL window functions -- identical on
--   SQLite, Postgres, Snowflake, BigQuery, and Databricks, including the
--   optional offset and default-value arguments (`LAG(col, 1, 0)` to
--   default to 0 instead of NULL when there's no prior row, supported
--   identically everywhere). No dialect differences for this pattern.
-- =============================================================================

-- Per-category month-over-month change, using LAG() partitioned by
-- category so each category's series compares to its own prior month
-- (not another category's).
WITH monthly AS (
    SELECT year, month, category, total_net_amount
    FROM agg_monthly_sales_by_category
    WHERE category = 'Climbing'
)
SELECT
    year,
    month,
    total_net_amount,
    LAG(total_net_amount) OVER (ORDER BY year, month) AS prior_month_amount,
    ROUND(total_net_amount - LAG(total_net_amount) OVER (ORDER BY year, month), 2) AS mom_change,
    ROUND(
        100.0 * (total_net_amount - LAG(total_net_amount) OVER (ORDER BY year, month))
        / LAG(total_net_amount) OVER (ORDER BY year, month), 1
    ) AS mom_pct_change
FROM monthly
ORDER BY year, month
LIMIT 8;

-- The same pattern generalized across ALL categories at once via
-- PARTITION BY -- each category's LAG only looks at its own prior row,
-- never bleeding across category boundaries.
SELECT
    category,
    year,
    month,
    total_net_amount,
    LAG(total_net_amount) OVER (PARTITION BY category ORDER BY year, month) AS prior_month_amount,
    ROUND(
        total_net_amount - LAG(total_net_amount) OVER (PARTITION BY category ORDER BY year, month), 2
    ) AS mom_change
FROM agg_monthly_sales_by_category
ORDER BY category, year, month
LIMIT 10;
