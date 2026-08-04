# 3. Tools and Setup


<!-- nav -->
Previous: [2. What Is SQL?](02-what-is-sql.md). Next: [4. Meet Oakhaven](04-meet-oakhaven.md).
<!-- /nav -->

## The idea

Before writing any SQL, you need two things: the practice database
itself (`oakhaven.db`), and a way to open it and run queries against
it. This module walks through getting both set up. It's a one-time
chore — once it's done, every later module just assumes `oakhaven.db`
exists and is sitting in `project/`.

## Building the database

`project/oakhaven.db` is already checked into the repo — if you just
cloned it, you can skip straight to [Opening the
database](#opening-the-database) below. But it's worth building it
yourself at least once: the whole thing is *generated* by a Python
script, deterministically, from a fixed random seed. That means
rebuilding it gets you byte-for-byte the same data every time (same
customers, same messy strings, same row counts) — this matters because
every example and exercise in this course cites exact numbers from
that one deterministic build. If a number you compute doesn't match,
it's a sign to check whether your database has drifted from a fresh
build, not that the numbers in the lesson are wrong.

From the repo root:

```bash
pip install -r project/requirements.txt
python project/build.py
```

> **Using Claude Code or another AI coding assistant?** This repo ships
> a `setup-database` skill (`.claude/skills/setup-database/`) that runs
> all of the steps below for you, handles the virtual-environment
> pitfall automatically, and verifies the result. Just ask it to set up
> the database.

The `build.py` script creates `project/oakhaven.db`, populates all the
bronze tables, and prints a summary when it's done (ending in something
like `ALL HARD CHECKS PASSED`).

### If `pip install` refuses to run (macOS/Linux)

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

### Installing on Windows

The same two commands from the top of this section
(`pip install -r project/requirements.txt` then `python project/build.py`)
usually work as-is in Command Prompt or PowerShell if you installed
Python from [python.org](https://www.python.org/downloads/) with the
"Add python.exe to PATH" option checked. If you'd rather isolate the
install in a virtual environment (recommended, and the same idea as the
macOS/Linux fix above), from the repo root:

**PowerShell:**

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r project/requirements.txt
python project/build.py
```

If activation fails with a message about running scripts being
disabled on the system, PowerShell's execution policy is blocking it.
Run this once in that terminal, then retry the activate command:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**Command Prompt (cmd.exe):**

```bat
python -m venv .venv
.venv\Scripts\activate.bat
pip install -r project/requirements.txt
python project/build.py
```

Either way, you'll know activation worked because the prompt shows
`(.venv)` at the front, and you'll need to re-activate (`.venv\Scripts\Activate.ps1`
or `.venv\Scripts\activate.bat`) each time you open a new terminal.

## Opening the database

Once `project/oakhaven.db` exists, you need something to open it with
and run SQL against it. Two good options — pick whichever fits how you
like to work:

**Option A: the `sqlite3` command-line tool.** Fast, keyboard-driven,
works everywhere. If you don't already have it, it's available via your
OS package manager on Linux (e.g. `apt install sqlite3` on
Debian/Ubuntu) and may already be present on macOS. On Windows it
isn't bundled with the OS — download the "sqlite-tools" zip for your
system from the [official SQLite download
page](https://www.sqlite.org/download.html), unzip it, and either add
that folder to your `PATH` or run `sqlite3.exe` from inside it.
Once installed:

```bash
sqlite3 project/oakhaven.db
```

drops you into an interactive prompt where you can type SQL directly.
This course's SQL examples are written assuming this tool, but the SQL
itself is identical no matter what client you use. For the full set of
CLI tips (readable output formatting, useful dot-commands, common
gotchas), see **`project/docs/sqlite_cli_guide.md`** — worth a skim
before Tier 1.

**Option B: a GUI like DB Browser for SQLite or Beekeeper Studio.** Free
graphical applications — open the `.db` file in a window, let you
browse tables, run SQL in a query editor, and see results in a
spreadsheet-like grid. Good if you prefer a visual interface over a
terminal, or if you'd rather skip installing Python entirely and just
open the committed `project/oakhaven.db` directly. Download DB Browser
at **https://sqlitebrowser.org/** or Beekeeper Studio at
**https://www.beekeeperstudio.io/**.

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

- `project/oakhaven.db` is already committed to the repo — clone and go
  if you just want to query it.
- You can also generate it yourself, byte-identically:
  `pip install -r project/requirements.txt` then `python project/build.py`.
- If `pip install` fails with "externally-managed-environment" (macOS/Linux),
  create a virtual environment first (`python3 -m venv .venv && source
  .venv/bin/activate`) and install inside it. On Windows, use `python -m venv .venv`
  and `.venv\Scripts\Activate.ps1` (PowerShell) or `.venv\Scripts\activate.bat` (cmd.exe).
- Open `project/oakhaven.db` with the `sqlite3` CLI (on Windows, grab
  it from https://www.sqlite.org/download.html), DB Browser for SQLite
  (https://sqlitebrowser.org/), or Beekeeper Studio
  (https://www.beekeeperstudio.io/) — your choice.
- `project/docs/sqlite_cli_guide.md` is your reference for CLI-specific
  tips once you start running real queries.

---

<!-- nav -->
Previous: [2. What Is SQL?](02-what-is-sql.md). Next: [4. Meet Oakhaven](04-meet-oakhaven.md).
<!-- /nav -->
