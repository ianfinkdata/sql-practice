-- dim_employee: business-ready employee dimension.
-- termination_date NULL means still employed as of SNAPSHOT_DATE
-- (2026-06-30) -- this is the SCD Type 2 hook for a later lesson.

DROP VIEW IF EXISTS dim_employee;
CREATE VIEW dim_employee AS
SELECT
    employee_id,
    first_name,
    last_name,
    full_name,
    department,
    region,
    hire_date,
    termination_date,
    is_manager,
    email
FROM silver_employees;
