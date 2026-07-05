-- TASK-20260704-04 · G01_dim_date.sql · 2026-07-05
-- PURPOSE: Gold dim_date — the silver calendar spine constrained to the business window
--          2019-01-01..2026-06-30 (medallion-spec §Gold rules; window end constant per RULE-009).
-- GROUNDING: medallion-spec §Gold rules (dim_date does the window constraint, silver stays full width);
--            RULE-009 (window end is the constant '2026-06-30', never CURDATE())
-- RUN: Get-Content G01_dim_date.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * Expected span: 2,738 days (2019-01-01..2026-06-30 inclusive) — verified in V04.
-- * sales_month is a derived CHAR(7) '%Y-%m' key matching the month grain used by every
--   trend mart (numeric format string — locale-independent, deterministic).

CREATE OR REPLACE VIEW oakhaven_gold.dim_date AS
SELECT
  c.date_key,
  c.`date`,
  DATE_FORMAT(c.`date`, '%Y-%m') AS sales_month,        -- month key joining to the trend marts
  c.`year`,
  c.month_num,
  c.`month`,
  c.`quarter`,
  c.week_day,
  c.week_day_name,
  c.is_weekend,
  c.week_start,
  c.iso_week_start
FROM oakhaven_silver.calendar c
WHERE c.`date` BETWEEN '2019-01-01' AND '2026-06-30';   -- RULE-009 window constants
