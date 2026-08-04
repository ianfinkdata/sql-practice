-- agg_monthly_sales_by_category: monthly rollup of net sales by product
-- category. Inner-joins to dim_date/dim_product, so order lines with a
-- NULL order_date or an orphan product_id are (by design) excluded --
-- they can't be placed on a calendar or into a category. No
-- order_status filter is applied here; that's left as a lesson exercise.

DROP VIEW IF EXISTS agg_monthly_sales_by_category;
CREATE VIEW agg_monthly_sales_by_category AS
SELECT
    d.year,
    d.month,
    d.month_name,
    p.category,
    COUNT(*) AS order_line_count,
    SUM(f.quantity) AS total_quantity,
    ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_date d ON d.datekey = f.datekey
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY d.year, d.month, d.month_name, p.category
ORDER BY d.year, d.month, p.category;
