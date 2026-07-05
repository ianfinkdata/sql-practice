-- TASK-20260704-04 · V04_dim_date_window.sql · 2026-07-05
-- PURPOSE: Prove dim_date is constrained to exactly 2019-01-01..2026-06-30 with a complete,
--          unique daily spine (2,738 days).
-- GROUNDING: medallion-spec §Gold rules (dim_date window); RULE-009 (constant window end);
--            RULE-001, RULE-006
-- RUN: Get-Content V04_dim_date_window.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: n_days = 2738 = distinct_keys; min/max = window bounds; is_full_span = 1;
--           distinct_months = 90.

SELECT
  COUNT(*) AS n_days,
  COUNT(DISTINCT date_key) AS distinct_keys,
  MIN(`date`) AS min_date,
  MAX(`date`) AS max_date,
  COUNT(*) = DATEDIFF('2026-06-30', '2019-01-01') + 1 AS is_full_span,
  COUNT(DISTINCT sales_month) AS distinct_months
FROM oakhaven_gold.dim_date;
