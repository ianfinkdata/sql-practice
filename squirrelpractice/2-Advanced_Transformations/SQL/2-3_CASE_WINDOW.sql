WITH customer AS (
    SELECT 
    c.customer_id,
    c.region,
    c.customer_name as name,
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
 customer.name,
 customer.region,
 customer.email_address as customer_email,
 r.rep_name, 
 s.sale_amount,
 s.sale_date - interval(day(s.sale_date) - 1) day as sale_month,
 CASE 
	WHEN s.sale_amount < 2000 then 'Low Value'
	WHEN s.sale_amount >= 3000 then 'High Value'
	ELSE 'Standard'
 END AS deal_size_category,
 RANK() OVER( PARTITION BY customer.region, r.rep_name ORDER BY s.sale_amount DESC) as rep_sales_rank   
 from sp_sales as s
 left join customer on s.customer_id = customer.customer_id
 left join sp_sales_rep as r on s.rep_id = r.rep_id
 ;
 