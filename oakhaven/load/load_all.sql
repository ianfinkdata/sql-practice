-- Oakhaven load script — contract v1.1.
-- Run via load/run_load.ps1 (handles the local_infile toggle), or manually:
--   mysql --defaults-extra-file="C:\Users\ianfi\.my.cnf" --local-infile=1 < load_all.sql
-- Requires: SET GLOBAL local_infile = 1 (run_load.ps1 enables, then restores OFF).
-- FK checks stay ON deliberately — a violation should fail the load loudly.
-- Load order: parents before children. calendar is already populated by
-- ddl/02_calendar_copy.sql and is not touched here.

USE oakhaven;

-- Rerunnable: clear children first, then parents (calendar untouched).
DELETE FROM inventory_movements;
DELETE FROM `returns`;
DELETE FROM shipments;
DELETE FROM payments;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM promotions;
DELETE FROM customers;
DELETE FROM products;
DELETE FROM employees;
DELETE FROM suppliers;
DELETE FROM product_categories;
DELETE FROM stores;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/stores.csv'
  INTO TABLE stores
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/product_categories.csv'
  INTO TABLE product_categories
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/suppliers.csv'
  INTO TABLE suppliers
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/employees.csv'
  INTO TABLE employees
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/products.csv'
  INTO TABLE products
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/customers.csv'
  INTO TABLE customers
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/promotions.csv'
  INTO TABLE promotions
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/orders.csv'
  INTO TABLE orders
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/order_items.csv'
  INTO TABLE order_items
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/payments.csv'
  INTO TABLE payments
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/shipments.csv'
  INTO TABLE shipments
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/returns.csv'
  INTO TABLE `returns`
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/inventory_movements.csv'
  INTO TABLE inventory_movements
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\r\n' IGNORE 1 LINES;

-- Post-load row counts (calendar included for the full picture)
SELECT 'stores' AS t, COUNT(*) AS row_count FROM stores
UNION ALL SELECT 'product_categories', COUNT(*) FROM product_categories
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'promotions', COUNT(*) FROM promotions
UNION ALL SELECT 'calendar', COUNT(*) FROM calendar
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'shipments', COUNT(*) FROM shipments
UNION ALL SELECT 'returns', COUNT(*) FROM `returns`
UNION ALL SELECT 'inventory_movements', COUNT(*) FROM inventory_movements
ORDER BY t;
