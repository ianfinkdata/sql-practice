-- TASK-20260704-04 · Q09_r2_price_vs_cost.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — scatter source: list_price vs unit_cost for all
--          850 products, with the D16 below-cost anomaly flag as the call-out series.
-- GROUNDING: RULE-008 (D16 below-cost prices are planted FEATURES — highlighted, never fixed;
--            B06 census = 17); dim_product attributes; report-spec R2 breakdowns
-- RUN: Get-Content Q09_r2_price_vs_cost.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: 850 rows — captured in full in EXPECTED_OUTPUTS.md (TASK-20260705-02).
--       ORDER BY product_id (PK — RULE-001).
-- OMITTED: "margin distribution" (report-spec R2) — "unit margin" has NO DEF in
--          grounding/definitions.md; escalated as MISSING DEFINITION in the task handoff.
--          The D17 penny-line count for the R2 call-out is in Q11 RS2 (anomalies panel).

SELECT
  p.product_id,
  p.sku,
  p.category_name,
  p.unit_cost,
  p.list_price,
  p.is_below_cost                                       -- D16 planted anomaly flag (RULE-008)
FROM oakhaven_gold.dim_product p
ORDER BY p.product_id;
