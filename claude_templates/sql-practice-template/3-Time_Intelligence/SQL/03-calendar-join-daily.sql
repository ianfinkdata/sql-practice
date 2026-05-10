-- ============================================================
-- Exercise 3, Tier 2b — Calendar join with gap-fill
--
-- Goal: Join sales to dim_date so that days with no sales still
-- appear in the result with sale_amount = 0 (no missing dates).
--
-- Source: common_db.dim_date (must exist — run common_db/weekstart_adds.sql)
-- ============================================================

USE [your_schema];

CREATE OR REPLACE VIEW silver_rolling_daily_sales AS

WITH dim_calendar AS (
    SELECT * FROM common_db.dim_date AS cal
),

daily_sales AS (
    SELECT
        d.Date               AS calendar_date,
        d.WeekStart          AS week_start_date,
        d.month_start_date,
        COALESCE(SUM(s.sale_amount), 0) AS current_period_sales
    FROM dim_calendar AS d
    LEFT JOIN sales AS s ON d.Date = s.sale_date
    -- Rolling window: last 4 months through today
    WHERE d.month_start_date BETWEEN DATE_ADD(CURRENT_DATE, INTERVAL -4 MONTH) AND CURRENT_DATE
    GROUP BY calendar_date, week_start_date, month_start_date
)

SELECT * FROM daily_sales;

SELECT * FROM silver_rolling_daily_sales;

-- Validate against data/03-calendar-join-daily.csv
