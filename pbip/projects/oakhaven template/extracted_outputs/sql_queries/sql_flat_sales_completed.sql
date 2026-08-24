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
