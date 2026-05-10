-- ============================================================
-- Exercise 2, Step 1 — Extract emails from JSON using JSON_TABLE
--
-- Goal: From the contact_details JSON column, return one row
-- per customer showing only their email address.
--
-- Concepts: CTE (WITH), JSON_TABLE, CROSS JOIN, WHERE filter
-- ============================================================

USE [your_schema];

-- Pattern:
--   1. Name a CTE that selects the columns you need
--   2. CROSS JOIN the CTE to JSON_TABLE, which unpacks the JSON array
--   3. Filter to contact_type = 'email'

WITH contact_cte AS (
    SELECT customer_id, contact_details
    FROM customers
)

SELECT
    c.customer_id,
    j.email_address
FROM contact_cte AS c
CROSS JOIN JSON_TABLE(
    CAST(c.contact_details AS JSON),
    '$[*]' COLUMNS (
        contact_type   VARCHAR(50)  PATH '$.type',
        email_address  VARCHAR(255) PATH '$.value'
    )
) AS j
WHERE j.contact_type = 'email';

-- Expected: one row per customer with their email extracted.
-- Validate against data/01-json-cte.csv
