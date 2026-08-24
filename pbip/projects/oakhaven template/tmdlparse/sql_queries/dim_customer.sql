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
