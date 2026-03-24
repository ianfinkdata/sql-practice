use squirrelpractice;

WITH cust_email AS (
    SELECT 
    c.customer_id, 
    j.email_address
    FROM sp_customers as c
    CROSS JOIN JSON_TABLE(
    CAST(c.contact_details AS JSON), 
    '$[*]' COLUMNS (
        contact_type VARCHAR(50) PATH '$.type',
        email_address VARCHAR(255) PATH '$.value'
    )
) AS j
WHERE j.contact_type = 'email'
)

 select 
 s.sale_id, 
 s.customer_id, 
 cust_email.email_address as customer_email,
 s.rep_id, 
 s.sale_amount,
 s.sale_date - interval(day(s.sale_date) - 1) day as sale_month
 from sp_sales as s
 left join cust_email on s.customer_id = cust_email.customer_id;