-- agg_customer_ltv: lifetime-value rollup per customer. LEFT JOINs to
-- fact_sales so customers with zero orders still appear (with 0/NULL
-- measures) rather than being dropped.

DROP VIEW IF EXISTS agg_customer_ltv;
CREATE VIEW agg_customer_ltv AS
SELECT
    c.customer_id,
    c.full_name,
    c.customer_segment,
    c.state,
    COUNT(DISTINCT f.order_id) AS order_count,
    COUNT(f.order_line_id) AS order_line_count,
    ROUND(COALESCE(SUM(f.net_amount), 0), 2) AS lifetime_net_amount,
    MIN(f.order_date) AS first_order_date,
    MAX(f.order_date) AS last_order_date
FROM dim_customer c
LEFT JOIN fact_sales f ON f.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.customer_segment, c.state;
