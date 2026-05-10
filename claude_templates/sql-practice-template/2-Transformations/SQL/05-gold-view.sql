-- ============================================================
-- Exercise 2, Step 5 — Aggregate Silver into a Gold view
--
-- Goal: Build a Gold-layer view that summarizes rep performance
-- by month, and adds a cumulative sales total per rep.
--
-- Source: silver_sales_pipeline (must exist first — run Step 4)
-- Naming convention: gold_[descriptive_name]
--
-- Concepts: GROUP BY, aggregate functions, SUM() OVER(PARTITION BY)
-- ============================================================

USE [your_schema];

CREATE OR REPLACE VIEW gold_rep_performance AS

WITH monthly_summary AS (
    SELECT
        rep_name,
        sale_month,
        SUM(sale_amount)  AS total_revenue,
        COUNT(sale_id)    AS deals_closed,
        AVG(sale_amount)  AS average_deal_size
    FROM silver_sales_pipeline
    GROUP BY rep_name, sale_month
    ORDER BY sale_month, rep_name
)

SELECT
    *,
    SUM(total_revenue) OVER (PARTITION BY rep_name) AS rep_cumulative_sales
FROM monthly_summary;

SELECT * FROM gold_rep_performance;
