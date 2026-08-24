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
