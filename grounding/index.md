# Index (Table of Contents Memory Map)
Agents scan THIS file first, then load only the entries they need.

| ID | Title | Summary | Tags | Pointer |
|---|---|---|---|---|
| IDX-001 | Agent Contract | Rules all agents follow; DB write-scope boundary | process | CLAUDE.md |
| IDX-002 | Implementation Plan | Goal, verified starting state, architecture decisions A1–A6, task list, gates | process | IMPLEMENTATION_PLAN.md |
| IDX-003 | Definitions Registry | DEF-001…DEF-021 (APPROVED; DEF-012/013 v1.1 mappings final; DEF-014 v1.1; DEF-018 v1.1 order-level pending semantics; DEF-020 loyalty tier + DEF-021 unit margin added 2026-07-05) — rounding law, revenue recognition, cleaning rules, dedupe, metrics | grounding | grounding/definitions.md |
| IDX-004 | Schema Snapshot | Live-verified DDL + exact row counts + enum censuses for all 14 bronze tables (2026-07-04) | grounding | grounding/schema.md |
| IDX-005 | Medallion Spec | Layer rules, naming, file layout, reproducibility law ("exact same outputs") | grounding | grounding/medallion-spec.md |
| IDX-006 | Report Spec | Exploratory report template anatomy, the 3 reports, visual rules, lineage requirement | grounding | grounding/report-spec.md |
| IDX-007 | Data Contract (upstream) | How bronze was generated: dirt quotas D1–D25, agent charters, acceptance criteria. Read-only background | grounding | oakhaven/DATA_CONTRACT.md |
| IDX-008 | MySQL Setup | Windows connection command, file-based execution, output capture, snapshot refresh | infra | process/mysql-setup.md |
| IDX-009 | Task Briefs | TASK-20260704-01…05 (documentation, bronze pack, silver, gold, reports) + TASK-20260705-01 (gold amendment: DEF-020/021, gated on PR #56 merge) | process | process/briefs/ |
| IDX-010 | Lessons | Seeded reproducibility + environment rules; retro-maintained | grounding | grounding/lessons.md |
| IDX-011 | Bronze Data Dictionary | All 14 tables documented with live profiles, D1–D25 evidence, planted anomalies; SHIPPED 2026-07-04 | deliverable | medallion/_docs/DATA_DICTIONARY.md |
| IDX-012 | Bronze Baseline Pack | B01–B06 + captured outputs; gross revenue 83,160,177.98; DEF-016 reconciles 0 mismatches; SHIPPED 2026-07-04 — reconciliation targets for silver/gold | deliverable | medallion/a_bronze/ |
| IDX-013 | Silver Layer | oakhaven_silver: 14 table views + customer_dupe_map helper, live; V01–V07 verified vs B01/B03/B04; SHIPPED 2026-07-04 (PR #54, QA'd by Ian) — gold builds on these views | deliverable | medallion/b_silver/ |
| IDX-014 | Gold Layer | oakhaven_gold: fact_order_lines/fact_orders + 4 dims + 5 marts live; SHIPPED 2026-07-05 (PR #56). AMENDED by TASK-20260705-01 (pending QA): DEF-020 loyalty tier applied in dim_customer (+rank, +raw) and DEF-021 unit/catalog margin in fact_order_lines/dim_product/mart_product_performance; V06 tier census = B03 totals (7,296/2,583/1,491/630, zero NULL leaks), V07 margin reconciliation (3,444 revenue-scope below-cost lines of 3,534 all-lines; 17 catalog); Q13–Q15 close the R1 by-tier + R2 margin gaps (median unit margin 103.47); regression V01–V05/Q01–Q12 byte-identical; amendment files in outputs/TASK-20260705-01/gold/ awaiting promotion | deliverable | medallion/c_gold/ |
| IDX-015 | Exploratory Reports | template.html + R1 Sales Explorer, R2 Product & Category Explorer, R3 Data Quality Explorer; every value transcribed verbatim from medallion/{c_gold,a_bronze}/EXPECTED_OUTPUTS.md with lineage-table footers; validator PASS WITH WARNINGS 2026-07-05 (0 blocking, 6 informational — stale DEF-009 citation in R3 vs DEF-020, two disclosed R2 substitute visuals where Q07/Q09 only have aggregate-signature captures). Pending Ian's QA; not yet promoted to reports/ | deliverable | outputs/TASK-20260704-05/reports/ |
