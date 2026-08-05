-- =============================================================================
-- MODEL: Flat Sales Model (01_flat_model)
-- PARADIGM: One Flat Table (Denormalized)
-- PURPOSE: Single-table reporting model with embedded SQL business logic.
-- ROW LIMIT: Capped at 100 rows for PoC testing.
-- SOURCE DATABASE: project/oakhaven.db
-- =============================================================================


-- =============================================================================
-- TABLE 1: flat_sales_all
-- Description: Denormalized sales with customer, product, employee, and date details.
--              Embeds revenue calculations and discount tier logic in SQL.
-- =============================================================================
SELECT 
    f.order_id,
    f.order_line_id,
    f.order_date,
    c.full_name AS customer_name,
    c.customer_segment,
    c.state AS customer_state,
    p.product_name,
    p.category AS product_category,
    p.brand AS product_brand,
    e.full_name AS sales_rep_name,
    e.region AS sales_region,
    f.quantity,
    f.unit_price,
    f.discount_pct,
    -- Embedded Business Logic #1: Gross Revenue
    ROUND(f.quantity * f.unit_price, 2) AS gross_amount,
    -- Embedded Business Logic #2: Net Revenue
    f.net_amount,
    -- Embedded Business Logic #3: Categorical Bucketing
    CASE 
        WHEN f.discount_pct >= 0.20 THEN 'High Discount (20%+)'
        WHEN f.discount_pct > 0 THEN 'Standard Discount'
        ELSE 'Full Price'
    END AS discount_tier,
    f.payment_method,
    f.order_status,
    f.channel
FROM fact_sales f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
LEFT JOIN dim_product p ON f.product_id = p.product_id
LEFT JOIN dim_employee e ON f.employee_id = e.employee_id
ORDER BY f.order_date DESC, f.order_id, f.order_line_id
LIMIT 100;


-- =============================================================================
-- TABLE 2: flat_sales_completed_variant
-- Description: Demonstrates business logic sprawl across models.
--              Uses almost the exact same query, but hardcodes a status filter.
-- =============================================================================
SELECT 
    f.order_id,
    f.order_line_id,
    f.order_date,
    c.full_name AS customer_name,
    p.product_name,
    p.category AS product_category,
    f.quantity,
    f.net_amount,
    f.channel
FROM fact_sales f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
LEFT JOIN dim_product p ON f.product_id = p.product_id
WHERE f.order_status = 'Completed'
ORDER BY f.order_date DESC
LIMIT 100;
