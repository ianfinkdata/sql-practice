# SQL Practice

> A complete, self-paced path from your very first `SELECT` to designing
> warehouse-scale dimensional models — paired with a small, real
> **bronze → silver → gold** SQLite project you generate yourself with
> one command.

SQL Practice is built around one idea: **learning SQL should feel like a
patient mentor sitting next to you**, not a reference manual dropped on
your desk. Every lesson explains the concept in plain English first and
only reaches for code once you're ready to write it.

It's also built to be **maximally portable**: no database server to
install, no credentials to manage, no OS-specific setup, and no Python to
write. Everything here is either Markdown or SQLite — the kind of thing
that runs the same on a laptop, in a CI runner, or handed to an AI
assistant. Clone the repo, run one command, and you have a real,
intentionally-messy company database sitting in a single file.

---

## What's inside

| Part | What it is | Where |
|---|---|---|
| **Curriculum** | Beginner → master, six tiers | [`curriculum/`](curriculum/) |
| **Exercises** | Hands-on practice, tier-paired with the curriculum | [`exercises/`](exercises/) |
| **Applied project** | Oakhaven: a fictional retailer, modeled bronze → silver → gold, as one SQLite file you generate | [`project/`](project/) |
| **Portfolio** | A standalone, engine-agnostic library of medallion/star-schema query patterns — the takeaway artifact | [`portfolio/`](portfolio/) |
| **AI assistant guide** | Tool-agnostic instructions for any AI helping in this repo | [`AGENTS.md`](AGENTS.md) |
| **Web version** | Browsable GitHub Pages site | [`docs/`](docs/) (enable Pages on your fork, or browse the source directly) |

---

## Curriculum

Six tiers, each building on the last:

| Tier | Name | Focus |
|---|---|---|
| 0 | [Orientation](curriculum/00-orientation/) | What a database is, no code required; generating the practice database |
| 1 | [Beginner](curriculum/01-beginner/) | Asking a database simple questions |
| 2 | [Intermediate](curriculum/02-intermediate/) | Combining tables, summarizing, cleaning messy real-world data |
| 3 | [Advanced](curriculum/03-advanced/) | Window functions, CTEs, recursive CTEs, time intelligence — the medallion thread begins |
| 4 | [Expert](curriculum/04-expert/) | DDL, transactions, views, indexes, query optimization |
| 5 | [Master](curriculum/05-master/) | Dimensional modeling, star schema design, and the medallion architecture, end to end |

Start at [`curriculum/00-orientation/`](curriculum/00-orientation/) if
you're brand new, or jump to any tier you're ready for — see
[`curriculum/README.md`](curriculum/README.md) for the full module list.

Starting at Tier 3, lessons lean on the applied project below instead of
hypothetical tables — you read the concept, then go run it against a
real database. Every example and every exercise solution in this
curriculum was actually run against `oakhaven.db` and its output
verified; nothing is invented.

---

## The applied project

[`project/`](project/) is **Oakhaven** — a small, fictional outdoor-gear
retailer. You generate its database yourself, deterministically, with:

```bash
python3 -m venv .venv && source .venv/bin/activate   # see note below
pip install -r project/requirements.txt
python project/build.py
```

This produces `project/oakhaven.db` — a real medallion pipeline at a
scale you can actually hold in your head:

