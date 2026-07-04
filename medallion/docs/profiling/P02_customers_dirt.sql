-- TASK-20260704-01 · P02_customers_dirt.sql · 2026-07-04
-- PURPOSE: D1-D7 dirt census + example values for customers table
SELECT '--D1 email NULL--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE email IS NULL;
SELECT '--D1 email N/A or none--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE LOWER(TRIM(email)) IN ('n/a','none');
SELECT '--D1 email example N/A--' AS marker;
SELECT customer_id, email FROM oakhaven.customers WHERE LOWER(TRIM(email)) IN ('n/a','none') ORDER BY customer_id LIMIT 3;
SELECT '--D1 email UPPERCASE count--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE email IS NOT NULL AND email = UPPER(email) AND email REGEXP '[A-Z]';
SELECT '--D1 email UPPERCASE example--' AS marker;
SELECT customer_id, email FROM oakhaven.customers WHERE email IS NOT NULL AND email = UPPER(email) AND email REGEXP '[A-Z]' ORDER BY customer_id LIMIT 3;
SELECT '--D1 email trailing space count--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE email IS NOT NULL AND email != TRIM(TRAILING FROM email);
SELECT '--D1 email trailing space example--' AS marker;
SELECT customer_id, CONCAT('[',email,']') FROM oakhaven.customers WHERE email IS NOT NULL AND email != TRIM(TRAILING FROM email) ORDER BY customer_id LIMIT 3;

SELECT '--D2 phone format census--' AS marker;
SELECT
  SUM(phone REGEXP '^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$') AS paren_fmt,
  SUM(phone REGEXP '^[0-9]{3}-[0-9]{3}-[0-9]{4}$') AS dash_fmt,
  SUM(phone REGEXP '^[0-9]{3}\\.[0-9]{3}\\.[0-9]{4}$') AS dot_fmt,
  SUM(phone REGEXP '^\\+1 [0-9]{3} [0-9]{3} [0-9]{4}$') AS plus1_fmt,
  SUM(LOWER(TRIM(phone)) = 'n/a') AS na_txt,
  SUM(phone IS NULL) AS null_ct
FROM oakhaven.customers;
SELECT '--D2 phone examples one per format--' AS marker;
SELECT customer_id, phone FROM oakhaven.customers WHERE phone REGEXP '^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$' ORDER BY customer_id LIMIT 1;
SELECT customer_id, phone FROM oakhaven.customers WHERE phone REGEXP '^[0-9]{3}-[0-9]{3}-[0-9]{4}$' ORDER BY customer_id LIMIT 1;
SELECT customer_id, phone FROM oakhaven.customers WHERE phone REGEXP '^[0-9]{3}\\.[0-9]{3}\\.[0-9]{4}$' ORDER BY customer_id LIMIT 1;
SELECT customer_id, phone FROM oakhaven.customers WHERE phone REGEXP '^\\+1 [0-9]{3} [0-9]{3} [0-9]{4}$' ORDER BY customer_id LIMIT 1;
SELECT customer_id, phone FROM oakhaven.customers WHERE LOWER(TRIM(phone)) = 'n/a' ORDER BY customer_id LIMIT 1;

SELECT '--D3 state full name / abbrev-period census--' AS marker;
SELECT state, COUNT(*) FROM oakhaven.customers WHERE CHAR_LENGTH(TRIM(state)) > 2 GROUP BY state ORDER BY COUNT(*) DESC LIMIT 20;

SELECT '--D4 city dirt census--' AS marker;
SELECT SUM(city != TRIM(city)) AS leading_trailing_space,
       SUM(city = UPPER(city) AND city REGEXP '[A-Z]') AS allcaps,
       SUM(city = LOWER(city) AND city REGEXP '[a-z]') AS lowercase
FROM oakhaven.customers;
SELECT '--D4 city examples--' AS marker;
SELECT customer_id, CONCAT('[',city,']') FROM oakhaven.customers WHERE city != TRIM(city) ORDER BY customer_id LIMIT 2;
SELECT customer_id, city FROM oakhaven.customers WHERE city = UPPER(city) AND city REGEXP '[A-Z]' ORDER BY customer_id LIMIT 2;
SELECT customer_id, city FROM oakhaven.customers WHERE city = LOWER(city) AND city REGEXP '[a-z]' ORDER BY customer_id LIMIT 2;

SELECT '--D5 birth_date census--' AS marker;
SELECT SUM(birth_date IS NULL) AS null_ct,
       SUM(birth_date = '1900-01-01') AS sentinel_ct,
       SUM(birth_date > '2026-06-30') AS future_ct,
       SUM(birth_date IS NOT NULL AND birth_date <> '1900-01-01' AND TIMESTAMPDIFF(YEAR, birth_date, '2026-06-30') > 95) AS age_gt_95
FROM oakhaven.customers;
SELECT '--D5 examples--' AS marker;
SELECT customer_id, birth_date FROM oakhaven.customers WHERE birth_date = '1900-01-01' ORDER BY customer_id LIMIT 2;
SELECT customer_id, birth_date FROM oakhaven.customers WHERE birth_date > '2026-06-30' ORDER BY customer_id LIMIT 2;
SELECT customer_id, birth_date, TIMESTAMPDIFF(YEAR, birth_date, '2026-06-30') AS age FROM oakhaven.customers WHERE birth_date IS NOT NULL AND birth_date <> '1900-01-01' AND TIMESTAMPDIFF(YEAR, birth_date, '2026-06-30') > 95 ORDER BY customer_id LIMIT 2;

SELECT '--D6 loyalty_tier casing census--' AS marker;
SELECT loyalty_tier, COUNT(*) FROM oakhaven.customers GROUP BY loyalty_tier ORDER BY COUNT(*) DESC;

SELECT '--D7 near-dupe range census--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE customer_id BETWEEN 11851 AND 12000;
SELECT '--D7 example dupe pair--' AS marker;
SELECT customer_id, first_name, last_name, phone FROM oakhaven.customers WHERE customer_id IN (11851, 11852) ORDER BY customer_id;

SELECT '--marketing_opt_in flag census--' AS marker;
SELECT marketing_opt_in, COUNT(*) FROM oakhaven.customers GROUP BY marketing_opt_in ORDER BY COUNT(*) DESC;

SELECT '--postal_code 4-digit census--' AS marker;
SELECT COUNT(*) FROM oakhaven.customers WHERE postal_code REGEXP '^[0-9]{4}$';
SELECT customer_id, postal_code FROM oakhaven.customers WHERE postal_code REGEXP '^[0-9]{4}$' ORDER BY customer_id LIMIT 2;
