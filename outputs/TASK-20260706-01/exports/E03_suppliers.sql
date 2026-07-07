-- TASK-20260706-01 · E03_suppliers.sql · 2026-07-07
-- PURPOSE: Full-row bronze export of oakhaven.suppliers for external BI (Power BI) exploration.
-- GROUNDING: grounding/schema.md (IDX-004) — PK suppliers.supplier_id (live DDL); medallion-spec
--   §Reproducibility (RULE-001 deterministic ORDER BY on the PK)
-- NOTE: No LIMIT is intentional. This is the one sanctioned full, unbounded bronze export in
--   this project (see EXPORT_GUIDE.md) — do not "fix" this by adding a LIMIT.
-- RUN: Get-Content E03_suppliers.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven

SELECT * FROM oakhaven.suppliers ORDER BY supplier_id;
