-- silver_products: cleaned/standardized view over bronze_products.
-- Normalizes category to the 8 canonical names, coalesces
-- is_discontinued to 0/1, parses weight_kg's dirty text to a real
-- number, parses mixed created_at date formats to ISO, and surfaces
-- (does not silently fix) the intentional SKU collisions via
-- sku_is_duplicate so downstream lessons can find them.

DROP VIEW IF EXISTS silver_products;
CREATE VIEW silver_products AS
WITH base AS (
    SELECT
        p.product_id,
        TRIM(p.product_name) AS product_name,
        LOWER(TRIM(REPLACE(p.category, '  ', ' '))) AS category_key,
        NULLIF(TRIM(p.subcategory), '') AS subcategory,
        TRIM(p.brand) AS brand,
        p.unit_cost AS unit_cost,
        p.unit_price AS unit_price,
        p.is_discontinued AS is_discontinued_raw,
        TRIM(p.sku) AS sku,
        p.weight_kg AS weight_kg_raw,
        p.created_at AS created_at_raw
    FROM bronze_products p
)
SELECT
    product_id,
    product_name,
    CASE category_key
        WHEN 'footwear' THEN 'Footwear'
        WHEN 'foot wear' THEN 'Footwear'
        WHEN 'apparel' THEN 'Apparel'
        WHEN 'camping & hiking' THEN 'Camping & Hiking'
        WHEN 'camping and hiking' THEN 'Camping & Hiking'
        WHEN 'climbing' THEN 'Climbing'
        WHEN 'water sports' THEN 'Water Sports'
        WHEN 'winter sports' THEN 'Winter Sports'
        WHEN 'accessories' THEN 'Accessories'
        WHEN 'nutrition & hydration' THEN 'Nutrition & Hydration'
        WHEN 'nutrition and hydration' THEN 'Nutrition & Hydration'
        ELSE NULL
    END AS category,
    subcategory,
    brand,
    unit_cost,
    unit_price,
    CASE
        WHEN LOWER(TRIM(is_discontinued_raw)) IN ('y', 'yes', 'true', '1') THEN 1
        WHEN LOWER(TRIM(is_discontinued_raw)) IN ('n', 'no', 'false', '0') THEN 0
        ELSE NULL
    END AS is_discontinued,
    sku,
    COUNT(*) OVER (PARTITION BY sku) > 1 AS sku_is_duplicate,
    CASE
        WHEN weight_kg_raw IS NULL THEN NULL
        WHEN weight_kg_raw LIKE '% kg' THEN CAST(TRIM(REPLACE(weight_kg_raw, ' kg', '')) AS REAL)
        ELSE CAST(weight_kg_raw AS REAL)
    END AS weight_kg,
    CASE
        WHEN created_at_raw IS NULL THEN NULL
        WHEN created_at_raw LIKE '__/__/____'
            THEN substr(created_at_raw, 7, 4) || '-' || substr(created_at_raw, 1, 2) || '-' || substr(created_at_raw, 4, 2)
        WHEN created_at_raw LIKE '____-__-__ __:__:__' THEN substr(created_at_raw, 1, 10)
        WHEN created_at_raw LIKE '____-__-__' THEN created_at_raw
        ELSE NULL
    END AS created_at
FROM base;
