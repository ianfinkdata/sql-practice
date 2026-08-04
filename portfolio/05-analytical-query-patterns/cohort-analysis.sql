-- =============================================================================
-- PATTERN: Signup-month cohort analysis
-- =============================================================================
-- PROBLEM
--   You want to understand behavior grouped by WHEN a customer first
--   joined (their "cohort"), not just by who they are today -- e.g. do
--   customers who signed up in January spend differently, or churn
--   faster, than customers who signed up in June? Naive aggregation by
--   calendar month of the ORDER conflates two different things: how many
--   customers were active that month, versus how a specific cohort's
--   behavior evolves over its own lifetime.
--
-- WHEN TO REACH FOR IT
--   - Retention/engagement analysis: "of customers who signed up in
--     cohort month X, how many placed an order 1/2/3... months later?"
--   - Comparing cohorts to each other: did a marketing change in a given
--     signup month produce customers with different lifetime value than
--     prior cohorts?
--   - Any "time since acquisition" framing, as opposed to "time on the
--     calendar" framing.
--
-- HOW IT WORKS
--   1. Derive each entity's cohort key from its own acquisition event
--      (here: signup_date truncated to year-month).
--   2. Join to the activity table (here: fact_sales) on the entity key.
--   3. Optionally compute "months since signup" for each activity event
--      (event_month - cohort_month, as an integer count of months) so you
--      can align cohorts of different starting months on a common
--      "months since acquisition" x-axis -- this is what makes cohorts
--      from different calendar periods comparable to each other.
--   4. LEFT JOIN from the cohort side so cohort members with zero
--      activity still appear (same principle as the date-spine pattern in
--      03-date-dimension-patterns/ -- don't let "no activity" silently
--      disappear from the result).
--
-- REAL EXAMPLE (Oakhaven)
--   dim_customer.signup_date is the acquisition event; fact_sales gives
--   the activity. Truncating signup_date to 'YYYY-MM' with substr(...,1,7)
--   defines the cohort_month. The example below shows both the simple
--   cohort-size-and-revenue rollup, and the "months since signup"
--   alignment for one cohort (customers who signed up 2021-01).
--
-- SAMPLE OUTPUT (real data)
--   -- Cohort size and total net revenue, first several cohorts:
--   cohort_month  cohort_size  active_customers  cohort_net_amount
--   2018-01       3            3                 37046.99
--   2018-02       3            3                 43276.09
--   2018-03       6            6                 87439.14
--   2018-04       8            8                 117898.37
--
--   -- Months-since-signup alignment for the 2021-01 cohort (how many of
--   -- that cohort's customers were active N months after they signed up):
--   months_since_signup  active_customers
--   0                    1
--   1                    1
--   3                    1
--   4                    2
--
-- PORTABILITY
--   substr(date_col, 1, 7) for a 'YYYY-MM' truncation is SQLite-idiomatic
--   string slicing; native equivalents elsewhere are generally clearer of
--   intent:
--     - Postgres: `DATE_TRUNC('month', date_col)` returns a full date
--       (first of month) rather than a string -- often preferable since it
--       stays comparable/sortable as a date type.
--     - Snowflake: `DATE_TRUNC('MONTH', date_col)`, same idea.
--     - BigQuery: `DATE_TRUNC(date_col, MONTH)`.
--     - Databricks (Spark SQL): `DATE_TRUNC('MONTH', date_col)` or
--       `TRUNC(date_col, 'MM')`.
--   The "months since signup" integer calculation
--   (year-diff*12 + month-diff, as done manually here via strftime) has
--   direct built-ins elsewhere: Postgres/Snowflake
--   `DATEDIFF('month', cohort_date, event_date)` (Snowflake) or
--   `AGE(event_date, cohort_date)` (Postgres, returns an interval you'd
--   extract months from); BigQuery `DATE_DIFF(event_date, cohort_date,
--   MONTH)`; Databricks `MONTHS_BETWEEN(event_date, cohort_date)` (returns
--   a fractional value, so wrap in `FLOOR`/`CAST ... AS INT` for a whole
--   month count). All are simpler than SQLite's manual strftime
--   arithmetic, which lacks a native DATEDIFF/MONTHS_BETWEEN function.
-- =============================================================================

-- Cohort size and revenue rollup: how many customers signed up each
-- month, how many of them ever placed an order, and how much revenue
-- that cohort generated in total (all-time, not just their signup month).
WITH cohorts AS (
    SELECT customer_id, substr(signup_date, 1, 7) AS cohort_month
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),
orders AS (
    SELECT f.customer_id, substr(f.order_date, 1, 7) AS order_month, f.net_amount
    FROM fact_sales f
    WHERE f.order_date IS NOT NULL
)
SELECT
    c.cohort_month,
    COUNT(DISTINCT c.customer_id) AS cohort_size,
    COUNT(DISTINCT o.customer_id) AS active_customers,
    ROUND(SUM(o.net_amount), 2) AS cohort_net_amount
FROM cohorts c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month
LIMIT 8;

-- Months-since-signup alignment: for ONE cohort (customers who signed up
-- in 2021-01), how many were still active N months later. This is the
-- shape a retention-curve chart needs -- one row per (cohort, months-
-- since-signup) with a count, comparable across cohorts of different
-- starting months once you repeat this for every cohort_month.
WITH cohorts AS (
    SELECT customer_id, substr(signup_date, 1, 7) AS cohort_month
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),
orders AS (
    SELECT f.customer_id, substr(f.order_date, 1, 7) AS order_month
    FROM fact_sales f
    WHERE f.order_date IS NOT NULL
)
SELECT
    c.cohort_month,
    CAST(
        (strftime('%Y', o.order_month || '-01') - strftime('%Y', c.cohort_month || '-01')) * 12 +
        (strftime('%m', o.order_month || '-01') - strftime('%m', c.cohort_month || '-01'))
        AS INTEGER
    ) AS months_since_signup,
    COUNT(DISTINCT o.customer_id) AS active_customers
FROM cohorts c
JOIN orders o ON o.customer_id = c.customer_id
WHERE c.cohort_month = '2021-01'
GROUP BY months_since_signup
ORDER BY months_since_signup
LIMIT 8;
