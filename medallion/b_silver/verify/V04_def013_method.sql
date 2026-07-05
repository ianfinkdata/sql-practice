-- TASK-20260704-03 · V04_def013_method.sql · 2026-07-04
-- PURPOSE: Prove DEF-013 maps every bronze payment method — post-clean distinct set is exactly
--          {amex, cash, gift, mastercard, visa} with ZERO NULLs and the v1.1 mapped totals.
-- GROUNDING: DEF-013 v1.1 (mapping + mapped totals in its caveat); RULE-007 (tripwire),
--            RULE-011 (census under binary collation), RULE-001/012 (deterministic pinned ORDER BY)
-- RUN: Get-Content V04_def013_method.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED (DEF-013 v1.1 caveat): amex 6143 · cash 11203 · gift 3087 · mastercard 19068 ·
--   visa 27162 (sum 66663 = full payments row count); method_null_leaks = 0.

-- Result set 1: post-clean census (a NULL group appearing here = unmapped-value leak)
SELECT method COLLATE utf8mb4_bin AS method_clean, COUNT(*) AS n
FROM oakhaven_silver.payments
GROUP BY method_clean
ORDER BY method_clean;

-- Result set 2: explicit leak count (must be 0 — bronze method is NOT NULL)
SELECT COUNT(*) AS method_null_leaks
FROM oakhaven_silver.payments
WHERE method IS NULL;
