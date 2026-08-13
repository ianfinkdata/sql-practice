-- =============================================================================
-- PATTERN: SQL Pushdown vs. BI Semantic Layer Logic (sql-pushdown-vs-dax.sql)
-- CATEGORY: 05-bi-integration
-- PROBLEM IT SOLVES: Eliminates metric drift and logic sprawl between relational 
--                    databases and BI presentation tools (Power BI, Tableau, Looker).
-- WHEN TO USE IT: When building analytical data pipelines where calculations 
--                 (gross/net revenue, customer segmentation, discount tiers) 
--                 need to be standardized centrally before reaching BI reporting.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VERIFIED EXAMPLE (Executed against project/oakhaven.db)
-- -----------------------------------------------------------------------------
-- Centralized Gold View query that performs transformations in SQL pushdown
-- rather than requiring complex DAX measures or Power Query M transformations.

SELECT 
    f.order_id,
    f.order_line_id,
    f.order_date,
    c.customer_id,
    c.full_name AS customer_name,
    c.customer_segment,
    p.product_id,
    p.product_name,
    p.category AS product_category,
    f.quantity,
    f.unit_price,
    f.discount_pct,
    -- 1. SQL Pushdown: Gross Sales Calculation
    ROUND(f.quantity * f.unit_price, 2) AS gross_amount,
    -- 2. SQL Pushdown: Net Sales Calculation
    f.net_amount,
    -- 3. SQL Pushdown: Categorical Discount Bucketing
    CASE 
        WHEN f.discount_pct >= 0.20 THEN 'High Discount (20%+)'
        WHEN f.discount_pct > 0 THEN 'Standard Discount'
        ELSE 'Full Price'
    END AS discount_tier,
    f.order_status,
    f.channel
FROM fact_sales f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
LEFT JOIN dim_product p ON f.product_id = p.product_id
ORDER BY f.order_date DESC, f.order_id, f.order_line_id
LIMIT 100;

-- -----------------------------------------------------------------------------
-- PORTABILITY NOTES Across Enterprise Engines
-- -----------------------------------------------------------------------------
-- SQLite: ROUND(qty * price, 2) and CASE WHEN expressions work natively.
-- Snowflake / BigQuery: Use standard ROUND() and CASE WHEN logic identically.
-- Databricks (Spark SQL): Fully compatible with standard ANSI SQL joins and CASE statements.
-- PostgreSQL: ROUND((qty * price)::numeric, 2) for precise numeric casting.
-- -----------------------------------------------------------------------------
