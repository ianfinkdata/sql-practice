-- ============================================================
-- Exercise 3, Tier 1 — Prior month via self-join
--
-- Business Requirement: For every month, show current month total revenue,
-- prior month total revenue, and the dollar variance between them.
--
-- Technical Constraint: Use a self-join + date math. Window functions prohibited.
-- ============================================================

USE [your_schema];

CREATE OR REPLACE VIEW time_intel_joins AS

WITH current_month AS (
    SELECT
        sale_date - INTERVAL (DAY(sale_date) - 1) DAY AS sale_month,
        SUM(sale_amount) AS sale_amount
    FROM sales
    GROUP BY sale_month
)

SELECT
    c.sale_month,
    IFNULL(c.sale_amount, 0) AS current_month_sales,
    IFNULL(p.sale_amount, 0) AS previous_month_sales,
    IFNULL(c.sale_amount, 0) - IFNULL(p.sale_amount, 0) AS variance
FROM current_month AS c
-- Self-join: find the row whose sale_month is exactly one month before c.sale_month
LEFT JOIN current_month AS p
    ON p.sale_month = DATE_ADD(c.sale_month, INTERVAL -1 MONTH)
ORDER BY c.sale_month;

SELECT * FROM time_intel_joins;

-- Validate against data/01-self-join-prior-month.csv
