-- TASK-20260704-03 · V02_def009_boolean_leaks.sql · 2026-07-04
-- PURPOSE: Prove zero unmapped-value NULL leaks for all three DEF-009 boolean columns
--          (bronze columns are NOT NULL, so any silver NULL = an unmapped raw value).
-- GROUNDING: DEF-009 (ELSE NULL tripwire); RULE-007 (unmapped values must trip this query);
--            RULE-001, RULE-012 (literal alias ordered with pinned collation)
-- RUN: Get-Content V02_def009_boolean_leaks.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED (from B03 census): null_leaks = 0 on all three rows;
--   customers.marketing_opt_in: 1s = 3715+1567+1446 = 6728 · 0s = 2926+1177+1169 = 5272 (total 12000)
--   products.discontinued_flag: 1s = 70+130+60 = 260 · 0s = 85+460+45 = 590 (total 850)
--   suppliers.active_flag:      1s = 8+18+5 = 31 · 0s = 4+7+3 = 14 (total 45)

SELECT 'customers.marketing_opt_in' AS bool_column,
       COUNT(*)                          AS total_rows,
       SUM(marketing_opt_in = 1)         AS mapped_1,
       SUM(marketing_opt_in = 0)         AS mapped_0,
       SUM(marketing_opt_in IS NULL)     AS null_leaks
FROM oakhaven_silver.customers
UNION ALL
SELECT 'products.discontinued_flag',
       COUNT(*),
       SUM(discontinued_flag = 1),
       SUM(discontinued_flag = 0),
       SUM(discontinued_flag IS NULL)
FROM oakhaven_silver.products
UNION ALL
SELECT 'suppliers.active_flag',
       COUNT(*),
       SUM(active_flag = 1),
       SUM(active_flag = 0),
       SUM(active_flag IS NULL)
FROM oakhaven_silver.suppliers
ORDER BY bool_column COLLATE utf8mb4_bin;
