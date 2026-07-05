-- TASK-20260704-01 · P03_products_suppliers_employees_dirt.sql · 2026-07-04
-- PURPOSE: D13-D21 dirt census + examples for products, suppliers, employees

SELECT '--D13 weight_kg NULL/-999 census--' AS marker;
SELECT SUM(weight_kg IS NULL) AS null_ct, SUM(weight_kg = -999) AS sentinel_ct FROM oakhaven.products;
SELECT product_id, sku, weight_kg FROM oakhaven.products WHERE weight_kg = -999 ORDER BY product_id LIMIT 3;

SELECT '--D14 discontinued_flag distinct census--' AS marker;
SELECT discontinued_flag, COUNT(*) FROM oakhaven.products GROUP BY discontinued_flag ORDER BY COUNT(*) DESC;

SELECT '--D15 product_name dirt census (binary-safe)--' AS marker;
SELECT SUM(product_name LIKE '%  %') AS double_space,
       SUM(BINARY product_name != BINARY TRIM(product_name)) AS trailing_space,
       SUM(BINARY product_name = BINARY UPPER(product_name) AND product_name REGEXP '[A-Za-z]') AS allcaps
FROM oakhaven.products;
SELECT product_id, CONCAT('[',product_name,']') FROM oakhaven.products WHERE product_name LIKE '%  %' ORDER BY product_id LIMIT 2;
SELECT product_id, product_name FROM oakhaven.products WHERE BINARY product_name = BINARY UPPER(product_name) AND product_name REGEXP '[A-Za-z]' ORDER BY product_id LIMIT 2;

SELECT '--D16 list_price below unit_cost census--' AS marker;
SELECT COUNT(*) FROM oakhaven.products WHERE list_price < unit_cost;
SELECT product_id, sku, unit_cost, list_price FROM oakhaven.products WHERE list_price < unit_cost ORDER BY product_id LIMIT 3;

SELECT '--sku format census--' AS marker;
SELECT SUM(sku LIKE 'OAK-%') AS oak_fmt, SUM(sku LIKE 'SKU%') AS legacy_fmt FROM oakhaven.products;
SELECT product_id, sku FROM oakhaven.products WHERE sku LIKE 'SKU%' ORDER BY product_id LIMIT 2;

SELECT '--color casing census--' AS marker;
SELECT COUNT(DISTINCT color) FROM oakhaven.products WHERE color IS NOT NULL;
SELECT color, COUNT(*) c FROM oakhaven.products WHERE color IS NOT NULL GROUP BY color, BINARY color ORDER BY color LIMIT 10;

SELECT '--D20 suppliers.country coding census--' AS marker;
SELECT country, COUNT(*) FROM oakhaven.suppliers GROUP BY country ORDER BY COUNT(*) DESC;

SELECT '--D21 suppliers.lead_time_days sentinel census--' AS marker;
SELECT COUNT(*) FROM oakhaven.suppliers WHERE lead_time_days = -999;
SELECT supplier_id, supplier_name, lead_time_days FROM oakhaven.suppliers WHERE lead_time_days = -999 ORDER BY supplier_id;

SELECT '--suppliers.active_flag census--' AS marker;
SELECT active_flag, COUNT(*) FROM oakhaven.suppliers GROUP BY active_flag ORDER BY COUNT(*) DESC;

SELECT '--suppliers phone/email dirt example--' AS marker;
SELECT supplier_id, supplier_name, phone, contact_email FROM oakhaven.suppliers ORDER BY supplier_id LIMIT 5;

SELECT '--suppliers near-dup name pair--' AS marker;
SELECT supplier_id, supplier_name FROM oakhaven.suppliers ORDER BY supplier_name LIMIT 50;

SELECT '--D18 employees.hourly_wage outlier census--' AS marker;
SELECT COUNT(*) FROM oakhaven.employees WHERE hourly_wage > 150.00;
SELECT employee_id, job_title, hourly_wage FROM oakhaven.employees WHERE hourly_wage > 150.00 ORDER BY employee_id;

SELECT '--D19 employees.job_title casing census--' AS marker;
SELECT job_title, COUNT(*) c FROM oakhaven.employees GROUP BY job_title, BINARY job_title ORDER BY job_title LIMIT 30;

SELECT '--employees rehired census (same person two ids)--' AS marker;
SELECT first_name, last_name, COUNT(*) c FROM oakhaven.employees GROUP BY first_name, last_name HAVING COUNT(*) > 1 ORDER BY first_name LIMIT 10;

SELECT '--employees termination_date census--' AS marker;
SELECT SUM(termination_date IS NOT NULL) AS terminated_ct, COUNT(*) AS total FROM oakhaven.employees;

SELECT '--employees work_email dirt example--' AS marker;
SELECT employee_id, first_name, last_name, work_email FROM oakhaven.employees ORDER BY employee_id LIMIT 5;
