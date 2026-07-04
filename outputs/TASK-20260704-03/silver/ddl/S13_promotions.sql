-- TASK-20260704-03 · S13_promotions.sql · 2026-07-04
-- PURPOSE: Silver promotions — trivial passthrough (clean table; the minor promo_code
--          lowercase mix has no cleaning DEF).
-- GROUNDING: medallion-spec §Silver rules (clean tables pass through as trivial views);
--            RULE-005, RULE-007 (promo_code casing stays raw — no DEF)
-- RUN: Get-Content S13_promotions.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)

CREATE OR REPLACE VIEW oakhaven_silver.promotions AS
SELECT
  pr.promo_id,
  pr.promo_code,
  pr.start_date,
  pr.end_date,
  pr.discount_pct,
  pr.description
FROM oakhaven.promotions pr;
