-- Oakhaven calendar — direct generation (contract v1.3).
-- Bronze carries date_key + date only; derived columns (year, month,
-- quarter, week_day, etc.) are a silver-layer concern and not needed here.
-- Replaces 02_calendar_copy.sql: that script copied from common_db.dim_date,
-- a database that does not exist on this machine. No other table has an FK
-- to calendar, so this table can be (re)built independently and rerun freely.

USE oakhaven;

DROP TABLE IF EXISTS calendar;

CREATE TABLE calendar (
  date_key INT  NOT NULL,
  `date`   DATE NOT NULL,
  PRIMARY KEY (date_key)
);

-- 2018-01-01..2038-12-31 = 7,670 rows; default cte_max_recursion_depth (1000)
-- isn't enough, so raise it for this session only.
SET SESSION cte_max_recursion_depth = 10000;

INSERT INTO calendar (date_key, `date`)
WITH RECURSIVE spine AS (
  SELECT DATE('2018-01-01') AS d
  UNION ALL
  SELECT d + INTERVAL 1 DAY FROM spine WHERE d < '2038-12-31'
)
SELECT CAST(DATE_FORMAT(d, '%Y%m%d') AS UNSIGNED), d FROM spine;
