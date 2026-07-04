-- TASK-20260704-01 · P04_orders_payments_shipments_dirt.sql · 2026-07-04
-- PURPOSE: D8-D12, D17, D22-D25 dirt census + planted anomalies

SELECT '--D8 order_total_text format census--' AS marker;
SELECT
  SUM(order_total_text REGEXP '^\\$[0-9]{1,3}(,[0-9]{3})*\\.[0-9]{2}$') AS dollar_comma_fmt,
  SUM(order_total_text REGEXP '^\\$[0-9]+\\.[0-9]{2}$') AS dollar_nocomma_fmt,
  SUM(order_total_text REGEXP '^[0-9]+\\.[0-9]{2}$') AS no_dollar_fmt,
  SUM(order_total_text REGEXP '^ ') AS leading_space_fmt
FROM oakhaven.orders;
SELECT order_id, order_total_text FROM oakhaven.orders WHERE order_total_text REGEXP '^\\$[0-9]{1,3},[0-9]{3}\\.[0-9]{2}$' ORDER BY order_id LIMIT 1;
SELECT order_id, order_total_text FROM oakhaven.orders WHERE order_total_text NOT LIKE '$%' ORDER BY order_id LIMIT 2;
SELECT order_id, CONCAT('[',order_total_text,']') FROM oakhaven.orders WHERE order_total_text REGEXP '^ ' ORDER BY order_id LIMIT 2;

SELECT '--D9 order_notes non-NULL census--' AS marker;
SELECT SUM(order_notes IS NOT NULL) AS non_null_ct, COUNT(*) AS total FROM oakhaven.orders;
SELECT order_id, order_notes FROM oakhaven.orders WHERE order_notes IS NOT NULL ORDER BY order_id LIMIT 5;

SELECT '--D10 delivered_date_raw format census--' AS marker;
SELECT
  SUM(delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS iso_fmt,
  SUM(delivered_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$') AS us_slash_fmt,
  SUM(delivered_date_raw REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$') AS mon_d_yyyy_fmt,
  SUM(delivered_date_raw = 'PENDING') AS pending_ct,
  SUM(delivered_date_raw IS NULL) AS null_ct
FROM oakhaven.shipments;
SELECT shipment_id, delivered_date_raw FROM oakhaven.shipments WHERE delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ORDER BY shipment_id LIMIT 1;
SELECT shipment_id, delivered_date_raw FROM oakhaven.shipments WHERE delivered_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' ORDER BY shipment_id LIMIT 1;
SELECT shipment_id, delivered_date_raw FROM oakhaven.shipments WHERE delivered_date_raw REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$' ORDER BY shipment_id LIMIT 1;
SELECT shipment_id, delivered_date_raw FROM oakhaven.shipments WHERE delivered_date_raw = 'PENDING' ORDER BY shipment_id LIMIT 1;

SELECT '--D11 carrier casing census--' AS marker;
SELECT carrier, COUNT(*) c FROM oakhaven.shipments GROUP BY carrier, BINARY carrier ORDER BY carrier;

SELECT '--D12 payments.method spelling census--' AS marker;
SELECT method, COUNT(*) c FROM oakhaven.payments GROUP BY method, BINARY method ORDER BY method;

SELECT '--D17 order_items unit_price penny census--' AS marker;
SELECT COUNT(*) FROM oakhaven.order_items WHERE unit_price = 0.01;
SELECT order_item_id, order_id, product_id, unit_price FROM oakhaven.order_items WHERE unit_price = 0.01 ORDER BY order_item_id LIMIT 3;

SELECT '--D22 returns.reason census--' AS marker;
SELECT SUM(reason IS NULL) AS null_ct, COUNT(*) AS total FROM oakhaven.returns;
SELECT reason, COUNT(*) c FROM oakhaven.returns WHERE reason IS NOT NULL GROUP BY reason, BINARY reason ORDER BY c DESC LIMIT 15;

SELECT '--D23 inventory_movements.reference census--' AS marker;
SELECT SUM(reference = 'MIGRATION') AS migration_ct,
       SUM(reference IS NULL) AS null_ct,
       COUNT(*) AS total
FROM oakhaven.inventory_movements;
SELECT movement_id, reference FROM oakhaven.inventory_movements WHERE reference = 'MIGRATION' ORDER BY movement_id LIMIT 2;
SELECT DISTINCT reference FROM oakhaven.inventory_movements WHERE reference IS NOT NULL AND reference != 'MIGRATION' ORDER BY reference LIMIT 15;

SELECT '--D25 shipments.tracking_number duplicate census--' AS marker;
SELECT COUNT(*) FROM (
  SELECT tracking_number FROM oakhaven.shipments GROUP BY tracking_number HAVING COUNT(*) > 1
) d;
SELECT tracking_number, COUNT(*) c FROM oakhaven.shipments GROUP BY tracking_number HAVING COUNT(*) > 1 ORDER BY tracking_number LIMIT 3;

SELECT '--D24 orders before signup_date (planted anomaly) census--' AS marker;
SELECT COUNT(*) FROM oakhaven.orders o JOIN oakhaven.customers c ON c.customer_id = o.customer_id WHERE DATE(o.order_ts) < c.signup_date;
SELECT o.order_id, o.order_ts, c.customer_id, c.signup_date FROM oakhaven.orders o JOIN oakhaven.customers c ON c.customer_id = o.customer_id WHERE DATE(o.order_ts) < c.signup_date ORDER BY o.order_id LIMIT 3;

SELECT '--movements before product intro_date (planted anomaly) census--' AS marker;
SELECT COUNT(*) FROM oakhaven.inventory_movements m JOIN oakhaven.products p ON p.product_id = m.product_id WHERE DATE(m.movement_ts) < p.intro_date;
SELECT m.movement_id, m.movement_ts, m.product_id, p.intro_date FROM oakhaven.inventory_movements m JOIN oakhaven.products p ON p.product_id = m.product_id WHERE DATE(m.movement_ts) < p.intro_date ORDER BY m.movement_id LIMIT 3;

SELECT '--orphan transfer_out (planted anomaly) census--' AS marker;
-- orphan = a transfer_out with no matching transfer_in for same product/store/abs(quantity) pairing is complex;
-- use simple heuristic per contract: transfer_out rows with no same-day transfer_in row for same product+store
SELECT COUNT(*) AS transfer_out_total FROM oakhaven.inventory_movements WHERE movement_type = 'transfer_out';
SELECT COUNT(*) AS transfer_in_total FROM oakhaven.inventory_movements WHERE movement_type = 'transfer_in';

SELECT '--penny-price line pct check vs order_items total--' AS marker;
SELECT COUNT(*) AS total_lines FROM oakhaven.order_items;

SELECT '--below-cost list price pct check vs products total--' AS marker;
SELECT COUNT(*) AS total_products FROM oakhaven.products;
