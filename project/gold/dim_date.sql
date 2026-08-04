-- dim_date: date dimension built from silver_calendar, one row per day
-- from 2018-01-01 through 2038-12-31. Adds year/month/quarter/
-- day-of-week/weekend flags commonly needed by BI-style queries.

DROP VIEW IF EXISTS dim_date;
CREATE VIEW dim_date AS
SELECT
    datekey,
    date,
    CAST(strftime('%Y', date) AS INTEGER) AS year,
    CAST(strftime('%m', date) AS INTEGER) AS month,
    CASE CAST(strftime('%m', date) AS INTEGER)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    ((CAST(strftime('%m', date) AS INTEGER) - 1) / 3) + 1 AS quarter,
    CAST(strftime('%d', date) AS INTEGER) AS day_of_month,
    CAST(strftime('%w', date) AS INTEGER) AS day_of_week,  -- 0=Sunday .. 6=Saturday
    CASE CAST(strftime('%w', date) AS INTEGER)
        WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    CASE WHEN CAST(strftime('%w', date) AS INTEGER) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend
FROM silver_calendar;
