-- ============================================================
-- Exercise 2, Step 3 — Add deal category (CASE) and rank (RANK OVER)
--
-- Goal: Extend Step 2's query with:
--   1. A deal_size_category column using CASE WHEN on sale_amount
--   2. A rank that orders sales within each region by amount descending
--
-- Concepts: CASE WHEN, RANK() OVER (PARTITION BY ... ORDER BY ...)
-- ============================================================

USE [your_schema];

-- TODO: Copy the full query from Step 2 and add two columns:
--
-- CASE
--     WHEN s.sale_amount < 2000  THEN 'Low Value'
--     WHEN s.sale_amount >= 3000 THEN 'High Value'
--     ELSE 'Standard'
-- END AS deal_size_category,
--
-- RANK() OVER (
--     PARTITION BY customer.region
--     ORDER BY s.sale_amount DESC
-- ) AS region_sales_rank

-- Also add the rep_name by joining to sales_rep.

-- Validate against data/03-case-window.csv
