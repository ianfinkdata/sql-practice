-- TASK-20260704-04 · G02_dim_store.sql · 2026-07-05
-- PURPOSE: Gold dim_store — business-named store dimension (trivial conform of silver stores;
--          the table is clean, no transforms needed).
-- GROUNDING: medallion-spec §Gold rules (dim_store); silver S11 passthrough
-- RUN: Get-Content G02_dim_store.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTE: square_feet is NULL only for the WEB row (store_id 13) — structural, not dirt.

CREATE OR REPLACE VIEW oakhaven_gold.dim_store AS
SELECT
  st.store_id,
  st.store_code,
  st.city,
  st.state,
  st.opened_date,
  st.square_feet
FROM oakhaven_silver.stores st;
