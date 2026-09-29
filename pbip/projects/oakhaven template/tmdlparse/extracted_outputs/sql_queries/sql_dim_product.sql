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
