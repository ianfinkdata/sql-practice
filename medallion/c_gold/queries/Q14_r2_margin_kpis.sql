-- TASK-20260705-01 · Q14_r2_margin_kpis.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — margin KPI row: MEDIAN unit margin over the
--          DEF-003 revenue lines in fact_order_lines, with the distribution bounds and the
--          realized below-cost line count (RULE-008 call-out).
-- GROUNDING: DEF-021 v1.0 (unit margin; "median unit margin" = median over DEF-003 revenue
--            lines in fact_order_lines per the DEF caveat), DEF-003 (scope is the fact itself),
--            RULE-008 (below-cost lines are a feature, surfaced); report-spec R2 KPIs
-- RUN: Get-Content Q14_r2_margin_kpis.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- MEDIAN RULE (MySQL has no MEDIAN()): sort the unit_margin multiset ascending with
--   ROW_NUMBER() (order_item_id tie-break — deterministic, RULE-001) and take the rows at
--   positions FLOOR((n+1)/2) and CEILING((n+1)/2). Odd n → the two positions coincide (the
--   single middle value); EVEN n → the median is the ARITHMETIC MEAN of the two middle values.
--   AVG() covers both cases; ROUND(…, 2) per medallion-spec §Reproducibility rule 3.
--   Tie order among equal margins cannot change the result — positions select from the sorted
--   multiset, so the values at the middle positions are order-independent.
-- NOTE: single-row aggregate — trivially deterministic (RULE-001).

SELECT
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines) AS n_revenue_lines,       -- DEF-003 scope
  (SELECT ROUND(AVG(unit_margin), 2)
   FROM (
     SELECT unit_margin,
            ROW_NUMBER() OVER (ORDER BY unit_margin, order_item_id) AS rn,        -- RULE-001 tie-break
            COUNT(*) OVER () AS n
     FROM oakhaven_gold.fact_order_lines
   ) ordered
   WHERE rn IN (FLOOR((n + 1) / 2), CEILING((n + 1) / 2))) AS median_unit_margin, -- DEF-021 (median rule above)
  (SELECT MIN(unit_margin) FROM oakhaven_gold.fact_order_lines) AS min_unit_margin,  -- DEF-021 (distribution lower bound)
  (SELECT MAX(unit_margin) FROM oakhaven_gold.fact_order_lines) AS max_unit_margin,  -- DEF-021 (distribution upper bound)
  (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines
   WHERE unit_margin < 0) AS below_cost_lines;                                    -- DEF-021 / RULE-008 (V07 reconciles)
