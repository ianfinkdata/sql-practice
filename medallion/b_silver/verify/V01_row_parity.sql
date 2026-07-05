-- TASK-20260704-03 · V01_row_parity.sql · 2026-07-04
-- PURPOSE: Prove grain preservation — row count of every silver view equals its bronze table
--          (all 14 views; reconciles to bronze B01 captures).
-- GROUNDING: RULE-005 (silver flags, never filters); medallion-spec §Silver rules;
--            RULE-001 (deterministic ORDER BY), RULE-012 (literal alias ordered with pinned collation)
-- RUN: Get-Content V01_row_parity.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: 14 rows, bronze_rows = silver_rows on every row (B01 numbers), is_match = 1 throughout.

SELECT 'calendar' AS table_name,
       (SELECT COUNT(*) FROM oakhaven.calendar)                    AS bronze_rows,
       (SELECT COUNT(*) FROM oakhaven_silver.calendar)             AS silver_rows,
       (SELECT COUNT(*) FROM oakhaven.calendar) = (SELECT COUNT(*) FROM oakhaven_silver.calendar) AS is_match
UNION ALL
SELECT 'customers',
       (SELECT COUNT(*) FROM oakhaven.customers),
       (SELECT COUNT(*) FROM oakhaven_silver.customers),
       (SELECT COUNT(*) FROM oakhaven.customers) = (SELECT COUNT(*) FROM oakhaven_silver.customers)
UNION ALL
SELECT 'employees',
       (SELECT COUNT(*) FROM oakhaven.employees),
       (SELECT COUNT(*) FROM oakhaven_silver.employees),
       (SELECT COUNT(*) FROM oakhaven.employees) = (SELECT COUNT(*) FROM oakhaven_silver.employees)
UNION ALL
SELECT 'inventory_movements',
       (SELECT COUNT(*) FROM oakhaven.inventory_movements),
       (SELECT COUNT(*) FROM oakhaven_silver.inventory_movements),
       (SELECT COUNT(*) FROM oakhaven.inventory_movements) = (SELECT COUNT(*) FROM oakhaven_silver.inventory_movements)
UNION ALL
SELECT 'order_items',
       (SELECT COUNT(*) FROM oakhaven.order_items),
       (SELECT COUNT(*) FROM oakhaven_silver.order_items),
       (SELECT COUNT(*) FROM oakhaven.order_items) = (SELECT COUNT(*) FROM oakhaven_silver.order_items)
UNION ALL
SELECT 'orders',
       (SELECT COUNT(*) FROM oakhaven.orders),
       (SELECT COUNT(*) FROM oakhaven_silver.orders),
       (SELECT COUNT(*) FROM oakhaven.orders) = (SELECT COUNT(*) FROM oakhaven_silver.orders)
UNION ALL
SELECT 'payments',
       (SELECT COUNT(*) FROM oakhaven.payments),
       (SELECT COUNT(*) FROM oakhaven_silver.payments),
       (SELECT COUNT(*) FROM oakhaven.payments) = (SELECT COUNT(*) FROM oakhaven_silver.payments)
UNION ALL
SELECT 'product_categories',
       (SELECT COUNT(*) FROM oakhaven.product_categories),
       (SELECT COUNT(*) FROM oakhaven_silver.product_categories),
       (SELECT COUNT(*) FROM oakhaven.product_categories) = (SELECT COUNT(*) FROM oakhaven_silver.product_categories)
UNION ALL
SELECT 'products',
       (SELECT COUNT(*) FROM oakhaven.products),
       (SELECT COUNT(*) FROM oakhaven_silver.products),
       (SELECT COUNT(*) FROM oakhaven.products) = (SELECT COUNT(*) FROM oakhaven_silver.products)
UNION ALL
SELECT 'promotions',
       (SELECT COUNT(*) FROM oakhaven.promotions),
       (SELECT COUNT(*) FROM oakhaven_silver.promotions),
       (SELECT COUNT(*) FROM oakhaven.promotions) = (SELECT COUNT(*) FROM oakhaven_silver.promotions)
UNION ALL
SELECT 'returns',
       (SELECT COUNT(*) FROM oakhaven.returns),
       (SELECT COUNT(*) FROM oakhaven_silver.returns),
       (SELECT COUNT(*) FROM oakhaven.returns) = (SELECT COUNT(*) FROM oakhaven_silver.returns)
UNION ALL
SELECT 'shipments',
       (SELECT COUNT(*) FROM oakhaven.shipments),
       (SELECT COUNT(*) FROM oakhaven_silver.shipments),
       (SELECT COUNT(*) FROM oakhaven.shipments) = (SELECT COUNT(*) FROM oakhaven_silver.shipments)
UNION ALL
SELECT 'stores',
       (SELECT COUNT(*) FROM oakhaven.stores),
       (SELECT COUNT(*) FROM oakhaven_silver.stores),
       (SELECT COUNT(*) FROM oakhaven.stores) = (SELECT COUNT(*) FROM oakhaven_silver.stores)
UNION ALL
SELECT 'suppliers',
       (SELECT COUNT(*) FROM oakhaven.suppliers),
       (SELECT COUNT(*) FROM oakhaven_silver.suppliers),
       (SELECT COUNT(*) FROM oakhaven.suppliers) = (SELECT COUNT(*) FROM oakhaven_silver.suppliers)
ORDER BY table_name COLLATE utf8mb4_bin;
