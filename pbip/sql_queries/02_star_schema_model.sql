-- =============================================================================
-- MODEL: Enterprise Star Schema (02_star_schema_model)
-- PARADIGM: Dimensional Model (1 Fact + 4 Dimensions)
-- PURPOSE: Traditional star-schema Power BI model linked via relationships.
-- ROW LIMIT: Capped at 100 fact rows; dimensions dynamically scoped to matching keys.
-- SOURCE DATABASE: project/oakhaven.db
-- =============================================================================


-- =============================================================================
-- TABLE 1: fact_sales
-- Description: Central fact table containing order line measures and surrogate keys.
-- =============================================================================
SELECT 
    f.order_id,
    f.order_line_id,
    f.customer_id,
    f.product_id,
    f.employee_id,
    f.datekey,
    f.quantity,
    f.unit_price,
    f.discount_pct,
    f.net_amount,
    f.payment_method,
    f.order_status,
    f.channel
FROM fact_sales f
ORDER BY f.order_date DESC, f.order_id, f.order_line_id
LIMIT 100;


-- =============================================================================
-- TABLE 2: dim_customer
-- Description: Customer dimension attributes scoped to matching fact rows.
-- =============================================================================
SELECT DISTINCT 
    c.customer_id,
    c.full_name,
    c.email,
    c.state,
    c.customer_segment
FROM dim_customer c
WHERE c.customer_id IN (
    SELECT customer_id 
    FROM fact_sales 
    ORDER BY order_date DESC, order_id, order_line_id 
    LIMIT 100
);


-- =============================================================================
-- TABLE 3: dim_product
-- Description: Product dimension attributes scoped to matching fact rows.
-- =============================================================================
SELECT DISTINCT 
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    p.unit_cost,
    p.unit_price
FROM dim_product p
WHERE p.product_id IN (
    SELECT product_id 
    FROM fact_sales 
    ORDER BY order_date DESC, order_id, order_line_id 
    LIMIT 100
);


-- =============================================================================
-- TABLE 4: dim_employee
-- Description: Sales rep employee dimension attributes scoped to matching fact rows.
-- =============================================================================
SELECT DISTINCT 
    e.employee_id,
    e.full_name,
    e.department,
    e.region
FROM dim_employee e
WHERE e.employee_id IN (
    SELECT employee_id 
    FROM fact_sales 
    ORDER BY order_date DESC, order_id, order_line_id 
    LIMIT 100
);


-- =============================================================================
-- TABLE 5: dim_date
-- Description: Date dimension attributes scoped to matching fact order dates.
-- =============================================================================
SELECT DISTINCT 
    d.datekey,
    d.date,
    d.year,
    d.month,
    d.month_name,
    d.quarter,
    d.day_name,
    d.is_weekend
FROM dim_date d
WHERE d.datekey IN (
    SELECT datekey 
    FROM fact_sales 
    ORDER BY order_date DESC, order_id, order_line_id 
    LIMIT 100
);
