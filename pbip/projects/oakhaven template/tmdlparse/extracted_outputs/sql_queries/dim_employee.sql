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
