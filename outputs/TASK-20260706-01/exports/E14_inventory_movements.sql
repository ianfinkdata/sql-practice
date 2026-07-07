-- TASK-20260706-01 · E14_inventory_movements.sql · 2026-07-07
-- PURPOSE: Full-row bronze export of oakhaven.inventory_movements for external BI (Power BI)
--   exploration.
-- GROUNDING: grounding/schema.md (IDX-004) — PK inventory_movements.movement_id (live DDL);
--   medallion-spec §Reproducibility (RULE-001 deterministic ORDER BY on the PK)
-- NOTE: No LIMIT is intentional. This is the one sanctioned full, unbounded bronze export in
--   this project (see EXPORT_GUIDE.md) — do not "fix" this by adding a LIMIT. Planted orphan
--   transfer_out rows (no matching transfer_in, ~1.5%) are left visible per RULE-008.
-- RUN: Get-Content E14_inventory_movements.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven

SELECT * FROM oakhaven.inventory_movements ORDER BY movement_id;
