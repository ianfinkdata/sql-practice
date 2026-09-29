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
