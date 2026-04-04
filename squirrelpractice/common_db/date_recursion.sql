use common_db;

SET SESSION cte_max_recursion_depth = 5000;
CREATE TABLE dim_date as

WITH RECURSIVE DateEngine AS (  
SELECT CAST('2019-01-01' AS DATE) AS CalendarDate  
UNION ALL  
SELECT DATE_ADD( CalendarDate, INTERVAL 1 DAY)  
FROM DateEngine  
WHERE CalendarDate < CAST('2031-12-31' AS DATE)
)

SELECT 
CAST(CalendarDate AS DECIMAL) as DateKey,
CalendarDate as Date,
YEAR(CalendarDate) as Year,
MONTH(CalendarDate) as MonthNum,
LEFT(MONTHNAME(CalendarDate),3) as Month,
QUARTER(CalendarDate) as Quarter,
WEEKDAY(CalendarDate) as WeekDay,
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



