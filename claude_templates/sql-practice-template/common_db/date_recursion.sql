-- ============================================================
-- common_db: dim_date calendar table
-- Run this in the common_db schema.
-- Generates one row per day from 2019-01-01 through 2031-12-31.
-- Extend the end date if your data will go further.
-- ============================================================

USE common_db;

SET SESSION cte_max_recursion_depth = 5000;

CREATE TABLE dim_date AS

WITH RECURSIVE DateEngine AS (
    SELECT CAST('2019-01-01' AS DATE) AS CalendarDate
    UNION ALL
    SELECT DATE_ADD(CalendarDate, INTERVAL 1 DAY)
    FROM DateEngine
    WHERE CalendarDate < CAST('2031-12-31' AS DATE)
)

SELECT
    CAST(CalendarDate AS UNSIGNED)  AS DateKey,
    CalendarDate                    AS Date,
    YEAR(CalendarDate)              AS Year,
    MONTH(CalendarDate)             AS MonthNum,
    LEFT(MONTHNAME(CalendarDate),3) AS Month,
    QUARTER(CalendarDate)           AS Quarter,
    WEEKDAY(CalendarDate)           AS WeekDay,
    CASE
        WHEN WEEKDAY(CalendarDate) = 0 THEN 'Mon'
        WHEN WEEKDAY(CalendarDate) = 1 THEN 'Tue'
        WHEN WEEKDAY(CalendarDate) = 2 THEN 'Wed'
        WHEN WEEKDAY(CalendarDate) = 3 THEN 'Thu'
        WHEN WEEKDAY(CalendarDate) = 4 THEN 'Fri'
        WHEN WEEKDAY(CalendarDate) = 5 THEN 'Sat'
        WHEN WEEKDAY(CalendarDate) = 6 THEN 'Sun'
    END AS WeekDayName,
    CASE
        WHEN WEEKDAY(CalendarDate) >= 5 THEN 1
        ELSE 0
    END AS IsWeekend
FROM DateEngine;

-- Verify
SELECT COUNT(*) AS row_count FROM dim_date;
SELECT MIN(Date), MAX(Date) FROM dim_date;