- **Bronze** — five raw tables (`bronze_customers`, `bronze_products`,
  `bronze_employees`, `bronze_sales`, `bronze_calendar`), generated with
  [Faker](https://faker.readthedocs.io/) and deliberately messy:
  inconsistent state/phone formatting, mixed-format booleans, an
  untrustworthy order-total column, orphan foreign keys, and more.
  `bronze_calendar` is the one exception — a clean, manufactured date
  spine spanning **2018-01-01 through 2038-12-31**, built entirely in
  SQL with a recursive CTE, no Python loop involved.
- **Silver** — views that clean, standardize, and derive (`silver_*`).
- **Gold** — business-ready, star-schema-shaped views: four dimensions
  and a `fact_sales` table at order-line grain, plus ready-to-query
  aggregates (`agg_monthly_sales_by_category`, `agg_customer_ltv`,
  `agg_daily_sales`, including zero-order days via a date-spine join).

Generation is fully deterministic (a fixed random seed and a pinned
Faker version), so every learner's `oakhaven.db` is byte-identical —
exercise answer keys stay valid no matter who runs the build. The `.db`
file itself is **not** committed to the repo; you generate it in one
command as your first Tier 0 exercise.

**Note on `pip install`:** modern Debian/Ubuntu systems refuse
`pip install` outside a virtual environment with an
`externally-managed-environment` error. Creating a venv first (as shown
above) avoids this — see
[`curriculum/00-orientation/03-tools-and-setup.md`](curriculum/00-orientation/03-tools-and-setup.md)
for the full walkthrough.

See [`project/docs/data_dictionary.md`](project/docs/data_dictionary.md)
for the full schema and [`project/docs/erd.md`](project/docs/erd.md) for
an entity-relationship diagram.

---

## The portfolio

[`portfolio/`](portfolio/) is the repo's explicit takeaway: a standalone
library of annotated, engine-agnostic SQL patterns — deduplication,
orphan-FK detection, silver-style cleaning, recursive-CTE calendars,
SCD Type 1/2, star-schema fact tables, cohort analysis, LTV, and more —
each verified against Oakhaven but written to be lifted whole into a
different project on a different SQL engine, with portability notes for
Snowflake, BigQuery, Databricks, and Postgres. Think of it as "a recipe
for building most medallion lakehouses."

---

## How to use this repo

### If you're learning on your own
1. Read [`curriculum/00-orientation/`](curriculum/00-orientation/) and
   generate `oakhaven.db`.
2. Work tier by tier. Each module ends with matching exercises.
3. From Tier 3 on, query [`project/`](project/) alongside the lesson.
4. Once you've finished Tier 5, browse [`portfolio/`](portfolio/) as a
   reference you can keep using long after this repo.

### If you want the web version
Enable GitHub Pages on your fork pointing at `docs/` — see
[`docs/INSTRUCTIONS.md`](docs/INSTRUCTIONS.md) — or just open
[`docs/index.html`](docs/index.html) directly in a browser.

---

## Project structure

```
sql-practice/
├── README.md                  ← you are here
├── AGENTS.md                  ← instructions for AI assistants working in this repo
├── curriculum/                ← the beginner→master path, tier by tier
│   ├── 00-orientation/
│   ├── 01-beginner/
│   ├── 02-intermediate/
│   ├── 03-advanced/
│   ├── 04-expert/
│   └── 05-master/
├── exercises/                 ← practice prompts, tier-paired with the curriculum
├── project/                   ← Oakhaven: generate a real bronze/silver/gold SQLite database
│   ├── build.py                    ← the one command: python project/build.py
│   ├── requirements.txt
│   ├── build_lib/                  ← precooked Faker-based generators (no Python authorship needed)
│   ├── bronze/  silver/  gold/     ← schema + view SQL, the actual "recipe" files
│   └── docs/                       ← data dictionary, ERD, facts sheet, sqlite3 CLI guide
├── portfolio/                  ← standalone, engine-agnostic medallion/star-schema pattern library
└── docs/                       ← GitHub Pages site
    ├── index.html
    ├── styles.css
    └── INSTRUCTIONS.md
```

---

## Resources

**Opening the project database**
- [DB Browser for SQLite](https://sqlitebrowser.org/) — free GUI, works
  on Windows/Mac/Linux, no install expertise required.
- [`sqlite.org/lang.html`](https://sqlite.org/lang.html) — SQLite's own
  SQL language reference.
- [`project/docs/sqlite_cli_guide.md`](project/docs/sqlite_cli_guide.md) —
  a quick guide to the `sqlite3` command-line tool: dot-commands,
  one-liner syntax, common gotchas.

**Videos on the topics that trip people up most**
- [7 Window Functions MASTERED in 17 Minutes](https://youtu.be/vlltZIgn284)
- [What are CTEs in SQL, in 13 Minutes](https://www.youtube.com/watch?v=XUxBKO25ZyA)
- [Advanced SQL Tutorial: Subqueries](https://www.youtube.com/watch?v=m1KcNV-Zhmc)

**Web-based SQL practice exercises**
- [SQL Zoo](https://www.sqlzoo.net/wiki/SQL_Tutorial)
- [w3schools](https://www.w3schools.com/sql/)

Have a resource that belongs here? Add it — this list is meant to grow.

---

## A note on philosophy

You will notice the curriculum talks *a lot* and shows code *a little*.
That's deliberate. Most people don't get stuck on syntax — they get
stuck on the *idea*. Once the idea is clear, the syntax is a five-minute
lookup. SQL Practice optimizes for understanding first, typing second —
and every number you'll read along the way was actually queried out of
a real database, not made up for the sake of a tidy example.

---

*Contributions and corrections welcome.*
