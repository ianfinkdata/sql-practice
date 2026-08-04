-- silver_sales: cleaned/standardized view over bronze_sales -- the
-- messiest bronze table. Parses mixed order_date/ship_date formats,
-- normalizes payment_method/order_status/channel casing, fixes the
-- whole-number discount_pct data-entry bug, and -- most importantly --
-- recomputes a trustworthy net_amount from quantity * unit_price *
-- (1 - discount_pct) instead of trusting bronze's order_total column,
-- which is deliberately unreliable (stale pre-discount values, "$"
-- formatting, NULLs, and literal "TBD"/"N/A" placeholders).
-- Orphan customer_id/product_id rows are NOT dropped here -- they are
-- surfaced via is_customer_orphan / is_product_orphan so downstream
-- gold views and lessons can decide how to handle them.

DROP VIEW IF EXISTS silver_sales;
CREATE VIEW silver_sales AS
WITH base AS (
    SELECT
        s.order_id,
        s.order_line_id,
        s.customer_id,
        s.product_id,
        s.employee_id,
        s.order_date AS order_date_raw,
        s.ship_date AS ship_date_raw,
        s.quantity,
        s.unit_price,
        CASE WHEN s.discount_pct > 1 THEN s.discount_pct / 100.0 ELSE s.discount_pct END AS discount_pct,
        s.order_total AS order_total_raw,
        LOWER(TRIM(s.payment_method)) AS payment_method_key,
        LOWER(TRIM(s.order_status)) AS order_status_key,
        REPLACE(LOWER(TRIM(s.channel)), '-', ' ') AS channel_key
    FROM bronze_sales s
)
SELECT
    b.order_id,
    b.order_line_id,
    b.customer_id,
    b.product_id,
    b.employee_id,
    CASE
        WHEN order_date_raw IS NULL THEN NULL
        WHEN order_date_raw LIKE '__/__/____'
            THEN substr(order_date_raw, 7, 4) || '-' || substr(order_date_raw, 1, 2) || '-' || substr(order_date_raw, 4, 2)
        WHEN order_date_raw LIKE '____-__-__ __:__:__' THEN substr(order_date_raw, 1, 10)
        WHEN order_date_raw LIKE '____-__-__' THEN order_date_raw
        ELSE NULL
    END AS order_date,
    CASE
        WHEN ship_date_raw IS NULL THEN NULL
        WHEN ship_date_raw LIKE '__/__/____'
            THEN substr(ship_date_raw, 7, 4) || '-' || substr(ship_date_raw, 1, 2) || '-' || substr(ship_date_raw, 4, 2)
        WHEN ship_date_raw LIKE '____-__-__ __:__:__' THEN substr(ship_date_raw, 1, 10)
        WHEN ship_date_raw LIKE '____-__-__' THEN ship_date_raw
        ELSE NULL
    END AS ship_date,
    b.quantity,
    b.unit_price,
    b.discount_pct,
    ROUND(COALESCE(b.quantity, 0) * b.unit_price * (1 - b.discount_pct), 2) AS net_amount,
    b.order_total_raw,
    CASE payment_method_key
        WHEN 'credit card' THEN 'Credit Card'
        WHEN 'cc' THEN 'Credit Card'
        WHEN 'cash' THEN 'Cash'
        WHEN 'debit card' THEN 'Debit Card'
        WHEN 'paypal' THEN 'PayPal'
        WHEN 'gift card' THEN 'Gift Card'
        ELSE NULL
    END AS payment_method,
    CASE order_status_key
        WHEN 'completed' THEN 'Completed'
        WHEN 'cancelled' THEN 'Cancelled'
        WHEN 'returned' THEN 'Returned'
        ELSE NULL
    END AS order_status,
    CASE channel_key
        WHEN 'online' THEN 'Online'
        WHEN 'in store' THEN 'In-Store'
        ELSE NULL
    END AS channel,
    NOT EXISTS (SELECT 1 FROM bronze_customers c WHERE c.customer_id = b.customer_id) AS is_customer_orphan,
    NOT EXISTS (SELECT 1 FROM bronze_products p WHERE p.product_id = b.product_id) AS is_product_orphan
FROM base b;
