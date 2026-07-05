-- TASK-20260704-04 · Q02_r1_monthly_revenue_by_channel.sql · 2026-07-05
-- PURPOSE: R1 Sales Explorer — primary trend: monthly gross revenue split by channel
--          (STORE/WEB); expect summer seasonality and the 2020 COVID dip.
-- GROUNDING: DEF-003 (order counts), DEF-004 (gross revenue); report-spec R1 trend
-- RUN: Get-Content Q02_r1_monthly_revenue_by_channel.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: 90 months × 2 channels = 180 rows; ORDER BY full grouping key (RULE-001);
--       channel is a table-derived column (clean enum), so its collation is session-independent.

SELECT
  m.sales_month,
  m.channel,
  SUM(m.order_count) AS order_count,                    -- DEF-003
  SUM(m.gross_revenue) AS gross_revenue,                -- DEF-004
  SUM(m.net_revenue) AS net_revenue                     -- DEF-005 (return_date-dated per mart policy)
FROM oakhaven_gold.mart_monthly_sales m
GROUP BY m.sales_month, m.channel
ORDER BY m.sales_month, m.channel;
