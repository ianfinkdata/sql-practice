# Index (Table of Contents Memory Map)
Agents scan THIS file first, then load only the entries they need.

| ID | Title | Summary | Tags | Pointer |
|---|---|---|---|---|
| IDX-001 | Agent Contract | Rules all agents follow; DB write-scope boundary | process | CLAUDE.md |
| IDX-002 | Implementation Plan | Goal, verified starting state, architecture decisions A1–A6, task list, gates | process | IMPLEMENTATION_PLAN.md |
| IDX-003 | Definitions Registry | DEF-001…DEF-018 (DRAFT v0.1, pending Ian approval) — rounding law, revenue recognition, cleaning rules, dedupe, metrics | grounding | grounding/definitions.md |
| IDX-004 | Schema Snapshot | Live-verified DDL + exact row counts + enum censuses for all 14 bronze tables (2026-07-04) | grounding | grounding/schema.md |
| IDX-005 | Medallion Spec | Layer rules, naming, file layout, reproducibility law ("exact same outputs") | grounding | grounding/medallion-spec.md |
| IDX-006 | Report Spec | Exploratory report template anatomy, the 3 reports, visual rules, lineage requirement | grounding | grounding/report-spec.md |
| IDX-007 | Data Contract (upstream) | How bronze was generated: dirt quotas D1–D25, agent charters, acceptance criteria. Read-only background | grounding | oakhaven/DATA_CONTRACT.md |
| IDX-008 | MySQL Setup | Windows connection command, file-based execution, output capture, snapshot refresh | infra | process/mysql-setup.md |
| IDX-009 | Task Briefs | TASK-20260704-01…05: documentation, bronze pack, silver, gold, reports | process | process/briefs/ |
| IDX-010 | Lessons | Seeded reproducibility + environment rules; retro-maintained | grounding | grounding/lessons.md |
