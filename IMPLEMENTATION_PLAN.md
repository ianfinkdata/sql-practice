# Oakhaven Medallion Project — Implementation Plan

Version: 1.0 · 2026-07-04 · Owner: Ian · Status: **approved by Ian 2026-07-04** (decisions A1–A6 as written; definitions registry approval rides on the setup PR review)

## 1. Goal

Treat the live `oakhaven` MySQL schema (14 tables, ~420k rows, deliberately dirty analytical
columns) as the **bronze layer**. Deliver:

1. **Full dataset documentation** — data dictionary + per-column profiles + dirt census.
2. **Bronze queries** — a source-of-truth baseline pack: profiling and reconciliation queries
   against the raw tables, with captured outputs that any future work must tie back to.
3. **Silver layer** — `oakhaven_silver` schema of cleaned, typed, conformed VIEWS (1:1 with
   bronze tables; flag, never drop).
4. **Gold layer** — `oakhaven_gold` schema of business-ready VIEWS (facts, dims, marts) with
   business logic applied per approved definitions.
5. **Report design templates** — a reusable exploratory-report template spec plus three
   working exploratory reports (self-contained HTML with embedded visuals) fed exclusively
   by gold/bronze query outputs.

Acceptance bar for every published query: **run it verbatim in MySQL and get byte-identical
output to the captured example.** The dataset is deterministic (seed `oakhaven-v1`), so this
is achievable if queries follow the reproducibility rules in `grounding/medallion-spec.md`.

## 2. Verified starting state (checked live 2026-07-04)

- `oakhaven` schema exists on local MySQL80 with all 14 tables at exact contract counts:
  orders 60,000 · order_items 156,190 · payments 66,663 · shipments 29,784 ·
  inventory_movements 90,000 · returns 5,010 · customers 12,000 · calendar 4,748 ·
  products 850 · promotions 70 · suppliers 45 · product_categories 24 · stores 13 ·
  employees 240.
- Order statuses: completed 55,917 · cancelled 1,689 · refunded 2,383 · pending 11.
  Channels: STORE 32,819 · WEB 27,181. Window: 2019-01-01 08:48:34 → 2026-06-30 21:34:10.
- Repo is on branch `oakhaven-practice-db` (PR #51). This project's files are added to the
  working tree; committing/pushing is Ian's call.
- Live DDL for all 14 tables is snapshotted in `grounding/schema.md`.

## 3. Architecture decisions (approve or veto these)

| # | Decision | Rationale |
|---|---|---|
| A1 | Bronze = the `oakhaven` schema **as-is**; no bronze copies. Bronze deliverable is a query pack + captured outputs, not new objects. | The DB is already the immutable, regenerable source of truth (DATA_CONTRACT v1.2). |
| A2 | Silver and gold are **VIEWS** in new schemas `oakhaven_silver` / `oakhaven_gold`, not materialized tables. | Views can't drift from bronze; deterministic data ⇒ deterministic view output; rebuild = rerun one DDL script. |
| A3 | Silver preserves grain and rows: **flag, don't filter**. Sentinels → NULL + flag column; near-dupes get `canonical_customer_id`, not deletion. | Bronze↔silver row-count reconciliation stays trivial; nothing silently disappears. |
| A4 | Gold applies business logic per `grounding/definitions.md` only (revenue statuses, net revenue, AOV, return rates, margins, fulfillment). | Grounding discipline — no invented logic in the layer stakeholders read. |
| A5 | Reports are **self-contained HTML** (inline CSS/JS, data embedded from captured query outputs), one file per report, plus a written template spec. | Zero infrastructure to view; maps 1:1 to gold queries; PBIR/Power BI versions are a natural DLC follow-up using Ian's pbi-cli stack. |
| A6 | The `claude` MySQL user is used with a contract-level restriction (CLAUDE.md): read-only on `oakhaven`, view-DDL only on the two new schemas. | Matches existing local setup; the boundary is enforced by contract + validator checks rather than a new DB user. |

## 4. Phases and task briefs

Workflow per task: brief → plan → ground → execute (builder) → machine verify (validator)
→ human QA (Ian) → log. Briefs live in `process/briefs/`.

| Task | Deliverable | Owner agent | Depends on |
|---|---|---|---|
| TASK-20260704-01 Dataset documentation | `outputs/TASK-20260704-01/DATA_DICTIONARY.md` — per table: purpose, grain, columns (type, nullability, dirt patterns present), relationships, row counts, per-column profiles for dirty columns | data-documenter | — |
| TASK-20260704-02 Bronze baseline pack | `outputs/TASK-20260704-02/bronze/*.sql` + `EXPECTED_OUTPUTS.md` — row counts, PK/FK integrity, status/channel/enum censuses, date-window checks, dirt census (D1–D25), revenue ground-truth totals | sql-builder → sql-validator | 01 |
| TASK-20260704-03 Silver layer | `outputs/TASK-20260704-03/silver/ddl/*.sql` (schema + views) + verification queries + captured outputs | sql-builder → sql-validator | 02 + approved DEFs |
| TASK-20260704-04 Gold layer | `outputs/TASK-20260704-04/gold/ddl/*.sql` (facts/dims/marts) + business queries + captured outputs | sql-builder → sql-validator | 03 |
| TASK-20260704-05 Report templates | `outputs/TASK-20260704-05/reports/` — template spec instantiation + 3 exploratory HTML reports (Sales Explorer, Product & Category Explorer, Data Quality Explorer) | report-designer → sql-validator (data lineage check) | 04 |

Promotion on Ian's approval: SQL layers → `medallion/{a_bronze,b_silver,c_gold}/`,
documentation → `medallion/_docs/`, reports → `reports/`.

## 5. Definitions gate (Phase 2 — blocking)

`grounding/definitions.md` is seeded as **DRAFT v0.1** with DEF-001…DEF-018 (rounding law,
revenue recognition, cleaning rules, dedupe rule, report metrics). **Ian must approve or
amend these before TASK-03 (silver) starts.** TASK-01 and TASK-02 only need DEF-001/002/003
(they measure; they don't transform). Missing-definition discoveries during any task stop
work and produce a proposed diff.

## 6. Reproducibility rules (summary — normative text in medallion-spec.md)

- Every published query: deterministic `ORDER BY` (full tie-break), no `LIMIT` without
  `ORDER BY`, `ROUND()` on any derived decimal shown, no session-dependent functions
  (`NOW()`, `RAND()`, timezone-sensitive casts).
- Captured outputs are produced by actually executing the query via
  `mysql --batch` and pasted verbatim — never hand-written.
- Validator re-executes every query and diffs against the captured output; any mismatch
  is an automatic FAIL.

## 7. Risks / open items

- **State-value mapping (DEF-012)** and payment-method mapping (DEF-013) enumerate variants
  discovered in TASK-02's census; the DEF entries get their final mapping tables then
  (diff → Ian approval) before silver builds on them.
- Near-dupe resolution (DEF-014) depends on phone/email normalization quality; unresolved
  candidates are flagged, not guessed.
- `calendar` covers 2019–2031 (wider than facts) — gold date spine must constrain to the
  business window or trend charts get empty tails.
- Repo branch: new files currently sit on `oakhaven-practice-db`; decide whether this
  project ships on that PR, a new branch, or after #51 merges.

## 8. Suggested follow-ups (out of scope now)

- Power BI PBIR versions of the three reports via pbi-cli (strong fit with existing skills).
- sql-trainer exercise integration against silver/gold.
- Materialization + refresh script if view performance ever matters (it shouldn't at 420k rows).
