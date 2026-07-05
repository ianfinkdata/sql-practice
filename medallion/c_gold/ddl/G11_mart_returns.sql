-- TASK-20260704-04 · G11_mart_returns.sql · 2026-07-05
-- PURPOSE: Gold mart_returns — return-month × store × channel trend mart: return counts,
--          returned units, refund value.
-- GROUNDING: DEF-005 (returned value + dating policy), DEF-007 (units returned input),
--            DEF-003 (scope: returns on revenue-recognized order lines, via fact_order_lines)
-- RUN: Get-Content G11_mart_returns.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- DATING POLICY (DEF-005 caveat — this is the returns side of the netting): TREND mart, so rows
-- are dated by RETURN_DATE month (cash-timing view); store/channel are the ORIGINAL order
-- line's dimensions per DEF-005 ("return value attributes to the ORIGINAL order line's
-- dimensions, dated by policy").
--
-- SCOPE: returns reachable from fact_order_lines, i.e. returns on DEF-003 revenue-order lines.
-- V05 quantifies returns (if any) sitting on non-revenue orders so the scope is transparent.
--
-- Grain: return_month ('%Y-%m' of return_date) × store_id × channel.

CREATE OR REPLACE VIEW oakhaven_gold.mart_returns AS
SELECT
  DATE_FORMAT(f.return_date, '%Y-%m') AS return_month,  -- DEF-005 trend-mart dating: return_date
  f.store_id,
  f.channel,
  COUNT(*) AS n_returns,
  SUM(f.quantity_returned) AS units_returned,           -- DEF-007 input
  SUM(f.refund_amount) AS refund_value                  -- DEF-005 returned_value
FROM oakhaven_gold.fact_order_lines f
WHERE f.is_returned = 1
GROUP BY DATE_FORMAT(f.return_date, '%Y-%m'), f.store_id, f.channel;
