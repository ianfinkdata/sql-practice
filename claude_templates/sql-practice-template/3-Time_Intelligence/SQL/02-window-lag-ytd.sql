-- ============================================================
-- Exercise 3, Tier 2 — Window functions: LAG + YTD
--
-- Business Requirement: For every month, show current month revenue,
-- prior month revenue (via LAG), and a Year-to-Date total that
-- resets each January 1st.
--
-- Technical Constraint: Use window functions only. No self-joins.
-- ============================================================

USE [your_schema];

CREATE OR REPLACE VIEW time_intel_windows AS

WITH current_month AS (
    SELECT
        sale_date - INTERVAL (DAY(sale_date) - 1) DAY AS sale_month,
        SUM(sale_amount) AS current_month_sales
    FROM sales
    GROUP BY sale_month
)

SELECT
    *,
    -- LAG(col, offset, default) — third argument avoids NULL for the first row
    LAG(current_month_sales, 1, 0) OVER (ORDER BY sale_month) AS previous_month_sales,

    -- YTD: running sum that resets at year boundary
    SUM(current_month_sales) OVER (
        PARTITION BY YEAR(sale_month)
        ORDER BY sale_month
    ) AS ytd_sales

FROM current_month;

SELECT * FROM time_intel_windows;

-- Validate against data/02-window-lag-ytd.csv
