-- TASK-20260704-02 · B04_dirt_census.sql · 2026-07-04
-- PURPOSE: One probe per DATA_CONTRACT.md §4 dirt-quota registry row (D1-D25), proving presence
--          (count > 0) and giving a magnitude to sanity-check against the contract's quota column.
-- GROUNDING: oakhaven/DATA_CONTRACT.md §4 (D1-D25 registry, source of the patterns below);
--            DEF-011 (D10 partition mirrors the delivered-date parse rule's own format buckets);
--            DEF-017 (D5, D13, D21 sentinel patterns), DEF-009 target columns (D6/D14 casing/flag chaos)
-- RUN: Get-Content B04_dirt_census.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- NOTE: 25 result sets follow, one per D-id, in order D1..D25. Where a D-row's sub-patterns sum to
--       100% of the column (D2, D8, D10, D23) the probe is an exhaustive CASE/GROUP BY partition
--       (rows sum back to the table's row count -- self-checking). Where sub-patterns are independent/
--       non-exhaustive (e.g. D1, D5), each pattern is counted by its own mutually-exclusive WHERE clause.
--       Casing checks use BINARY(...) because the schema collation (utf8mb4_0900_ai_ci) is case-insensitive
--       and would otherwise hide casing variants from a plain comparison (see B03 header note).

-- D1: customers.email — NULL / 'N/A' or 'none' / UPPERCASE / leading-or-trailing space
SELECT 'D1' AS dirt_id, 'NULL' AS pattern, COUNT(*) AS n FROM oakhaven.customers WHERE email IS NULL
UNION ALL
SELECT 'D1', 'N/A or none (any case)', COUNT(*) FROM oakhaven.customers
  WHERE email IS NOT NULL AND LOWER(TRIM(email)) IN ('n/a','none')
UNION ALL
SELECT 'D1', 'UPPERCASE', COUNT(*) FROM oakhaven.customers
  WHERE email IS NOT NULL AND LOWER(TRIM(email)) NOT IN ('n/a','none')
    AND BINARY(email) = BINARY(UPPER(email)) AND email REGEXP '[A-Za-z]'
UNION ALL
SELECT 'D1', 'leading/trailing space', COUNT(*) FROM oakhaven.customers
  WHERE email IS NOT NULL AND email <> TRIM(email)
ORDER BY pattern;

-- D2: customers.phone — exhaustive partition (quotas sum to 100%)
SELECT 'D2' AS dirt_id,
  CASE
    WHEN phone IS NULL THEN '1-NULL'
    WHEN LOWER(TRIM(phone)) = 'n/a' THEN '2-N/A'
    WHEN phone REGEXP '^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$' THEN '3-(206) 555-0143 style'
    WHEN phone REGEXP '^[0-9]{3}-[0-9]{3}-[0-9]{4}$' THEN '4-206-555-0143 style'
    WHEN phone REGEXP '^[0-9]{3}\\.[0-9]{3}\\.[0-9]{4}$' THEN '5-206.555.0143 style'
    WHEN phone REGEXP '^\\+1 [0-9]{3} [0-9]{3} [0-9]{4}$' THEN '6-+1 206 555 0143 style'
    ELSE '7-other/unrecognized'
  END AS pattern,
  COUNT(*) AS n
FROM oakhaven.customers
GROUP BY pattern
ORDER BY pattern;

-- D3: customers.state — full state name / abbrev-with-period / (remainder: clean 2-letter code)
SELECT 'D3' AS dirt_id,
  CASE
    WHEN CHAR_LENGTH(TRIM(state)) = 2 THEN '3-clean 2-letter code'
    WHEN RIGHT(TRIM(state), 1) = '.' THEN '2-abbrev-period (e.g. Wash.)'
    ELSE '1-full state name (e.g. Washington)'
  END AS pattern,
  COUNT(*) AS n
FROM oakhaven.customers
GROUP BY pattern
ORDER BY pattern;

-- D4: customers.city — leading/trailing space / ALLCAPS / lowercase
SELECT 'D4' AS dirt_id, 'leading/trailing space' AS pattern, COUNT(*) AS n FROM oakhaven.customers
  WHERE city <> TRIM(city)
UNION ALL
SELECT 'D4', 'ALLCAPS', COUNT(*) FROM oakhaven.customers
  WHERE BINARY(city) = BINARY(UPPER(city)) AND city REGEXP '[A-Za-z]'
UNION ALL
SELECT 'D4', 'lowercase', COUNT(*) FROM oakhaven.customers
  WHERE BINARY(city) = BINARY(LOWER(city)) AND city REGEXP '[A-Za-z]'
ORDER BY pattern;

-- D5: customers.birth_date — NULL / 1900-01-01 sentinel / future date / age > 95 (mutually exclusive by construction)
SELECT 'D5' AS dirt_id, 'NULL' AS pattern, COUNT(*) AS n FROM oakhaven.customers WHERE birth_date IS NULL
UNION ALL
SELECT 'D5', '1900-01-01 sentinel', COUNT(*) FROM oakhaven.customers WHERE birth_date = '1900-01-01'
UNION ALL
SELECT 'D5', 'future date (> 2026-06-30)', COUNT(*) FROM oakhaven.customers
  WHERE birth_date IS NOT NULL AND birth_date <> '1900-01-01' AND birth_date > '2026-06-30'
UNION ALL
SELECT 'D5', 'age > 95 as of 2026-06-30', COUNT(*) FROM oakhaven.customers
  WHERE birth_date IS NOT NULL AND birth_date <> '1900-01-01' AND birth_date <= '2026-06-30'
    AND TIMESTAMPDIFF(YEAR, birth_date, '2026-06-30') > 95
ORDER BY pattern;

-- D6: customers.loyalty_tier — wrong casing vs the 4 canonical exact strings
SELECT 'D6' AS dirt_id,
  CASE WHEN loyalty_tier COLLATE utf8mb4_0900_bin IN ('Basic','Silver','Gold','Platinum')
       THEN '1-canonical casing' ELSE '2-wrong casing' END AS pattern,
  COUNT(*) AS n
FROM oakhaven.customers
GROUP BY pattern
ORDER BY pattern;

-- D7: customers near-dupes — ids 11851-12000 fuzzy-copy 150 originals (expect exactly 150)
SELECT 'D7' AS dirt_id, 'customer_id BETWEEN 11851 AND 12000' AS pattern, COUNT(*) AS n
FROM oakhaven.customers WHERE customer_id BETWEEN 11851 AND 12000
ORDER BY pattern;

-- D8: orders.order_total_text — exhaustive partition (quotas sum to 100%)
-- NOTE: comma presence alone is confounded with order MAGNITUDE (a total under 1000 never needs a
--       comma regardless of formatting variant). A naive "LIKE '%,%'" split produced two ~47% buckets
--       instead of the contract's 90/5 shape. Fixed by only treating "missing comma" as dirty when the
--       true numeric total is >= 1000 and no comma is present (verified this session: 92.5/2.6/2.9/1.9%
--       vs. the contract's stated 90/5/3/2%).
SELECT 'D8' AS dirt_id,
  CASE
    WHEN order_total_text <> TRIM(order_total_text) THEN '4-leading/trailing space'
    WHEN order_total_text NOT LIKE '$%' THEN '3-no $ sign'
    WHEN CAST(REPLACE(REPLACE(TRIM(order_total_text), '$', ''), ',', '') AS DECIMAL(10,2)) >= 1000
         AND order_total_text NOT LIKE '%,%' THEN '2-missing comma (total >= 1000, no comma)'
    ELSE '1-standard formatting (comma present when magnitude requires it)'
  END AS pattern,
  COUNT(*) AS n
FROM oakhaven.orders
GROUP BY pattern
ORDER BY pattern;

-- D9: orders.order_notes — junk/non-NULL presence (quota: 20% non-NULL)
SELECT 'D9' AS dirt_id, 'non-NULL order_notes' AS pattern, COUNT(*) AS n
FROM oakhaven.orders WHERE order_notes IS NOT NULL
ORDER BY pattern;

-- D10: shipments.delivered_date_raw — exhaustive partition, mirrors DEF-011's own format buckets
SELECT 'D10' AS dirt_id,
  CASE
    WHEN delivered_date_raw IS NULL THEN '1-NULL'
    WHEN delivered_date_raw = 'PENDING' THEN '2-PENDING'
    WHEN delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN '3-YYYY-MM-DD'
    WHEN delivered_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN '4-MM/DD/YYYY'
    ELSE '5-Mon D, YYYY'
  END AS pattern,
  COUNT(*) AS n
FROM oakhaven.shipments
GROUP BY pattern
ORDER BY pattern;

-- D11: shipments.carrier — casing variants vs canonical {UPS, FedEx, USPS, OnTrac}
SELECT 'D11' AS dirt_id,
  CASE WHEN carrier COLLATE utf8mb4_0900_bin IN ('UPS','FedEx','USPS','OnTrac')
       THEN '1-canonical casing' ELSE '2-casing variant' END AS pattern,
  COUNT(*) AS n
FROM oakhaven.shipments
GROUP BY pattern
ORDER BY pattern;

-- D12: payments.method — distinct spelling count (contract: >= 8 distinct spellings); full breakdown in B03
SELECT 'D12' AS dirt_id, 'distinct spellings (BINARY-exact)' AS pattern,
  COUNT(DISTINCT method COLLATE utf8mb4_0900_bin) AS n
FROM oakhaven.payments
ORDER BY pattern;

-- D13: products.weight_kg — NULL / -999 sentinel
SELECT 'D13' AS dirt_id, 'NULL' AS pattern, COUNT(*) AS n FROM oakhaven.products WHERE weight_kg IS NULL
UNION ALL
SELECT 'D13', '-999 sentinel', COUNT(*) FROM oakhaven.products WHERE weight_kg = -999
ORDER BY pattern;

-- D14: products.discontinued_flag — distinct value count (contract: >= 5 distinct values); full breakdown in B03
SELECT 'D14' AS dirt_id, 'distinct values (BINARY-exact)' AS pattern,
  COUNT(DISTINCT discontinued_flag COLLATE utf8mb4_0900_bin) AS n
FROM oakhaven.products
ORDER BY pattern;

-- D15: products.product_name — double space / trailing space / ALLCAPS
SELECT 'D15' AS dirt_id, 'double space' AS pattern, COUNT(*) AS n FROM oakhaven.products
  WHERE product_name LIKE '%  %'
UNION ALL
SELECT 'D15', 'trailing space', COUNT(*) FROM oakhaven.products
  WHERE product_name <> TRIM(TRAILING FROM product_name)
UNION ALL
SELECT 'D15', 'ALLCAPS', COUNT(*) FROM oakhaven.products
  WHERE BINARY(product_name) = BINARY(UPPER(product_name)) AND product_name REGEXP '[A-Za-z]'
ORDER BY pattern;

-- D16: products.list_price — below unit_cost (contract fn anomaly, ~2%)
SELECT 'D16' AS dirt_id, 'list_price < unit_cost' AS pattern, COUNT(*) AS n
FROM oakhaven.products WHERE list_price < unit_cost
ORDER BY pattern;

-- D17: order_items.unit_price — 0.01 penny-pricing error (0.2%)
SELECT 'D17' AS dirt_id, 'unit_price = 0.01' AS pattern, COUNT(*) AS n
FROM oakhaven.order_items WHERE unit_price = 0.01
ORDER BY pattern;

-- D18: employees.hourly_wage — typo outlier > 150.00 (contract: ~1%, >= 2 rows)
SELECT 'D18' AS dirt_id, 'hourly_wage > 150.00' AS pattern, COUNT(*) AS n
FROM oakhaven.employees WHERE hourly_wage > 150.00
ORDER BY pattern;

-- D19: employees.job_title — casing variants vs the 7 canonical titles
SELECT 'D19' AS dirt_id,
  CASE WHEN job_title COLLATE utf8mb4_0900_bin IN
    ('Store Manager','Assistant Manager','Sales Associate','Cashier','Web Support','Buyer','Warehouse Lead')
    THEN '1-canonical casing' ELSE '2-casing variant' END AS pattern,
  COUNT(*) AS n
FROM oakhaven.employees
GROUP BY pattern
ORDER BY pattern;

-- D20: suppliers.country — distinct USA-coding count (contract: >= 3 codings: US/USA/United States).
--      NOTE: unlike D12/D14 (pure spelling variants of one concept), suppliers.country legitimately
--      contains other real countries too (Canada, China, Germany, ...); the probe is scoped to the
--      USA-referring values only so it measures the intended coding-mix dirt, not real geographic
--      diversity. Full breakdown of every country value is in B03.
SELECT 'D20' AS dirt_id, 'distinct USA codings (US/USA/United States, BINARY-exact)' AS pattern,
  COUNT(DISTINCT country COLLATE utf8mb4_0900_bin) AS n
FROM oakhaven.suppliers
WHERE country COLLATE utf8mb4_0900_bin IN ('US', 'USA', 'United States')
ORDER BY pattern;

-- D21: suppliers.lead_time_days — -999 sentinel (expect exactly 2 rows)
SELECT 'D21' AS dirt_id, 'lead_time_days = -999' AS pattern, COUNT(*) AS n
FROM oakhaven.suppliers WHERE lead_time_days = -999
ORDER BY pattern;

-- D22: returns.reason — NULL presence (contract quota specifically names NULL: 6%)
SELECT 'D22' AS dirt_id, 'NULL' AS pattern, COUNT(*) AS n
FROM oakhaven.returns WHERE reason IS NULL
ORDER BY pattern;

-- D23: inventory_movements.reference — exhaustive partition (MIGRATION / junk-or-PO-id / NULL sum to 100%)
SELECT 'D23' AS dirt_id,
  CASE
    WHEN reference IS NULL THEN '3-NULL'
    WHEN reference = 'MIGRATION' THEN '1-MIGRATION'
    ELSE '2-PO-style id or junk (non-NULL, non-MIGRATION)'
  END AS pattern,
  COUNT(*) AS n
FROM oakhaven.inventory_movements
GROUP BY pattern
ORDER BY pattern;

-- D24: orders vs customers — order_ts predates signup_date (migration artifact; assert > 0)
SELECT 'D24' AS dirt_id, 'DATE(order_ts) < signup_date' AS pattern, COUNT(*) AS n
FROM oakhaven.orders o JOIN oakhaven.customers c ON c.customer_id = o.customer_id
WHERE DATE(o.order_ts) < c.signup_date
ORDER BY pattern;

-- D25: shipments.tracking_number — duplicated value pairs (contract: ~1%); counts all rows sharing a dup value
SELECT 'D25' AS dirt_id, 'rows sharing a duplicated tracking_number' AS pattern, COUNT(*) AS n
FROM oakhaven.shipments s
JOIN (
  SELECT tracking_number FROM oakhaven.shipments GROUP BY tracking_number HAVING COUNT(*) > 1
) d ON d.tracking_number = s.tracking_number
ORDER BY pattern;
