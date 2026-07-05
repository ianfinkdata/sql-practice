-- TASK-20260704-04 · V05_returns_scope.sql · 2026-07-05
-- PURPOSE: Make the returns scope transparent: silver returns vs fact-covered returns vs
--          mart_returns totals, quantify returns on non-revenue orders, and adversarially
--          verify the DEF-007 "at most one return per line" grain guarantee the fact relies on.
-- GROUNDING: DEF-003 (fact scope), DEF-005 (returned value), DEF-007 caveat (one return per
--            line — the fact's LEFT JOIN fan-out guard); RULE-001, RULE-006
-- RUN: Get-Content V05_returns_scope.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 — fact/mart return totals agree with each other; silver totals differ only by
--           RS2's non-revenue count (silver = fact + non-revenue).
--           RS2 — returns_on_non_revenue_orders reported (transparency, whatever the value).
--           RS3 — lines_with_multiple_returns = 0 (DEF-007 caveat holds; fact grain safe).

-- RS1: return row/units/value totals across the three layers
SELECT
  (SELECT COUNT(*) FROM oakhaven_silver.returns) AS silver_return_rows,
  (SELECT SUM(refund_amount) FROM oakhaven_silver.returns) AS silver_refund_total,
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines WHERE is_returned = 1) AS fact_return_rows,
  (SELECT SUM(refund_amount) FROM oakhaven_gold.fact_order_lines) AS fact_refund_total,     -- DEF-005 input
  (SELECT SUM(n_returns) FROM oakhaven_gold.mart_returns) AS mart_return_rows,
  (SELECT SUM(refund_value) FROM oakhaven_gold.mart_returns) AS mart_refund_total,          -- DEF-005
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines WHERE is_returned = 1) =
  (SELECT SUM(n_returns) FROM oakhaven_gold.mart_returns) AS fact_mart_match;

-- RS2: returns attached to NON-revenue orders (outside DEF-003 scope — excluded from the facts)
SELECT COUNT(*) AS returns_on_non_revenue_orders,
       COALESCE(SUM(r.refund_amount), 0) AS refund_outside_scope
FROM oakhaven_silver.returns r
JOIN oakhaven_silver.order_items oi ON oi.order_item_id = r.order_item_id
JOIN oakhaven_silver.orders o ON o.order_id = oi.order_id
WHERE o.status NOT IN ('completed', 'refunded');

-- RS3: DEF-007 caveat guard — order lines with MORE than one return row (fan-out risk); must be 0
SELECT COUNT(*) AS lines_with_multiple_returns
FROM (
  SELECT r.order_item_id
  FROM oakhaven_silver.returns r
  GROUP BY r.order_item_id
  HAVING COUNT(*) > 1
) x;
