ALTER TABLE dim_calendar
-- 1. Remove the static column we built earlier
DROP COLUMN DateKey,

-- 2. Add the smart column, tell it how to calculate, and make it the Primary Key
ADD COLUMN DateKey INT GENERATED ALWAYS AS (CAST(CalendarDate AS UNSIGNED)) STORED PRIMARY KEY FIRST;



alter table dim_date
add column WeekStart DATE,
add column ISOWeekStart DATE
;


UPDATE dim_date
SET 
    -- Subtract (DAYOFWEEK - 1) days to find Sunday
    WeekStart = DATE_SUB(Date, INTERVAL (DAYOFWEEK(Date) - 1) DAY),
    
    -- Subtract WEEKDAY days to find Monday
    ISOWeekStart = DATE_SUB(Date, INTERVAL WEEKDAY(Date) DAY)
    WHERE DateKey > 20181231 ;
    
    select * from dim_date;
