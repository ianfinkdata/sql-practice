-- TASK-20260704-01 · P02b_customers_city_fix.sql · 2026-07-04
-- PURPOSE: Redo D4 city casing census using BINARY comparison (ci collation made first attempt wrong)
SELECT '--D4 city dirt census (binary-safe)--' AS marker;
SELECT SUM(city != TRIM(city)) AS leading_trailing_space,
       SUM(BINARY city = BINARY UPPER(city) AND city REGEXP '[A-Za-z]') AS allcaps,
       SUM(BINARY city = BINARY LOWER(city) AND city REGEXP '[A-Za-z]') AS lowercase
FROM oakhaven.customers;
SELECT '--D4 city examples--' AS marker;
SELECT customer_id, CONCAT('[',city,']') FROM oakhaven.customers WHERE city != TRIM(city) ORDER BY customer_id LIMIT 2;
SELECT customer_id, city FROM oakhaven.customers WHERE BINARY city = BINARY UPPER(city) AND city REGEXP '[A-Za-z]' ORDER BY customer_id LIMIT 2;
SELECT customer_id, city FROM oakhaven.customers WHERE BINARY city = BINARY LOWER(city) AND city REGEXP '[A-Za-z]' ORDER BY customer_id LIMIT 2;

SELECT '--D1 email UPPERCASE (binary-safe)--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE email IS NOT NULL AND BINARY email = BINARY UPPER(email) AND email REGEXP '[A-Za-z]';
SELECT customer_id, email FROM oakhaven.customers WHERE email IS NOT NULL AND BINARY email = BINARY UPPER(email) AND email REGEXP '[A-Za-z]' ORDER BY customer_id LIMIT 2;

SELECT '--D6 loyalty_tier casing (binary-safe) wrong-casing count--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE BINARY loyalty_tier NOT IN (BINARY 'Basic', BINARY 'Silver', BINARY 'Gold', BINARY 'Platinum');
