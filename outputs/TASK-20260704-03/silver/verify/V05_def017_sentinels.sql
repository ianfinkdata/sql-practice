-- TASK-20260704-03 · V05_def017_sentinels.sql · 2026-07-04
-- PURPOSE: Prove DEF-017 sentinel flags match the bronze B04 census exactly, and that every
--          flagged sentinel value was actually NULLed (and age outliers were KEPT, not NULLed).
-- GROUNDING: DEF-017 (sentinel policy + age-outlier caveat); RULE-009 (window end constant
--            '2026-06-30'); RULE-001, RULE-012 (literal alias ordered with pinned collation)
-- RUN: Get-Content V05_def017_sentinels.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED (B04 census): flag counts 1=9 (D13), 2=2 (D21), 3=60 (D5), 4=24 (D5), 5=36 (D5);
--   all integrity rows (6-9) = 0.

SELECT '1 products.is_weight_sentinel'            AS check_name, SUM(is_weight_sentinel)      AS n FROM oakhaven_silver.products
UNION ALL
SELECT '2 suppliers.is_lead_time_sentinel',                      SUM(is_lead_time_sentinel)         FROM oakhaven_silver.suppliers
UNION ALL
SELECT '3 customers.is_birth_date_sentinel',                     SUM(is_birth_date_sentinel)        FROM oakhaven_silver.customers
UNION ALL
SELECT '4 customers.is_birth_date_future',                       SUM(is_birth_date_future)          FROM oakhaven_silver.customers
UNION ALL
SELECT '5 customers.is_age_outlier',                             SUM(is_age_outlier)                FROM oakhaven_silver.customers
UNION ALL
-- integrity: flagged sentinel rows must be NULLed in the cleaned column (expect 0)
SELECT '6 weight flagged but not NULLed',                        SUM(is_weight_sentinel = 1 AND weight_kg IS NOT NULL)     FROM oakhaven_silver.products
UNION ALL
SELECT '7 lead_time flagged but not NULLed',                     SUM(is_lead_time_sentinel = 1 AND lead_time_days IS NOT NULL) FROM oakhaven_silver.suppliers
UNION ALL
SELECT '8 birth_date flagged but not NULLed',                    SUM((is_birth_date_sentinel = 1 OR is_birth_date_future = 1) AND birth_date IS NOT NULL) FROM oakhaven_silver.customers
UNION ALL
-- integrity: age outliers are plausible-not-impossible — KEPT (expect 0 NULLed among flagged)
SELECT '9 age outlier wrongly NULLed',                           SUM(is_age_outlier = 1 AND birth_date IS NULL)            FROM oakhaven_silver.customers
ORDER BY check_name COLLATE utf8mb4_bin;
