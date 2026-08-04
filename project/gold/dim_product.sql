-- dim_product: business-ready product dimension.
-- sku_is_duplicate surfaces the intentional ~2% SKU collision rate.

DROP VIEW IF EXISTS dim_product;
CREATE VIEW dim_product AS
SELECT
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    unit_cost,
    unit_price,
    is_discontinued,
    sku,
    sku_is_duplicate,
    weight_kg,
    created_at
FROM silver_products;
