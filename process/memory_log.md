# Memory Log (append-only)
One entry block per task, appended at the end. Verdicts are Ian's.

---
TASK: SETUP-20260704
BRIEF: (bootstrap — no brief) Instantiate agent-starter-kit for sql-practice; write implementation plan + grounding for the medallion project.
OUTPUT: CLAUDE.md, IMPLEMENTATION_PLAN.md, grounding/{index,definitions,schema,medallion-spec,report-spec,lessons}.md, process/{briefs/TASK-20260704-01..05,mysql-setup,prompts,memory_log}.md, .claude/agents/{data-documenter,sql-builder,sql-validator,report-designer,retrospective}.md
NOTES: Live DB verified (14 tables, exact contract counts). Plan decisions A1–A6 approved by Ian 2026-07-04. Shipped as PR #52 (branch task/SETUP-20260704, commit bcf865d), merged 2026-07-04 — merge = approval artifact for definitions v1.0 (DEF-012/013 mapping tables still pending TASK-02 census).
VERDICT: ship
CORRECTIONS: none

---
TASK: TASK-20260704-01
BRIEF: process/briefs/TASK-20260704-01.md (bronze data dictionary)
OUTPUT: outputs/TASK-20260704-01/DATA_DICTIONARY.md + profiling/*.sql,*.out.txt (8 query/capture pairs)
BUILDER: data-documenter (sub-agent). VALIDATOR: sql-validator — PASS WITH WARNINGS. Reproduction 7/8 byte-identical; 10 numbers independently re-derived, 0 mismatches. Issues: (1) P01 row-order nondeterminism (ORDER BY on string-literal alias inherits session collation — fix: COLLATE utf8mb4_bin); (2) 3x "Faker" generation-mechanics mentions violate brief constraint. Warnings: D3/D6 examples census-level not row-level; D11 prose overstates; ERD cardinality cosmetics.
VERDICT: ship (Ian, 2026-07-04 — "ship away", after corrections applied and re-verified)
CORRECTIONS: applied by orchestrator 2026-07-04: P01 ORDER BY pinned to utf8mb4_bin, rerun 2x byte-identical, capture refreshed (values unchanged); 3 Faker mentions reworded; D11 prose corrected to "in line with" (5.8% vs 6%); D3/D6 given row-level examples (customer_id 49/175, 15/49 — live-queried). ERD cardinality cosmetics left as-is. → new RULE-011/012 in lessons.md.
---
TASK: TASK-20260704-02
BRIEF: process/briefs/TASK-20260704-02.md (bronze baseline query pack)
OUTPUT: outputs/TASK-20260704-02/bronze/B01-B06 + EXPECTED_OUTPUTS.md
BUILDER: sql-builder (sub-agent). VALIDATOR: sql-validator — PASS WITH WARNINGS. Reproduction 6/6 byte-identical (45 result sets); 5 numbers independently re-derived, 0 mismatches (gross revenue 83,160,177.98; DEF-016 reconciliation 0 mismatches / 60,000 orders). No blocking issues. Warnings: (1) transfer pairing via reference token is undocumented logic — needs a DEF (proposed DEF-019) + 38 reverse-orphan transfer_in rows unexplained; (2) D8 quota prose used wrong denominator (rebased: 4.94% vs 5% quota — excellent); (3) D23 junk sub-quota not separable; (4) D2 split verified by validator but unstated in write-up; (5) medallion-spec RUN-header template uses "<" redirection that is invalid in PowerShell — spec fix needed.
VERDICT: ship (Ian, 2026-07-04 — "ship away", after corrections applied and re-verified)
CORRECTIONS: applied by orchestrator 2026-07-04: D8 quota prose rebased to meaningful denominator (1,561/31,588 = 4.94% vs 5%); D2 split percentages stated (verified against captured counts); RUN headers in B01–B06 switched to the PowerShell-valid Get-Content pipe form (B01/B05 smoke-tested clean after edit, B05 still 83,160,177.98). Grounding updates approved by Ian: medallion-spec RUN template fixed, RULE-011/012 added, DEF-019 (transfer pairing incl. 38 reverse-orphan transfer_ins as documented discoverable) added v1.0. D23 junk sub-quota left combined (no documented ID format — unchanged).

---
TASK: TASK-20260704-03
BRIEF: process/briefs/TASK-20260704-03.md (silver layer, oakhaven_silver views)
OUTPUT: outputs/TASK-20260704-03/silver/ddl/S00-S14 + verify/V01-V07 + EXPECTED_OUTPUTS.md
BUILDER: sql-builder (sub-agent). Scope amendment (Ian-approved in session): 14 views not 13 -- order_items added as trivial passthrough (D17 penny prices untouched per RULE-008). Live objects created: schema oakhaven_silver + 15 views (14 table views + DEF-014 helper customer_dupe_map). All verify targets hit exactly: row parity 14/14 = B01; DEF-009/012/013 zero NULL leaks with B03-reconciled totals; DEF-017 flags 9/2/60/24/36 = B04; DEF-014 = 134 phone-resolved + 16 unresolved = 150 (email fallback resolves 0 on live data -- local parts mutated by generator; documented in EXPECTED_OUTPUTS); DEF-011 parsed NULLs 3005 = 1840 NULL + 1165 PENDING, 0 parse failures. Verify pack run twice, byte-identical. Validation: NOT yet -- pending sql-validator.
VALIDATOR: sql-validator — PASS WITH WARNINGS, zero blocking issues. Reproduction 7/7 verify queries byte-identical (run twice). All DEF transforms verbatim vs canonical SQL. Grain proven (customer_dupe_map structurally ≤1 row/customer; 11851→5514 re-derived from raw bronze). Email-fallback-resolves-zero independently confirmed (0 shared local parts exist at all). 5 numbers re-derived with differently-structured SQL, 0 mismatches. RULE-008 anomalies intact in silver (297 penny / 17 below-cost / 24217 pre-signup / 54 orphan transfer_outs = B06). Write-scope audit clean; no file-vs-live drift. Warnings: (1) DEF-014 rule-3 impl adds uniqueness+non-NULL guards beyond DEF letter (zero-impact live; propose DEF-014 v1.1); (2) S02 keeps raw as order_total_text not order_total_raw — two raw-naming styles in layer, decide before promotion; (3) single-row aggregates without ORDER BY (bronze-pack precedent, informational); (4) DEF-012 2-char branch permissive by design (canonical SQL; V03 distinct-set assertion is the compensating control).
VERDICT: pending (validated; awaiting Ian QA / ship call)
CORRECTIONS: applied by orchestrator 2026-07-04, both Ian-approved in-session: (1) Warning 2 — S02 raw column renamed order_total_text → order_total_raw (spec <name>_raw convention), view re-executed live, full verify pack V01–V07 re-run and diffed MATCH against all captures; (2) Warning 1 — DEF-014 bumped to v1.1 in grounding/definitions.md (rule-3 exactly-one-match + non-NULL guards codified, dupe_resolution vocabulary added, zero-resolution live finding documented; diff approved by Ian before application). Warnings 3 (single-row aggregates, informational) and 4 (DEF-012 2-char branch is canonical SQL by design) left as-is. Scope amendment order_items-as-14th-view approved by Ian in-session before build.
