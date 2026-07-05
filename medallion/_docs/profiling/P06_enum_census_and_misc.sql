-- TASK-20260704-01 · P06_enum_census_and_misc.sql · 2026-07-04
-- PURPOSE: Cross-check enum censuses vs grounding/schema.md; misc column profiles; revenue backbone (DEF-001/002)

SELECT '--orders.status census--' AS marker;
SELECT status, COUNT(*) c FROM oakhaven.orders GROUP BY status ORDER BY status;

SELECT '--orders.channel census--' AS marker;
SELECT channel, COUNT(*) c FROM oakhaven.orders GROUP BY channel ORDER BY channel;

SELECT '--payments.status census--' AS marker;
SELECT status, COUNT(*) c FROM oakhaven.payments GROUP BY status ORDER BY status;

SELECT '--inventory_movements.movement_type census--' AS marker;
SELECT movement_type, COUNT(*) c FROM oakhaven.inventory_movements GROUP BY movement_type ORDER BY movement_type;

SELECT '--order window--' AS marker;
SELECT MIN(order_ts), MAX(order_ts) FROM oakhaven.orders;

SELECT '--calendar window--' AS marker;
SELECT MIN(date), MAX(date) FROM oakhaven.calendar;

SELECT '--payments card_last4 / method-status crosscheck--' AS marker;
SELECT method, SUM(card_last4 IS NULL) AS null_card4, SUM(card_last4 IS NOT NULL) AS has_card4 FROM oakhaven.payments GROUP BY method ORDER BY method;

SELECT '--payments example rows--' AS marker;
SELECT payment_id, order_id, method, amount, status, card_last4 FROM oakhaven.payments ORDER BY payment_id LIMIT 5;

SELECT '--returns condition_code census--' AS marker;
SELECT condition_code, COUNT(*) c FROM oakhaven.returns GROUP BY condition_code, BINARY condition_code ORDER BY condition_code;

SELECT '--shipments ship_cost zero census--' AS marker;
SELECT COUNT(*) FROM oakhaven.shipments WHERE ship_cost = 0.00;
SELECT shipment_id, order_id, carrier, ship_cost FROM oakhaven.shipments WHERE ship_cost = 0.00 ORDER BY shipment_id LIMIT 3;

SELECT '--promotions description NULL census--' AS marker;
SELECT SUM(description IS NULL) AS null_ct, COUNT(*) AS total FROM oakhaven.promotions;
SELECT promo_id, promo_code, discount_pct, description FROM oakhaven.promotions ORDER BY promo_id LIMIT 3;

SELECT '--promotions promo_code lowercase census--' AS marker;
SELECT COUNT(*) FROM oakhaven.promotions WHERE BINARY promo_code = BINARY LOWER(promo_code) AND promo_code REGEXP '[A-Za-z]';

SELECT '--stores square_feet NULL (WEB) census--' AS marker;
SELECT store_id, store_code, city, state, square_feet FROM oakhaven.stores ORDER BY store_id;

SELECT '--product_categories parent census--' AS marker;
SELECT COUNT(*) AS total, SUM(parent_category_id IS NULL) AS root_ct FROM oakhaven.product_categories;

SELECT '--DEF-002 revenue backbone example: order true total for one order--' AS marker;
SELECT oi.order_id, SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct/100), 2)) AS order_true_total
FROM oakhaven.order_items oi WHERE oi.order_id = 100001 GROUP BY oi.order_id;

SELECT '--DEF-001 revenue backbone example: single line net revenue--' AS marker;
SELECT order_item_id, order_id, product_id, quantity, unit_price, line_discount_pct,
       ROUND(quantity * unit_price * (1 - line_discount_pct/100), 2) AS line_net_revenue
FROM oakhaven.order_items WHERE order_id = 100001 ORDER BY order_item_id;

SELECT '--gross revenue total (DEF-004 scope) sanity number--' AS marker;
SELECT SUM(ROUND(oi.quantity*oi.unit_price*(1-oi.line_discount_pct/100),2)) AS gross_revenue
FROM oakhaven.order_items oi JOIN oakhaven.orders o ON o.order_id=oi.order_id
WHERE o.status IN ('completed','refunded');

SELECT '--FK orphan spot-check: order_items.order_id all resolve--' AS marker;
SELECT COUNT(*) FROM oakhaven.order_items oi LEFT JOIN oakhaven.orders o ON o.order_id=oi.order_id WHERE o.order_id IS NULL;

SELECT '--FK orphan spot-check: returns.order_item_id all resolve--' AS marker;
SELECT COUNT(*) FROM oakhaven.returns r LEFT JOIN oakhaven.order_items oi ON oi.order_item_id=r.order_item_id WHERE oi.order_item_id IS NULL;
