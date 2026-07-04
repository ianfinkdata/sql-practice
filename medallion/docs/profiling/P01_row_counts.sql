-- TASK-20260704-01 · P01_row_counts.sql · 2026-07-04
-- PURPOSE: Exact COUNT(*) row counts for all 14 bronze tables
-- GROUNDING: IDX-004 cross-check
SELECT 'stores' AS tbl, COUNT(*) AS rows_ FROM oakhaven.stores
UNION ALL SELECT 'employees', COUNT(*) FROM oakhaven.employees
UNION ALL SELECT 'suppliers', COUNT(*) FROM oakhaven.suppliers
UNION ALL SELECT 'product_categories', COUNT(*) FROM oakhaven.product_categories
UNION ALL SELECT 'products', COUNT(*) FROM oakhaven.products
UNION ALL SELECT 'customers', COUNT(*) FROM oakhaven.customers
UNION ALL SELECT 'promotions', COUNT(*) FROM oakhaven.promotions
UNION ALL SELECT 'calendar', COUNT(*) FROM oakhaven.calendar
UNION ALL SELECT 'orders', COUNT(*) FROM oakhaven.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM oakhaven.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM oakhaven.payments
UNION ALL SELECT 'shipments', COUNT(*) FROM oakhaven.shipments
UNION ALL SELECT 'returns', COUNT(*) FROM oakhaven.returns
UNION ALL SELECT 'inventory_movements', COUNT(*) FROM oakhaven.inventory_movements
-- COLLATE pin: a string-literal alias otherwise inherits the session collation,
-- which made row order vary between runs (validator finding, 2026-07-04).
ORDER BY tbl COLLATE utf8mb4_bin;
