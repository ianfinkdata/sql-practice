-- TASK-20260704-03 · S14_calendar.sql · 2026-07-04
-- PURPOSE: Silver calendar — trivial passthrough (clean utility date spine, full 2019-01-01..
--          2031-12-31 width; gold dim_date constrains to the fact window, not silver).
-- GROUNDING: medallion-spec §Silver rules (clean tables pass through as trivial views) and
--            §Gold rules (dim_date does the 2019-01-01..2026-06-30 constraint); RULE-005
-- RUN: Get-Content S14_calendar.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)

CREATE OR REPLACE VIEW oakhaven_silver.calendar AS
SELECT
  c.date_key,
  c.`date`,
  c.`year`,
  c.month_num,
  c.`month`,
  c.`quarter`,
  c.week_day,
  c.week_day_name,
  c.is_weekend,
  c.week_start,
  c.iso_week_start
FROM oakhaven.calendar c;
