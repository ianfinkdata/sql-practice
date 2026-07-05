-- TASK-20260704-03 · S12_product_categories.sql · 2026-07-04
-- PURPOSE: Silver product_categories — trivial passthrough (clean utility dimension).
-- GROUNDING: medallion-spec §Silver rules (clean tables pass through as trivial views); RULE-005
-- RUN: Get-Content S12_product_categories.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)

CREATE OR REPLACE VIEW oakhaven_silver.product_categories AS
SELECT
  pc.category_id,
  pc.category_name,
  pc.parent_category_id
FROM oakhaven.product_categories pc;
