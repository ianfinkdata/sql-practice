# Oakhaven Bronze — Ubuntu Rebuild Plan

Status: **DRAFT — for Ian's review, iterating in chat before execution.**
Context: the Windows machine this was originally built on had a hard-drive
failure. This repo was re-cloned onto a fresh Ubuntu 26.04 box
(`ianfinkdata/sql-practice` → `/home/ian/github/sql-practice`). Original build
record: `IMPLEMENTATION_PLAN.md` (repo root), completed/QA'd 2026-07-02.

## The good news first

`oakhaven/data/*.csv` was **always gitignored** (`oakhaven/.gitignore` →
`data/`) — nothing was lost that git would have saved anyway. Generation is
deterministic (fixed seed `oakhaven-v1`, pure stdlib + Faker, no external
data files), so a full rebuild reproduces the same dataset, not an
approximation of it.

## Gaps found vs. the original Windows setup (checked live, 2026-07-13)

| # | Gap | Resolution |
|---|---|---|
| 1 | `oakhaven/data/` doesn't exist | Expected — regenerate via the existing `generate/*.py` scripts. |
| 2 | `common_db.dim_date` (calendar's source, `ddl/02_calendar_copy.sql`) doesn't exist on this MySQL instance | **Decided with Ian 2026-07-13:** drop the `common_db` indirection. Generate `oakhaven.calendar` directly via a recursive CTE — bronze carries only `date_key` + `date`; derived columns (year/month/quarter/week_day/etc.) are deferred to the silver layer, not needed for this rebuild. Range widened to **2018-01-01–2038-12-31 (7,670 rows)**. This is a `DATA_CONTRACT.md` **v1.3** change (§3.8 + acceptance criterion 10) — see Phase 1. |
| 3 | No `faker` module (Python 3.14.4 present; generators are otherwise stdlib-only) | Install into a throwaway venv — doesn't need the full `uv` data-stack open thread from `ubuntu_26.04/docs/install-checklist.md` §4, that's a separate, bigger piece of work. |
| 4 | Load tooling is Windows-only: `load/run_load.ps1`, `CLAUDE.md`'s DB-access section (`C:\Program Files\MySQL\...`, `--defaults-extra-file="C:\Users\ianfi\.my.cnf"`) | Linux equivalents in Phase 4. `CLAUDE.md` gets a Linux connection section added alongside (not replacing) the Windows one, since this repo may still be touched from Windows later. |
| 5 | Credential model differs from what `CLAUDE.md` currently documents | This machine already has `claude@localhost` set up with a vault-held password entered live per session (`ubuntu_26.04` repo, 2026-07-12) — deliberately **no `.my.cnf` file**. Load/QA scripts here use the same live-entry pattern, not a credentials file. |
| 6 | `claude@localhost` only has grants on `oakhaven`/`oakhaven_silver`/`oakhaven_gold` — not global `SUPER`/`SYSTEM_VARIABLES_ADMIN` | Enabling `local_infile` needs root once. Recommend setting it permanently in `mysqld.cnf` (`local_infile=1`) rather than toggling per-load — simpler, and this is a sandboxed practice box, not a hardened one. |

## Phases

### Phase 0 — Environment prep
- `python3 -m venv` (or equivalent) + `pip install faker` — scoped to this rebuild, throwaway.
- Confirm `mysql` client reaches `claude@localhost` (already proven working this session).
- One-time, as root: enable `local_infile` (mysqld.cnf edit + restart, or `SET GLOBAL` if a persistent toggle is preferred instead — decide at execution time).

### Phase 1 — Calendar contract change (v1.3)
- Bump `DATA_CONTRACT.md` `CONTRACT_VERSION` to `1.3`, rewrite §3.8 (drop `common_db` copy, document direct generation, new range/row count, bronze columns = `date_key, date` only).
- Update acceptance criterion 10 in `DATA_CONTRACT.md` §6 and the matching checks in `qa/validation.sql` (`C10.01`–`C10.04`): new row count (7,670), new range, **drop C10.04** entirely (no more `common_db.dim_date` to compare against).
- Write the recursive-CTE calendar build as a new file, `oakhaven/ddl/02_calendar_generate.sql` (replaces `02_calendar_copy.sql` — the copy script no longer applies to this architecture; decide whether to delete or keep it for history/Windows-branch reference).

### Phase 2 — DDL
- Apply `oakhaven/ddl/01_schema.sql` (schema + 14 tables, PKs, FKs, indexes) — unchanged from original.
- Apply the new calendar generator from Phase 1.

### Phase 3 — Regenerate CSVs
- Run `generate/gen_dimensions.py`, `generate/gen_sales.py`, `generate/gen_logistics.py` as-is (pure Python, no platform-specific paths inside them beyond writing into `oakhaven/data/`) — verify each completes and prints its row counts.

### Phase 4 — Load
- `load/load_all.sql`: every `LOAD DATA LOCAL INFILE 'C:/github/sql-practice/oakhaven/data/<table>.csv'` path → `/home/ian/github/sql-practice/oakhaven/data/<table>.csv`.
- Replace `load/run_load.ps1` with a small bash script (`load/run_load.sh`): same shape (enable `local_infile` if not already permanent, run `load_all.sql` via `mysql -u claude -h 127.0.0.1 --local-infile=1`, no `.my.cnf`/`--defaults-extra-file`, password supplied live per this repo's convention — never written to a file or command-line arg visible in `ps`).

### Phase 5 — QA
- Run `qa/validation.sql` (with Phase 1's calendar-check updates) and confirm PASS across the board, matching the original 2026-07-02 verdict (128/130 clean + 1 approved rounding/window-cap exception) minus/plus whatever the calendar change affects.

### Phase 6 — Docs & housekeeping
- Append a decision-log entry to `oakhaven/IMPLEMENTATION_PLAN.md` (Ubuntu rebuild, calendar architecture change, credential model note).
- Add the Linux DB-access section to `CLAUDE.md` (Phase 0/4 details), alongside the existing Windows one.

## Open question before executing

`CLAUDE.md`'s sync protocol says **all work lands on a task branch, merged via PR — no direct commits to main.** This rebuild touches `DATA_CONTRACT.md` (contract version bump) and `oakhaven/` files that the medallion project's own contract calls "never modify" — that rule is scoped to the *downstream medallion agents*, not to this foundational rebuild, but worth being explicit about the distinction in case a future session reads `CLAUDE.md` cold. Recommend this rebuild follows the same task-branch-and-PR discipline as everything else (e.g. `task/oakhaven-ubuntu-rebuild`) rather than committing straight to `main` — confirm before Phase 1 starts.
