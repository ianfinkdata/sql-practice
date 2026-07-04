-- TASK-20260704-03 · S09_employees.sql · 2026-07-04
-- PURPOSE: Silver employees — DEF-015 work_email normalization; everything else structural
--          passthrough (job_title D19 and hourly_wage D18 have no cleaning DEF).
-- GROUNDING: DEF-015 (work_email); RULE-005 (grain preserved), RULE-007 (job_title casing D19
--            and hourly_wage outliers D18 have no DEF — raw passthrough, discoverable dirt)
-- RUN: Get-Content S09_employees.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * hourly_wage typo outliers (D18, 3 rows > 150.00) stay visible — no DEF authorizes a fix
--   or a flag (RULE-007); they are discoverable dirt for reports.
-- * The 6 "rehired" duplicate-person pairs are legitimate distinct employee_id rows —
--   NOT near-dupes, no resolution applies (data dictionary §2).

CREATE OR REPLACE VIEW oakhaven_silver.employees AS
SELECT
  e.employee_id,
  e.first_name,
  e.last_name,
  e.job_title,                                          -- D19 casing dirt: no cleaning DEF — raw passthrough
  e.store_id,
  e.manager_id,
  e.hire_date,
  e.termination_date,
  e.hourly_wage,                                        -- D18 outliers: no DEF — untouched, discoverable
  -- DEF-015: email normalization (lossy: keeps work_email_raw)
  CASE WHEN LOWER(TRIM(e.work_email)) IN ('n/a', 'none') OR TRIM(COALESCE(e.work_email, '')) = '' THEN NULL
       ELSE LOWER(TRIM(e.work_email)) END AS work_email,
  e.work_email AS work_email_raw
FROM oakhaven.employees e;
