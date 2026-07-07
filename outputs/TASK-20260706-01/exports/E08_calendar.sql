-- TASK-20260706-01 · E08_calendar.sql · 2026-07-07
-- PURPOSE: Full-row bronze export of oakhaven.calendar for external BI (Power BI) exploration.
-- GROUNDING: grounding/schema.md (IDX-004) — PK calendar.date_key, a GENERATED ALWAYS AS
--   (cast(`date` as unsigned)) STORED column (live DDL); medallion-spec §Reproducibility
--   (RULE-001 deterministic ORDER BY on the PK)
-- NOTE: No LIMIT is intentional. This is the one sanctioned full, unbounded bronze export in
--   this project (see EXPORT_GUIDE.md) — do not "fix" this by adding a LIMIT. Calendar window
--   (2019-01-01..2031-12-31) is wider than the fact tables' window by design (schema.md).
-- RUN: Get-Content E08_calendar.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven

SELECT * FROM oakhaven.calendar ORDER BY date_key;
