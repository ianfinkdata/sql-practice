-- silver_employees: cleaned/standardized view over bronze_employees.
-- Normalizes department/region casing, coalesces is_manager to 0/1,
-- and parses mixed hire_date/termination_date formats to ISO.
-- termination_date staying NULL means "still employed as of SNAPSHOT_DATE".

DROP VIEW IF EXISTS silver_employees;
CREATE VIEW silver_employees AS
WITH base AS (
    SELECT
        e.employee_id,
        UPPER(SUBSTR(TRIM(e.first_name), 1, 1)) || LOWER(SUBSTR(TRIM(e.first_name), 2)) AS first_name,
        UPPER(SUBSTR(TRIM(e.last_name), 1, 1)) || LOWER(SUBSTR(TRIM(e.last_name), 2)) AS last_name,
        LOWER(TRIM(e.department)) AS department_key,
        LOWER(TRIM(e.region)) AS region_key,
        e.hire_date AS hire_date_raw,
        e.termination_date AS termination_date_raw,
        e.is_manager AS is_manager_raw,
        NULLIF(TRIM(LOWER(e.email)), '') AS email
    FROM bronze_employees e
)
SELECT
    employee_id,
    first_name,
    last_name,
    first_name || ' ' || last_name AS full_name,
    CASE department_key
        WHEN 'sales' THEN 'Sales'
        WHEN 'support' THEN 'Support'
        WHEN 'warehouse' THEN 'Warehouse'
        WHEN 'management' THEN 'Management'
        ELSE NULL
    END AS department,
    CASE region_key
        WHEN 'west' THEN 'West'
        WHEN 'east' THEN 'East'
        WHEN 'central' THEN 'Central'
        WHEN 'south' THEN 'South'
        WHEN 'northeast' THEN 'Northeast'
        ELSE NULL
    END AS region,
    CASE
        WHEN hire_date_raw IS NULL THEN NULL
        WHEN hire_date_raw LIKE '__/__/____'
            THEN substr(hire_date_raw, 7, 4) || '-' || substr(hire_date_raw, 1, 2) || '-' || substr(hire_date_raw, 4, 2)
        WHEN hire_date_raw LIKE '____-__-__ __:__:__' THEN substr(hire_date_raw, 1, 10)
        WHEN hire_date_raw LIKE '____-__-__' THEN hire_date_raw
        ELSE NULL
    END AS hire_date,
    CASE
        WHEN termination_date_raw IS NULL THEN NULL
        WHEN termination_date_raw LIKE '__/__/____'
            THEN substr(termination_date_raw, 7, 4) || '-' || substr(termination_date_raw, 1, 2) || '-' || substr(termination_date_raw, 4, 2)
        WHEN termination_date_raw LIKE '____-__-__ __:__:__' THEN substr(termination_date_raw, 1, 10)
        WHEN termination_date_raw LIKE '____-__-__' THEN termination_date_raw
        ELSE NULL
    END AS termination_date,
    CASE
        WHEN LOWER(TRIM(is_manager_raw)) IN ('y', 'yes', 'true', '1') THEN 1
        WHEN LOWER(TRIM(is_manager_raw)) IN ('n', 'no', 'false', '0') THEN 0
        ELSE NULL
    END AS is_manager,
    email
FROM base;
