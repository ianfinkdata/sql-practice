-- TASK-20260704-04 · V01_gross_revenue_reconciliation.sql · 2026-07-05
-- PURPOSE: Prove every gold gross-revenue path reconciles to the bronze B05 ground truth
--          (83,160,177.98) to the cent, and that mart_monthly_sales netting drops nothing.
-- GROUNDING: DEF-001, DEF-003, DEF-004 (gross revenue), DEF-005 (net = gross − returned);
--            bronze capture medallion/a_bronze/EXPECTED_OUTPUTS.md B05; RULE-001, RULE-006
-- RUN: Get-Content V01_gross_revenue_reconciliation.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 — all four totals = 83160177.98 and matches_b05 = 1.
--           RS2 — mart net total = fact net total, is_match = 1.
--           RS3 — orphan_return_cells = 0 (the mart's LEFT JOIN drops no return-side cell).

-- RS1: gross revenue via four independent gold paths vs the B05 constant (DEF-004)
SELECT
  (SELECT SUM(gross_revenue)    FROM oakhaven_gold.mart_monthly_sales)        AS mart_monthly_gross,
  (SELECT SUM(line_net_revenue) FROM oakhaven_gold.fact_order_lines)          AS fact_line_gross,
  (SELECT SUM(gross_revenue)    FROM oakhaven_gold.mart_category_sales)       AS mart_category_gross,
  (SELECT SUM(gross_revenue)    FROM oakhaven_gold.mart_product_performance)  AS mart_product_gross,
  (SELECT SUM(gross_revenue) FROM oakhaven_gold.mart_monthly_sales) = 83160177.98 AS matches_b05;

-- RS2: DEF-005 net-revenue consistency (mart cells vs the fact computed directly)
SELECT
  (SELECT SUM(net_revenue) FROM oakhaven_gold.mart_monthly_sales) AS mart_net_total,
  (SELECT SUM(line_net_revenue) - SUM(refund_amount) FROM oakhaven_gold.fact_order_lines) AS fact_net_total,
  (SELECT SUM(net_revenue) FROM oakhaven_gold.mart_monthly_sales) =
  (SELECT SUM(line_net_revenue) - SUM(refund_amount) FROM oakhaven_gold.fact_order_lines) AS is_match;

-- RS3: tripwire — return-side cells (return-month × store × channel) with no gross-side cell
-- would silently vanish from mart_monthly_sales' LEFT JOIN; must be 0.
SELECT COUNT(*) AS orphan_return_cells
FROM (
  SELECT DATE_FORMAT(f.return_date, '%Y-%m') AS m, f.store_id, f.channel
  FROM oakhaven_gold.fact_order_lines f
  WHERE f.is_returned = 1
  GROUP BY DATE_FORMAT(f.return_date, '%Y-%m'), f.store_id, f.channel
) r
LEFT JOIN (
  SELECT DATE_FORMAT(f.order_date, '%Y-%m') AS m, f.store_id, f.channel
  FROM oakhaven_gold.fact_order_lines f
  GROUP BY DATE_FORMAT(f.order_date, '%Y-%m'), f.store_id, f.channel
) g ON g.m = r.m AND g.store_id = r.store_id AND g.channel = r.channel
WHERE g.m IS NULL;
