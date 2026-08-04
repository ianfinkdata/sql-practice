# AGENTS.md

Instructions for any AI assistant (Claude Code, Codex, Copilot, or
otherwise) working in this repository. Tool-agnostic on purpose.

## What this repo is

SQL Practice is a self-paced SQL curriculum (beginner → master) built
around **Oakhaven**, a fictional outdoor-gear retailer's SQLite
database. The whole repo is one real, small medallion-architecture
pipeline (bronze → silver → gold) that a learner generates locally with
one command and no Python authorship of their own. See the root
[`README.md`](README.md) for the full picture; see
[`project/docs/data_dictionary.md`](project/docs/data_dictionary.md)
and [`project/docs/facts_sheet.md`](project/docs/facts_sheet.md) for
the exact schema and real, verified data facts.

## The one hard rule: never invent a number

Every SQL example, every exercise solution, and every claimed query
result anywhere in this repo (`curriculum/`, `exercises/`, `portfolio/`,
`project/docs/`) must be an **actual, verified** output of running that
query against a real `oakhaven.db` — not a plausible-looking guess. If
you write "returns 12 rows" or a sample output table, you must have
just run the query and be copying its real output.

```bash
sqlite3 project/oakhaven.db -header -column "SELECT ...;"
```

If `project/oakhaven.db` doesn't exist yet, build it first:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r project/requirements.txt
python project/build.py
```

Generation is fully deterministic (fixed seed, pinned Faker version —
see `project/build_lib/config.py`), so a fresh build always produces
byte-identical data. If a number you're citing doesn't match
`project/docs/facts_sheet.md`, trust the live query over the doc and
flag the doc as stale.

## `project/oakhaven.db` is precious — treat it as read-only

The database file is committed to the repo at `project/oakhaven.db`,
so it doesn't have to be regenerated — but anyone can regenerate it
byte-identically. When working in this repo (especially if multiple
agents or processes might touch it concurrently):

- Only run `SELECT` (and read-only introspection: `EXPLAIN QUERY PLAN`,
  `.schema`, `PRAGMA table_info`) against `project/oakhaven.db`.
- Never run `CREATE`, `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE`, or
  open a transaction against it. If a lesson needs to demonstrate DDL,
  transactions, or indexing hands-on (this happens in Tier 4), work
  against a scratch copy — `cp project/oakhaven.db /tmp/scratch.db` (or
  similar) — and discard it afterward.
- If a curriculum module shows `CREATE VIEW ...` as an example, verify
  correctness by running just the inner `SELECT` standalone; don't
  execute the `CREATE VIEW` against the shared file.

## Layer conventions, if you're touching `project/`

- **Bronze** (`project/bronze/`) is raw and deliberately messy.
  Messiness is a *feature*, not a bug to silently fix — don't "clean up"
  bronze generation logic without updating the curriculum/exercises
  that teach against the specific messiness patterns it currently
  produces.
- **Silver** (`project/silver/`) views clean/standardize/derive from
  bronze. They should surface data-quality problems (e.g. flag orphan
  foreign keys, recompute untrustworthy totals) rather than silently
  dropping rows.
- **Gold** (`project/gold/`) views are business-ready and star-schema
  shaped, built on top of silver — never directly on bronze.
- All three layers are implemented as `.sql` files (`CREATE VIEW` for
  silver/gold) read and executed by `project/build.py` via
  `executescript()` — not embedded as Python string literals. This
  keeps the SQL itself portable and reusable (see `portfolio/`).
- If you change the bronze schema, row counts, or seed, you must
  regenerate `project/docs/facts_sheet.md` and re-verify every
  downstream curriculum/exercise/portfolio file that cites specific
  numbers — this is a wide-blast-radius change, do it deliberately.

## Content conventions

**Curriculum modules** (`curriculum/0X-tier/NN-topic-slug.md`): plain-
English concept explainer first, then why it matters, then syntax, then
2-4 verified runnable examples against real Oakhaven data, then common
mistakes, then key takeaways. Explain the idea before the code —
understanding first, typing second.

**Exercises** (`exercises/0X-tier/NN-topic-slug.md`, same slug as its
curriculum module): 4-6 prompts of increasing difficulty, each with a
`<details><summary>Show solution</summary>` block containing verified
SQL and real output.

**Portfolio patterns** (`portfolio/0N-category/pattern-name.sql`):
standalone, engine-agnostic, heavily commented — pattern name, problem
it solves, when to use it, a real verified example, and a portability
note for Snowflake/BigQuery/Databricks/Postgres. Should make sense to
someone who's never heard of Oakhaven.

## Adding a new tier or module

1. Update the frozen module list in the relevant tier's `README.md` and
   in `curriculum/README.md`.
2. Write the curriculum module and its matching exercise file together,
   so the lesson and the answer key can't drift apart.
3. Verify every SQL statement against a real, freshly-built
   `oakhaven.db` before writing its output into markdown.
4. If the module teaches a genuinely reusable pattern (not just an
   Oakhaven-specific query), consider whether it belongs in
   `portfolio/` too.
