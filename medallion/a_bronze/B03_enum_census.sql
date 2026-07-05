-- TASK-20260704-02 · B03_enum_census.sql · 2026-07-04
-- PURPOSE: Complete distinct-value censuses (no LIMIT) for the 12 enum/status/flag columns that feed
--          the DEF-012 (state) and DEF-013 (payment method) mapping tables, plus other controlled-vocab
--          columns needed to scope DEF-009/014 work later.
-- GROUNDING: DEF-012, DEF-013 (mapping tables pending this census); DEF-009 (boolean normalization targets)
-- RUN: Get-Content B03_enum_census.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- NOTE: default schema collation (utf8mb4_0900_ai_ci) is CASE-INSENSITIVE, so a plain GROUP BY on these
--       columns silently collapses casing variants (e.g. 'Visa'/'VISA'/'visa' -> one row) and would
--       understate the spelling variety the mapping tables must cover. Every census below groups/orders
--       on `col COLLATE utf8mb4_0900_bin` to force byte-exact distinctness. Verified empirically: default
--       GROUP BY on payments.method returns 7 rows; COLLATE ..._bin returns the true 10 (Visa/VISA/visa,
--       Mastercard/'Master Card'/MC, AMEX, cash/CASH, GIFT) matching CONTRACT D12 ("≥8 distinct spellings").
-- 12 result sets follow, in brief order.

-- 1. orders.status
SELECT status COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.orders
GROUP BY status COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 2. orders.channel
SELECT channel COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.orders
GROUP BY channel COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 3. inventory_movements.movement_type
SELECT movement_type COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.inventory_movements
GROUP BY movement_type COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 4. payments.status
SELECT status COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.payments
GROUP BY status COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 5. payments.method
SELECT method COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.payments
GROUP BY method COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 6. customers.loyalty_tier
SELECT loyalty_tier COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.customers
GROUP BY loyalty_tier COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 7. customers.state
SELECT state COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.customers
GROUP BY state COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 8. products.discontinued_flag
SELECT discontinued_flag COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.products
GROUP BY discontinued_flag COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 9. suppliers.active_flag
SELECT active_flag COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.suppliers
GROUP BY active_flag COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 10. suppliers.country
SELECT country COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.suppliers
GROUP BY country COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 11. customers.marketing_opt_in
SELECT marketing_opt_in COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.customers
GROUP BY marketing_opt_in COLLATE utf8mb4_0900_bin
ORDER BY value;

-- 12. shipments.carrier
SELECT carrier COLLATE utf8mb4_0900_bin AS value, COUNT(*) AS n
FROM oakhaven.shipments
GROUP BY carrier COLLATE utf8mb4_0900_bin
ORDER BY value;
