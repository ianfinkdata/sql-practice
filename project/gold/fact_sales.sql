-- fact_sales: grain = one row per order line. Built on top of
-- silver_sales (never raw bronze). Carries FKs to all four dimensions
-- (customer_id -> dim_customer, product_id -> dim_product,
-- employee_id -> dim_employee, datekey -> dim_date) plus a recomputed
-- trustworthy net_amount measure. FK columns are NOT joined/validated
-- here -- orphan customer_id/product_id values (is_customer_orphan /
-- is_product_orphan) and NULL employee_id (online/no-rep sale) or NULL
-- datekey (missing order_date) are passed through by design so
-- learners can practice detecting them via joins.

DROP VIEW IF EXISTS fact_sales;
CREATE VIEW fact_sales AS
SELECT
    s.order_id,
    s.order_line_id,
    s.customer_id,
    s.product_id,
    s.employee_id,
    CAST(strftime('%Y%m%d', s.order_date) AS INTEGER) AS datekey,
    s.order_date,
    s.ship_date,
    s.quantity,
    s.unit_price,
    s.discount_pct,
    s.net_amount,
    s.payment_method,
    s.order_status,
    s.channel,
    s.is_customer_orphan,
    s.is_product_orphan
FROM silver_sales s;
