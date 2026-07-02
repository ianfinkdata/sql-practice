-- Calendar: verbatim lift-and-shift of common_db.dim_date (contract v1.1).
-- Full copy (2019-01-01..2031-12-31, 4,748 rows) so the calendar outlives the
-- fact window. Only tightening: `date` becomes NOT NULL (dirty-not-broken law).
-- Rerunnable independently of 01_schema.sql; no FK ties to calendar.

USE oakhaven;

DROP TABLE IF EXISTS calendar;
CREATE TABLE calendar LIKE common_db.dim_date;
ALTER TABLE calendar MODIFY `date` DATE NOT NULL;

INSERT INTO calendar
  (`date`, `year`, month_num, `month`, `quarter`,
   week_day, week_day_name, is_weekend, week_start, iso_week_start)
SELECT
  `date`, `year`, month_num, `month`, `quarter`,
  week_day, week_day_name, is_weekend, week_start, iso_week_start
FROM common_db.dim_date;
