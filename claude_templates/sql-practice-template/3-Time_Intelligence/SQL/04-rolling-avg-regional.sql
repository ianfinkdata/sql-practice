-- ============================================================
-- Exercise 3, Tier 3 (Final Boss) — Regional rolling 3-month average
--
-- Business Requirement: For every month + region combination,
-- show the current month's revenue and a rolling 3-month average
-- (current month + 2 prior months) that respects regional boundaries.
--
-- Technical Constraints:
--   1. Join to common_db.dim_date for month grouping (no inline month math)
--   2. Use ROWS BETWEEN 2 PRECEDING AND CURRENT ROW window frame
--   3. PARTITION BY region — Midwest numbers must not bleed into other regions
--   4. Every region must appear for every month even with zero sales
-- ============================================================

USE [your_schema];

CREATE OR REPLACE VIEW time_intel_sliding AS

WITH dim_calendar AS (
    -- Distinct months only — we don't need every day here
    SELECT DISTINCT month_start_date
    FROM common_db.dim_date
),

regions AS (
    SELECT DISTINCT region
    FROM customers
    WHERE region IS NOT NULL
),

-- Cross-join: guarantee every region has a row for every month
monthly_regions AS (
    SELECT
        d.month_start_date,
        r.region
    FROM dim_calendar AS d
    CROSS JOIN regions AS r
)

SELECT
    mr.month_start_date,
    mr.region,
    COALESCE(SUM(s.sale_amount), 0) AS current_period_sales,
    AVG(COALESCE(SUM(s.sale_amount), 0)) OVER (
        PARTITION BY mr.region
        ORDER BY mr.month_start_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3month_avg
FROM monthly_regions AS mr
LEFT JOIN customers AS c
    ON mr.region = c.region
LEFT JOIN sales AS s
    ON c.customer_id = s.customer_id
    AND s.sale_date >= mr.month_start_date
    AND s.sale_date <  DATE_ADD(mr.month_start_date, INTERVAL 1 MONTH)
WHERE mr.month_start_date BETWEEN DATE_ADD(CURRENT_DATE, INTERVAL -4 MONTH) AND CURRENT_DATE
GROUP BY
    mr.month_start_date,
    mr.region
ORDER BY
    mr.region,
    mr.month_start_date;

SELECT * FROM time_intel_sliding;

-- Validate against data/04-rolling-avg-regional.csv
