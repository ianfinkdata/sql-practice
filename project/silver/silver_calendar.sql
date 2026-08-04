-- silver_calendar: bronze_calendar is already a clean manufactured spine
-- (see bronze/calendar_recursive_cte.sql), so this view is a thin
-- pass-through that exists mainly for naming consistency with the rest
-- of the silver layer. Date-part derivations (year/month/quarter/etc.)
-- live in gold/dim_date.sql.

DROP VIEW IF EXISTS silver_calendar;
CREATE VIEW silver_calendar AS
SELECT
    datekey,
    date
FROM bronze_calendar;
