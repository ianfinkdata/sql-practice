-- Manufactured date spine for Oakhaven: one row per day, 2018-01-01
-- through 2038-12-31 inclusive (~7670 rows). This is NOT raw/messy data
-- -- it's built directly in SQL via a recursive CTE, not a Python loop.
-- Self-contained: safe to run this file on its own against oakhaven.db.

DROP TABLE IF EXISTS bronze_calendar;
CREATE TABLE bronze_calendar (
    datekey INTEGER,
    date    TEXT
);

INSERT INTO bronze_calendar (datekey, date)
WITH RECURSIVE dates(d) AS (
    SELECT date('2018-01-01')
    UNION ALL
    SELECT date(d, '+1 day')
    FROM dates
    WHERE d < date('2038-12-31')
)
SELECT
    CAST(strftime('%Y%m%d', d) AS INTEGER) AS datekey,
    d AS date
FROM dates;
