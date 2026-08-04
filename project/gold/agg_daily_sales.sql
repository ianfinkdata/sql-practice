-- agg_daily_sales: one row per calendar day (including zero-order days)
-- across the operational sales window. This is the portable
-- LEFT-JOIN-against-a-date-spine pattern: start from dim_date, not from
-- fact_sales, so days with no orders still produce a row with 0 counts
-- and totals instead of silently disappearing.
--
-- The date bounds below ('2021-01-01' / '2026-06-30') mirror
-- build_lib/config.py's SALES_START and SNAPSHOT_DATE -- if those
-- constants ever change, update this view to match.

DROP VIEW IF EXISTS agg_daily_sales;
CREATE VIEW agg_daily_sales AS
SELECT
    d.date AS order_date,
    d.year,
    d.month,
    d.day_name,
    d.is_weekend,
    COUNT(f.order_line_id) AS order_line_count,
    ROUND(COALESCE(SUM(f.net_amount), 0), 2) AS total_net_amount
FROM dim_date d
LEFT JOIN fact_sales f ON f.datekey = d.datekey
WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
GROUP BY d.date, d.year, d.month, d.day_name, d.is_weekend
ORDER BY d.date;
