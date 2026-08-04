---
name: setup-database
description: Use when the user wants to set up, build, generate, rebuild, or regenerate the sql-practice project database — phrases like "set up the database", "build oakhaven", "generate the practice database", "run the build script", "get started with sql-practice", "python project/build.py isn't working", or any pip/venv/faker install trouble in this repo. Creates a local venv, installs the pinned Faker dependency, runs project/build.py, and verifies the resulting project/oakhaven.db.
---

# Set up the Oakhaven practice database

`project/oakhaven.db` is never committed to this repo — every learner
generates their own copy. Generation is deterministic (fixed seed,
pinned Faker version in `project/build_lib/config.py` /
`project/requirements.txt`), so a correctly-built database is
byte-identical no matter who builds it or when.

Do these steps yourself with the Bash tool — don't just print them for
the user to copy/paste. Run everything from the repo root.

## 1. Confirm you're at the repo root

```bash
test -f project/build.py && test -f project/requirements.txt && echo OK
```

If this fails, `cd` to the repo root (the directory containing
`project/`, `curriculum/`, etc.) before continuing.

## 2. Check whether a database already exists

```bash
test -f project/oakhaven.db && echo "exists" || echo "missing"
```

If it already exists, ask the user whether they want to rebuild it
(harmless and safe — `build.py` deletes and recreates it, and the
result is byte-identical) or leave it as-is. Skip to step 6 if they
want to leave it alone.

## 3. Create an isolated virtual environment

Don't install into system Python — on modern Debian/Ubuntu this fails
outright (`error: externally-managed-environment`, PEP 668), and on any
system it risks version drift against the pinned Faker version.

```bash
python3 -m venv .venv
```

If `python3` isn't found, try `python` instead. If neither exists,
stop and tell the user they need Python 3.9+ installed before
continuing — don't attempt a system-wide install on their behalf.

## 4. Install the pinned dependency

Call the venv's `pip` directly by path — no need to `source activate`
first (activation is a shell-interactive convenience, not required for
running one-off commands):

```bash
.venv/bin/pip install -q -r project/requirements.txt
```

On Windows-style paths this would be `.venv\Scripts\pip.exe`, but this
skill assumes a POSIX shell; if the Bash tool is running on Windows via
WSL/Git Bash the `.venv/bin/...` form still applies.

## 5. Build the database

```bash
.venv/bin/python project/build.py
```

This prints a build summary ending in `ALL HARD CHECKS PASSED` and
takes roughly 30-60 seconds. If it fails, read the traceback, fix the
underlying cause if it's something you can address (e.g. a stale
partial `.venv` — remove it with `rm -rf .venv` and retry from step 3),
and don't report success until it actually passes.

## 6. Verify

```bash
sqlite3 project/oakhaven.db "SELECT COUNT(*) FROM bronze_sales;"
```

This must print `12000`. Also spot-check that the layered views exist:

```bash
sqlite3 project/oakhaven.db ".tables"
```

Expect 5 `bronze_*` tables, 5 `silver_*` views, 4 `dim_*` views,
`fact_sales`, and 3 `agg_*` views (18 objects total).

## 7. Report back

Tell the user:
- The database is built and verified at `project/oakhaven.db`.
- It won't show up in `git status` — it's gitignored by design.
- Where to go next: `curriculum/00-orientation/` if they haven't started
  the curriculum yet, or straight to whichever tier they're working on.

If anything failed and you couldn't resolve it, report exactly what
failed and at which step — don't guess at a fix you haven't verified.
