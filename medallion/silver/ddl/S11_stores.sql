-- TASK-20260704-03 · S11_stores.sql · 2026-07-04
-- PURPOSE: Silver stores — trivial passthrough (clean table) so silver is a complete,
--          self-sufficient layer.
-- GROUNDING: medallion-spec §Silver rules (clean tables pass through as trivial views); RULE-005
-- RUN: Get-Content S11_stores.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTE: square_feet is NULL only for the WEB row (store_id 13) — structural, not dirt.

CREATE OR REPLACE VIEW oakhaven_silver.stores AS
SELECT
  st.store_id,
  st.store_code,
  st.city,
  st.state,
  st.opened_date,
  st.square_feet
FROM oakhaven.stores st;
