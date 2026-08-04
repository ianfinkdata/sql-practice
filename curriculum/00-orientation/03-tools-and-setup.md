# 3. Tools and Setup

## The idea

Before writing any SQL, you need two things: the practice database
itself (`oakhaven.db`), and a way to open it and run queries against
it. This module walks through getting both set up. It's a one-time
chore — once it's done, every later module just assumes `oakhaven.db`
exists and is sitting in `project/`.

## Building the database

The database isn't checked into the repo as a static file you just
download — it's *generated* by a Python script, deterministically,
from a fixed random seed. That means if you rebuild it, you'll get
byte-for-byte the same data every time (same customers, same messy
strings, same row counts). This matters because every example and
exercise in this course cites exact numbers from that one deterministic
build — if your database doesn't match, it's because you haven't built
it yet, not because the numbers are wrong.

From the repo root:

```bash
pip install -r project/requirements.txt
python project/build.py
```

The `build.py` script creates `project/oakhaven.db`, populates all the
bronze tables, and prints a summary when it's done (ending in something
like `ALL HARD CHECKS PASSED`).

### If `pip install` refuses to run

On modern Debian/Ubuntu systems, running `pip install` directly against
your system Python often fails with an error like:

```
error: externally-managed-environment
```

This is Debian/Ubuntu protecting your system Python from having random
packages installed into it. The fix is to create a **virtual
environment** — an isolated, project-local copy of Python where `pip
install` is safe to run — and install into that instead:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r project/requirements.txt
python project/build.py
```

`source .venv/bin/activate` needs to be re-run (from the repo root)
each time you open a new terminal and want to use this environment.
You'll know it worked because your shell prompt will show `(.venv)` at
the front.

## Opening the database

Once `project/oakhaven.db` exists, you need something to open it with
and run SQL against it. Two good options — pick whichever fits how you
like to work:

**Option A: the `sqlite3` command-line tool.** Fast, keyboard-driven,
works everywhere. If you don't already have it, it's available via
your OS package manager (e.g. `apt install sqlite3` on Debian/Ubuntu,
or it may already be present on macOS). Once installed:

```bash
sqlite3 project/oakhaven.db
```

drops you into an interactive prompt where you can type SQL directly.
This course's SQL examples are written assuming this tool, but the SQL
itself is identical no matter what client you use. For the full set of
CLI tips (readable output formatting, useful dot-commands, common
gotchas), see **`project/docs/sqlite_cli_guide.md`** — worth a skim
before Tier 1.

**Option B: DB Browser for SQLite.** A free graphical application —
opens the `.db` file in a window, lets you browse tables, run SQL in a
query editor, and see results in a spreadsheet-like grid. Good if you
prefer a visual interface over a terminal. Download it at
**https://sqlitebrowser.org/**.

Either is fine. Some people use both — the CLI for quick one-off
queries, a GUI for browsing table structure. Nothing in this course
depends on which one you pick.

## A sanity check

However you connect, confirm the database is really there and populated:

```bash
sqlite3 project/oakhaven.db "SELECT COUNT(*) FROM bronze_sales;"
```

This should print `12000`. If you get an error about no such table, or
a different number, re-run `python project/build.py` and try again.

## Key takeaways

- The practice database is *generated*, not downloaded:
  `pip install -r project/requirements.txt` then `python project/build.py`.
- If `pip install` fails with "externally-managed-environment," create
  a virtual environment first (`python3 -m venv .venv && source
  .venv/bin/activate`) and install inside it.
- Open the resulting `project/oakhaven.db` with either the `sqlite3`
  CLI or DB Browser for SQLite (https://sqlitebrowser.org/) — your
  choice.
- `project/docs/sqlite_cli_guide.md` is your reference for CLI-specific
  tips once you start running real queries.
