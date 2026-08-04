-- silver_customers: cleaned/standardized view over bronze_customers.
-- Trims + normalizes casing, normalizes phone to "(XXX) XXX-XXXX",
-- normalizes state to a 2-letter code, parses mixed date formats to
-- ISO (YYYY-MM-DD), and coalesces the mixed-boolean is_active text
-- pool to a real 0/1 integer. Does NOT deduplicate the intentional
-- near-duplicate people -- that's left for a dedicated ROW_NUMBER lesson.

DROP VIEW IF EXISTS silver_customers;
CREATE VIEW silver_customers AS
WITH state_map(name_key, abbr) AS (
    VALUES
        ('alabama', 'AL'), ('alaska', 'AK'), ('arizona', 'AZ'), ('arkansas', 'AR'),
        ('california', 'CA'), ('colorado', 'CO'), ('connecticut', 'CT'), ('delaware', 'DE'),
        ('florida', 'FL'), ('georgia', 'GA'), ('hawaii', 'HI'), ('idaho', 'ID'),
        ('illinois', 'IL'), ('indiana', 'IN'), ('iowa', 'IA'), ('kansas', 'KS'),
        ('kentucky', 'KY'), ('louisiana', 'LA'), ('maine', 'ME'), ('maryland', 'MD'),
        ('massachusetts', 'MA'), ('michigan', 'MI'), ('minnesota', 'MN'), ('mississippi', 'MS'),
        ('missouri', 'MO'), ('montana', 'MT'), ('nebraska', 'NE'), ('nevada', 'NV'),
        ('new hampshire', 'NH'), ('new jersey', 'NJ'), ('new mexico', 'NM'), ('new york', 'NY'),
        ('north carolina', 'NC'), ('north dakota', 'ND'), ('ohio', 'OH'), ('oklahoma', 'OK'),
        ('oregon', 'OR'), ('pennsylvania', 'PA'), ('rhode island', 'RI'), ('south carolina', 'SC'),
        ('south dakota', 'SD'), ('tennessee', 'TN'), ('texas', 'TX'), ('utah', 'UT'),
        ('vermont', 'VT'), ('virginia', 'VA'), ('washington', 'WA'), ('west virginia', 'WV'),
        ('wisconsin', 'WI'), ('wyoming', 'WY'),
        ('calif.', 'CA'), ('fla.', 'FL'), ('mass.', 'MA'), ('penn.', 'PA'), ('wash.', 'WA')
),
base AS (
    SELECT
        c.customer_id,
        -- collapse doubled internal spaces, trim, then capitalize the
        -- first letter only (names are single tokens from generation;
        -- true title-casing of multi-word names isn't attempted here).
        TRIM(REPLACE(REPLACE(TRIM(c.first_name), '  ', ' '), '  ', ' ')) AS fn_collapsed,
        TRIM(REPLACE(REPLACE(TRIM(c.last_name), '  ', ' '), '  ', ' ')) AS ln_collapsed,
        NULLIF(TRIM(LOWER(c.email)), '') AS email,
        c.phone AS phone_raw,
        NULLIF(TRIM(c.state), '') AS state_raw,
        c.signup_date AS signup_date_raw,
        c.is_active AS is_active_raw,
        c.customer_segment AS segment_raw
    FROM bronze_customers c
)
SELECT
    customer_id,
    UPPER(SUBSTR(fn_collapsed, 1, 1)) || LOWER(SUBSTR(fn_collapsed, 2)) AS first_name,
    UPPER(SUBSTR(ln_collapsed, 1, 1)) || LOWER(SUBSTR(ln_collapsed, 2)) AS last_name,
    UPPER(SUBSTR(fn_collapsed, 1, 1)) || LOWER(SUBSTR(fn_collapsed, 2)) || ' ' ||
        UPPER(SUBSTR(ln_collapsed, 1, 1)) || LOWER(SUBSTR(ln_collapsed, 2)) AS full_name,
    email,
    CASE
        WHEN phone_raw IS NULL OR TRIM(phone_raw) = '' THEN NULL
        WHEN phone_raw LIKE '(___) ___-____'
            THEN '(' || substr(phone_raw, 2, 3) || ') ' || substr(phone_raw, 7, 3) || '-' || substr(phone_raw, 11, 4)
        WHEN phone_raw LIKE '___-___-____'
            THEN '(' || substr(phone_raw, 1, 3) || ') ' || substr(phone_raw, 5, 3) || '-' || substr(phone_raw, 9, 4)
        WHEN phone_raw LIKE '___.___.____'
            THEN '(' || substr(phone_raw, 1, 3) || ') ' || substr(phone_raw, 5, 3) || '-' || substr(phone_raw, 9, 4)
        WHEN phone_raw LIKE '+1 ___ ___ ____'
            THEN '(' || substr(phone_raw, 4, 3) || ') ' || substr(phone_raw, 8, 3) || '-' || substr(phone_raw, 12, 4)
        WHEN phone_raw GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
            THEN '(' || substr(phone_raw, 1, 3) || ') ' || substr(phone_raw, 4, 3) || '-' || substr(phone_raw, 7, 4)
        ELSE phone_raw
    END AS phone,
    COALESCE(
        (SELECT abbr FROM state_map WHERE name_key = LOWER(state_raw)),
        (SELECT abbr FROM state_map WHERE abbr = UPPER(state_raw))
    ) AS state,
    CASE
        WHEN signup_date_raw IS NULL THEN NULL
        WHEN signup_date_raw LIKE '__/__/____'
            THEN substr(signup_date_raw, 7, 4) || '-' || substr(signup_date_raw, 1, 2) || '-' || substr(signup_date_raw, 4, 2)
        WHEN signup_date_raw LIKE '____-__-__ __:__:__' THEN substr(signup_date_raw, 1, 10)
        WHEN signup_date_raw LIKE '____-__-__' THEN signup_date_raw
        ELSE NULL
    END AS signup_date,
    CASE
        WHEN LOWER(TRIM(is_active_raw)) IN ('y', 'yes', 'true', '1') THEN 1
        WHEN LOWER(TRIM(is_active_raw)) IN ('n', 'no', 'false', '0') THEN 0
        ELSE NULL
    END AS is_active,
    CASE LOWER(TRIM(segment_raw))
        WHEN 'retail' THEN 'Retail'
        WHEN 'wholesale' THEN 'Wholesale'
        WHEN 'vip' THEN 'VIP'
        ELSE NULL
    END AS customer_segment
FROM base;
