-- TASK-20260706-01 · E12_shipments.sql · 2026-07-07
-- PURPOSE: Full-row bronze export of oakhaven.shipments for external BI (Power BI) exploration.
-- GROUNDING: grounding/schema.md (IDX-004) — PK shipments.shipment_id (live DDL); medallion-spec
--   §Reproducibility (RULE-001 deterministic ORDER BY on the PK)
-- NOTE: No LIMIT is intentional. This is the one sanctioned full, unbounded bronze export in
--   this project (see EXPORT_GUIDE.md) — do not "fix" this by adding a LIMIT.
--   delivered_date_raw is exported as-is (raw text date column) — do not derive dates from it
--   without the silver-layer type cast.
-- RUN: Get-Content E12_shipments.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven

SELECT * FROM oakhaven.shipments ORDER BY shipment_id;
