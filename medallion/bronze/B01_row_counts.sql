-- TASK-20260704-02 · B01_row_counts.sql · 2026-07-04
-- PURPOSE: Bronze row counts for all 14 oakhaven tables (reference numbers for later layers).
-- GROUNDING: medallion-spec §Bronze rules (bronze query pack states facts only)
-- RUN: Get-Content B01_row_counts.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven

SELECT 'stores' AS table_name, COUNT(*) AS row_count FROM oakhaven.stores
UNION ALL
SELECT 'employees', COUNT(*) FROM oakhaven.employees
UNION ALL
SELECT 'suppliers', COUNT(*) FROM oakhaven.suppliers
UNION ALL
SELECT 'product_categories', COUNT(*) FROM oakhaven.product_categories
UNION ALL
SELECT 'products', COUNT(*) FROM oakhaven.products
UNION ALL
SELECT 'customers', COUNT(*) FROM oakhaven.customers
UNION ALL
SELECT 'promotions', COUNT(*) FROM oakhaven.promotions
UNION ALL
SELECT 'calendar', COUNT(*) FROM oakhaven.calendar
UNION ALL
SELECT 'orders', COUNT(*) FROM oakhaven.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM oakhaven.order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM oakhaven.payments
UNION ALL
SELECT 'shipments', COUNT(*) FROM oakhaven.shipments
UNION ALL
SELECT 'returns', COUNT(*) FROM oakhaven.returns
UNION ALL
SELECT 'inventory_movements', COUNT(*) FROM oakhaven.inventory_movements
ORDER BY table_name;
