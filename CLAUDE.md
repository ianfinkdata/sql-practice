# Agent Contract — sql-practice / Oakhaven Medallion Project

You are operating inside Ian's agent operating system, instantiated from `agent-starter-kit`
for THIS repo. All agents — main session and sub-agents — follow this contract.
Project goal and phases: `IMPLEMENTATION_PLAN.md` (repo root).

**Project in one line:** treat the `oakhaven` MySQL schema as the BRONZE layer; document it
fully, build SILVER (cleaned/conformed views) and GOLD (business marts) on top, and use the
gold queries to drive exploratory report templates. Every published query must be directly
runnable in MySQL and reproduce its captured output exactly.

## Grounding rules
- Only use metric names, business logic, and SQL patterns defined in `grounding/definitions.md`.
  If a needed definition is missing, STOP and request one. Never invent business logic.
- Cite the definition ID (e.g., `DEF-004`) in every output that uses it.
- Scan `grounding/index.md` first to locate context; load only the entries you need.
- Read `grounding/lessons.md` before starting any task and apply every applicable rule.
- Layer rules (naming, what belongs in bronze/silver/gold): `grounding/medallion-spec.md`.
- Report anatomy and visual rules: `grounding/report-spec.md`.
- Physical schema truth: `grounding/schema.md` (live-verified DDL + row counts). The upstream
  data generator contract is `oakhaven/DATA_CONTRACT.md` — read-only background; the database
  itself is the bronze source of truth.

## Scope rules
- Do only the task in the brief (`process/briefs/`). Adjacent work goes under
  "Suggested follow-ups" — do not do it.
- Never edit `grounding/definitions.md` directly. Propose changes as a diff for Ian's approval.
- Never modify anything under `oakhaven/` (generators, CSVs, DDL) — that project is contract-
  governed and shipped. This project only READS the `oakhaven` schema.
- Sub-agents use only their allowlisted tools. If a task needs more, escalate.

## Database access (local MySQL, Windows or Linux)

**Windows** (original machine):
- Connect EXACTLY like this (Windows mysql does NOT auto-read `~/.my.cnf`):
  `& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven -e "<query>"`
  Details and file-based execution: `process/mysql-setup.md`.
- NEVER read, print, or copy the contents of `.my.cnf`; never place credentials in
  prompts, files, or logs.

**Linux** (Ubuntu, rebuilt 2026-07-13 — see `oakhaven/UBUNTU_REBUILD.md`):
- No `.my.cnf` file — deliberately (see the `ubuntu_26.04` repo's MySQL setup).
  `claude@localhost` connects over `127.0.0.1:3306`; the password is entered
  live per session, never written to a file or committed anywhere.
  `mysql -u claude -h 127.0.0.1 --batch oakhaven -e "<query>"`
- `SET GLOBAL local_infile = 1` needs root (`claude` only has grants on the
  three oakhaven schemas, not `SUPER`/`SYSTEM_VARIABLES_ADMIN`) — a one-time,
  human-run step, not something an agent does unattended.
- Same rule as Windows: never place credentials in prompts, files, or logs.
- Write scope is a hard boundary:
  - `oakhaven` schema: **READ ONLY.** No INSERT/UPDATE/DELETE/DDL, ever.
  - `oakhaven_silver`, `oakhaven_gold` schemas: CREATE SCHEMA / CREATE OR REPLACE VIEW /
    DROP VIEW only, and only when the task brief calls for it. No base tables without escalation.
  - Any other schema: off limits.
- Add `LIMIT` to exploratory queries. Published queries follow the reproducibility rules
  in `grounding/medallion-spec.md` §Reproducibility (deterministic ORDER BY, captured outputs).

## Output rules
Every deliverable ends with a Handoff Block:

```
WHAT: <one-line summary>
GROUNDING: <DEF IDs and index entries used>
ASSUMPTIONS: <anything inferred rather than specified>
CONFIDENCE: <high|medium|low + reason>
QA HINTS: <2–3 things the human reviewer should check first>
```

Prefer diffs over rewrites. Prefer one file changed over three.
Deliverables land in `outputs/TASK-<id>/`; Ian promotes approved work to `medallion/`
(SQL layers) or `reports/` (report templates) per the plan.

## Escalation triggers (stop and ask)
- Missing, ambiguous, or contradicted definition
- Two grounded sources conflict (e.g., DATA_CONTRACT vs live database)
- Task requires writing anywhere outside the allowed silver/gold view scope
- A published query's re-run output does not match its captured output
- Scope exceeds the brief by more than 2x

## Logging duties
- Append a session entry to `process/memory_log.md` (task ID, brief, output location,
  verdict: pending).
- Add or update the relevant `grounding/index.md` entry.

## Sync & branching protocol
- This repo is git-managed (`ianfinkdata/sql-practice`). **All work lands on a task branch
  (`task/<TASK-id>`) and merges to main through a PR — no direct commits to main.**
  (Ian's standing instruction, 2026-07-04. Applies to everything: outputs, process files,
  grounding, and especially `grounding/definitions.md`.) The PR is the approval artifact.
- Changes to `grounding/definitions.md` are additionally presented as a diff in-session
  for approval BEFORE the PR is opened.
- Never push or open PRs without Ian asking for the work to ship.
- NEVER commit credentials. `.my.cnf` lives outside the repo.

## Delegation
- Dataset documentation / profiling → `data-documenter` sub-agent
- SQL generation (bronze/silver/gold) → `sql-builder` sub-agent
- Review of any SQL before human QA → `sql-validator` sub-agent
- Report templates and exploratory reports → `report-designer` sub-agent
- Weekly improvement loop → `retrospective` sub-agent (Ian applies its diffs)
- A builder never validates its own work. Validator output goes to the human, not back
  to silent auto-fix loops.
