-- ============================================================
-- Exercise 2, Step 2 — Join tables and add sale_month
--
-- Goal: Combine sales with customers (via JSON email extraction)
-- and add a sale_month column that normalizes any date to the
-- first day of its month.
--
-- Concepts: LEFT JOIN, interval math, building on Step 1's CTE
-- ============================================================

USE [your_schema];

WITH customer AS (
    SELECT
        c.customer_id,
        c.region,
        c.customer_name AS name,
        j.email_address
    FROM customers AS c
    CROSS JOIN JSON_TABLE(
        CAST(c.contact_details AS JSON),
        '$[*]' COLUMNS (
            contact_type   VARCHAR(50)  PATH '$.type',
            email_address  VARCHAR(255) PATH '$.value'
        )
    ) AS j
    WHERE j.contact_type = 'email'
)

SELECT
    s.sale_id,
    s.customer_id,
    customer.name,
    customer.region,
    customer.email_address          AS customer_email,
    s.rep_id,
    s.sale_amount,
    -- Interval math: subtract (day-of-month - 1) days to land on the 1st
    s.sale_date - INTERVAL (DAY(s.sale_date) - 1) DAY AS sale_month
FROM sales AS s
LEFT JOIN customer ON s.customer_id = customer.customer_id;

-- Validate against data/02-join-enrich.csv
