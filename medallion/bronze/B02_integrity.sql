-- TASK-20260704-02 · B02_integrity.sql · 2026-07-04
-- PURPOSE: PK uniqueness for all 14 tables + FK orphan anti-joins for all 16 declared FKs.
-- GROUNDING: medallion-spec §Bronze rules (bronze states facts, doesn't fix); CONTRACT §6 criteria 2-3
-- RUN: Get-Content B02_integrity.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- NOTE: two result sets in this batch run — PK check, then FK orphan check. Both expected all-zero-mismatch / all-zero-orphan.

-- Result set 1: PK uniqueness (total_rows must equal distinct_pk for every table)
SELECT 'stores' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT store_id) AS distinct_pk FROM oakhaven.stores
UNION ALL
SELECT 'employees', COUNT(*), COUNT(DISTINCT employee_id) FROM oakhaven.employees
UNION ALL
SELECT 'suppliers', COUNT(*), COUNT(DISTINCT supplier_id) FROM oakhaven.suppliers
UNION ALL
SELECT 'product_categories', COUNT(*), COUNT(DISTINCT category_id) FROM oakhaven.product_categories
UNION ALL
SELECT 'products', COUNT(*), COUNT(DISTINCT product_id) FROM oakhaven.products
UNION ALL
SELECT 'customers', COUNT(*), COUNT(DISTINCT customer_id) FROM oakhaven.customers
UNION ALL
SELECT 'promotions', COUNT(*), COUNT(DISTINCT promo_id) FROM oakhaven.promotions
UNION ALL
SELECT 'calendar', COUNT(*), COUNT(DISTINCT date_key) FROM oakhaven.calendar
UNION ALL
SELECT 'orders', COUNT(*), COUNT(DISTINCT order_id) FROM oakhaven.orders
UNION ALL
SELECT 'order_items', COUNT(*), COUNT(DISTINCT order_item_id) FROM oakhaven.order_items
UNION ALL
SELECT 'payments', COUNT(*), COUNT(DISTINCT payment_id) FROM oakhaven.payments
UNION ALL
SELECT 'shipments', COUNT(*), COUNT(DISTINCT shipment_id) FROM oakhaven.shipments
UNION ALL
SELECT 'returns', COUNT(*), COUNT(DISTINCT return_id) FROM oakhaven.returns
UNION ALL
SELECT 'inventory_movements', COUNT(*), COUNT(DISTINCT movement_id) FROM oakhaven.inventory_movements
ORDER BY table_name;

-- Result set 2: FK orphan anti-joins (orphan_count must be 0 for every FK; nullable FKs exclude NULLs, which are valid)
SELECT 'employees.manager_id -> employees.employee_id' AS fk_check, COUNT(*) AS orphan_count
FROM oakhaven.employees c LEFT JOIN oakhaven.employees p ON c.manager_id = p.employee_id
WHERE c.manager_id IS NOT NULL AND p.employee_id IS NULL
UNION ALL
SELECT 'employees.store_id -> stores.store_id', COUNT(*)
FROM oakhaven.employees c LEFT JOIN oakhaven.stores p ON c.store_id = p.store_id
WHERE p.store_id IS NULL
UNION ALL
SELECT 'inventory_movements.product_id -> products.product_id', COUNT(*)
FROM oakhaven.inventory_movements c LEFT JOIN oakhaven.products p ON c.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'inventory_movements.store_id -> stores.store_id', COUNT(*)
FROM oakhaven.inventory_movements c LEFT JOIN oakhaven.stores p ON c.store_id = p.store_id
WHERE p.store_id IS NULL
UNION ALL
SELECT 'order_items.order_id -> orders.order_id', COUNT(*)
FROM oakhaven.order_items c LEFT JOIN oakhaven.orders p ON c.order_id = p.order_id
WHERE p.order_id IS NULL
UNION ALL
SELECT 'order_items.product_id -> products.product_id', COUNT(*)
FROM oakhaven.order_items c LEFT JOIN oakhaven.products p ON c.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'orders.customer_id -> customers.customer_id', COUNT(*)
FROM oakhaven.orders c LEFT JOIN oakhaven.customers p ON c.customer_id = p.customer_id
WHERE p.customer_id IS NULL
UNION ALL
SELECT 'orders.employee_id -> employees.employee_id', COUNT(*)
FROM oakhaven.orders c LEFT JOIN oakhaven.employees p ON c.employee_id = p.employee_id
WHERE c.employee_id IS NOT NULL AND p.employee_id IS NULL
UNION ALL
SELECT 'orders.promo_id -> promotions.promo_id', COUNT(*)
FROM oakhaven.orders c LEFT JOIN oakhaven.promotions p ON c.promo_id = p.promo_id
WHERE c.promo_id IS NOT NULL AND p.promo_id IS NULL
UNION ALL
SELECT 'orders.store_id -> stores.store_id', COUNT(*)
FROM oakhaven.orders c LEFT JOIN oakhaven.stores p ON c.store_id = p.store_id
WHERE p.store_id IS NULL
UNION ALL
SELECT 'payments.order_id -> orders.order_id', COUNT(*)
FROM oakhaven.payments c LEFT JOIN oakhaven.orders p ON c.order_id = p.order_id
WHERE p.order_id IS NULL
UNION ALL
SELECT 'product_categories.parent_category_id -> product_categories.category_id', COUNT(*)
FROM oakhaven.product_categories c LEFT JOIN oakhaven.product_categories p ON c.parent_category_id = p.category_id
WHERE c.parent_category_id IS NOT NULL AND p.category_id IS NULL
UNION ALL
SELECT 'products.category_id -> product_categories.category_id', COUNT(*)
FROM oakhaven.products c LEFT JOIN oakhaven.product_categories p ON c.category_id = p.category_id
WHERE p.category_id IS NULL
UNION ALL
SELECT 'products.supplier_id -> suppliers.supplier_id', COUNT(*)
FROM oakhaven.products c LEFT JOIN oakhaven.suppliers p ON c.supplier_id = p.supplier_id
WHERE p.supplier_id IS NULL
UNION ALL
SELECT 'returns.order_item_id -> order_items.order_item_id', COUNT(*)
FROM oakhaven.returns c LEFT JOIN oakhaven.order_items p ON c.order_item_id = p.order_item_id
WHERE p.order_item_id IS NULL
UNION ALL
SELECT 'shipments.order_id -> orders.order_id', COUNT(*)
FROM oakhaven.shipments c LEFT JOIN oakhaven.orders p ON c.order_id = p.order_id
WHERE p.order_id IS NULL
ORDER BY fk_check;
