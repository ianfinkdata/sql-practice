-- TASK-20260704-04 · Q05_r1_top15_months_mom.sql · 2026-07-05
-- PURPOSE: R1 Sales Explorer — detail table: top 15 months by gross revenue with MoM change
--          (change computed on the FULL monthly series before the top-15 cut).
-- GROUNDING: DEF-004 (gross revenue); report-spec R1 detail (MoM delta is arithmetic on the
--            DEF-004 series, requested verbatim by the spec)
-- RUN: Get-Content Q05_r1_top15_months_mom.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: LIMIT 15 with deterministic ORDER BY gross DESC + sales_month tie-break (RULE-001).

WITH monthly AS (
  SELECT m.sales_month,
         SUM(m.gross_revenue) AS gross_revenue          -- DEF-004
  FROM oakhaven_gold.mart_monthly_sales m
  GROUP BY m.sales_month
),
with_mom AS (
  SELECT sales_month,
         gross_revenue,
         gross_revenue - LAG(gross_revenue) OVER (ORDER BY sales_month) AS mom_change,
         ROUND((gross_revenue - LAG(gross_revenue) OVER (ORDER BY sales_month))
               / LAG(gross_revenue) OVER (ORDER BY sales_month) * 100, 2) AS mom_change_pct
  FROM monthly
)
SELECT sales_month, gross_revenue, mom_change, mom_change_pct
FROM with_mom
ORDER BY gross_revenue DESC, sales_month
LIMIT 15;
