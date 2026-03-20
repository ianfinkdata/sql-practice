use squirrelpractice;

WITH emails AS (
    SELECT customer_id, contact_details 
    FROM sp_customers
)
SELECT 
    e.customer_id,
    j.email_address
FROM emails e
CROSS JOIN JSON_TABLE(
    CAST(e.contact_details AS JSON), 
    '$[*]' COLUMNS (
        contact_type VARCHAR(50) PATH '$.type',
        email_address VARCHAR(255) PATH '$.value'
    )
) AS j
WHERE j.contact_type = 'email';