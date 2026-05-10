-- ============================================================
-- common_db: Add week and month boundary columns to dim_date
-- Run AFTER date_recursion.sql
-- ============================================================

USE common_db;

ALTER TABLE dim_date
    ADD COLUMN WeekStart     DATE,
    ADD COLUMN ISOWeekStart  DATE,
    ADD COLUMN month_start_date DATE;

UPDATE dim_date
SET
    -- Sunday of the week (US convention)
    WeekStart         = DATE_SUB(Date, INTERVAL (DAYOFWEEK(Date) - 1) DAY),
    -- Monday of the ISO week
    ISOWeekStart      = DATE_SUB(Date, INTERVAL WEEKDAY(Date) DAY),
    -- First day of the calendar month
    month_start_date  = DATE_SUB(Date, INTERVAL (DAY(Date) - 1) DAY);

-- Optional: add a generated primary key if you want indexed lookups
-- ALTER TABLE dim_date ADD PRIMARY KEY (DateKey);

SELECT * FROM dim_date LIMIT 5;
