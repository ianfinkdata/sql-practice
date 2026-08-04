-- dim_customer: business-ready customer dimension. One row per
-- bronze_customers row (including the intentional near-duplicate
-- people -- deduping them is a dedicated ROW_NUMBER lesson, not baked
-- in here).

DROP VIEW IF EXISTS dim_customer;
CREATE VIEW dim_customer AS
SELECT
    customer_id,
    first_name,
    last_name,
    full_name,
    email,
    phone,
    state,
    signup_date,
    is_active,
    customer_segment
FROM silver_customers;
