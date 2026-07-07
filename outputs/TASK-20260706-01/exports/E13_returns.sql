-- TASK-20260706-01 · E13_returns.sql · 2026-07-07
-- PURPOSE: Full-row bronze export of oakhaven.returns for external BI (Power BI) exploration.
-- GROUNDING: grounding/schema.md (IDX-004) — PK returns.return_id (live DDL); medallion-spec
--   §Reproducibility (RULE-001 deterministic ORDER BY on the PK)
-- NOTE: No LIMIT is intentional. This is the one sanctioned full, unbounded bronze export in
--   this project (see EXPORT_GUIDE.md) — do not "fix" this by adding a LIMIT.
-- RUN: Get-Content E13_returns.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven

SELECT * FROM oakhaven.returns ORDER BY return_id;
