-- =============================================================================
-- PATTERN: Running totals and moving averages with window functions
-- =============================================================================
-- PROBLEM
--   You need a cumulative total up to each row (a running total) or a
--   smoothed trend line over a trailing window (a moving average) --
--   without a self-join or a correlated subquery per row, both of which
--   get slow fast and are easy to get subtly wrong (off-by-one window
--   bounds, double counting).
--
-- WHEN TO REACH FOR IT
--   - Cumulative metrics: running revenue, running order count,
--     year-to-date totals.
--   - Trend smoothing: N-day/N-period moving averages to see the signal
--     through day-to-day noise (e.g. weekday/weekend swings in daily
--     sales).
--   - Any "as of each row" calculation over an ordered series, where each
--     row's answer depends on a window of preceding rows rather than the
--     whole table or just itself.
--
-- HOW IT WORKS
--   A window function's frame clause controls exactly which rows are
--   aggregated for each output row:
--     - Running total: `SUM(x) OVER (ORDER BY date_col ROWS UNBOUNDED
--       PRECEDING)` -- every row from the start of the ordered set through
--       the current row.
--     - N-period moving average: `AVG(x) OVER (ORDER BY date_col ROWS
--       BETWEEN N-1 PRECEDING AND CURRENT ROW)` -- exactly N rows
--       (current + N-1 before it), sliding forward one row at a time.
--   Both need an explicit ORDER BY inside the OVER() clause -- without it,
--   the frame is undefined/whole-partition and the result is either
--   wrong or engine-dependent.
--
-- REAL EXAMPLE (Oakhaven)
--   Layered on top of agg_daily_sales (itself a date-spine LEFT JOIN
--   pattern -- see 03-date-dimension-patterns/), which already has one
--   row per calendar day including zero-order days. That gap-free daily
--   series is exactly the precondition a 7-day moving average needs to be
--   meaningful -- a moving average over a series with missing days would
--   silently average across an inconsistent number of real days.
--
-- SAMPLE OUTPUT (real data, first 8 days of the sales window)
--   order_date  total_net_amount  running_total  moving_avg_7d
--   2021-01-01  2318.71           2318.71        2318.71
--   2021-01-02  3381.01           5699.72        2849.86
--   2021-01-03  1914.65           7614.37        2538.12
--   2021-01-04  3594.94           11209.31       2802.33
--   2021-01-05  3059.74           14269.05       2853.81
--   2021-01-06  7591.42           21860.47       3643.41
--   2021-01-07  8585.33           30445.80       4349.40
--   2021-01-08  0.0               30445.80       4018.16   <- zero-order day, average still correct
--
-- PORTABILITY
--   Window functions with explicit frame clauses (ROWS BETWEEN ... AND
--   ...) are standard ANSI SQL -- identical syntax and semantics on
--   SQLite, Postgres, Snowflake, BigQuery, and Databricks. This is one of
--   the most portable patterns in the whole library. The only nuance:
--   ROWS vs. RANGE framing differ when there are ties in the ORDER BY key
--   (RANGE includes all peer rows with the same ORDER BY value in the
--   frame, ROWS counts physical rows regardless of ties) -- all five
--   engines implement this distinction identically per the SQL standard,
--   so prefer ROWS (as used here) when you want an exact N-row window
--   regardless of duplicate dates/values.
-- =============================================================================

-- Running total: cumulative net sales from the start of the series
-- through each day.
SELECT
    order_date,
    total_net_amount,
    SUM(total_net_amount) OVER (
        ORDER BY order_date ROWS UNBOUNDED PRECEDING
    ) AS running_total
FROM agg_daily_sales
ORDER BY order_date
LIMIT 10;

-- 7-day moving average: smooths day-to-day noise (including the
-- occasional zero-order day) into a trend line.
SELECT
    order_date,
    total_net_amount,
    ROUND(
        AVG(total_net_amount) OVER (
            ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_7d
FROM agg_daily_sales
ORDER BY order_date
LIMIT 10;

-- Both together, since they're often wanted side by side on the same chart:
SELECT
    order_date,
    total_net_amount,
    SUM(total_net_amount) OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING) AS running_total,
    ROUND(AVG(total_net_amount) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7d
FROM agg_daily_sales
ORDER BY order_date
LIMIT 10;
