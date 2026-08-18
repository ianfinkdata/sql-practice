# SQL Practice

> **BLUF (Bottom Line Up Front):** SQL Practice is a zero-dependency, self-paced curriculum (Beginner → Master) built around **Oakhaven**, a real 3-tier medallion SQLite pipeline (`bronze → silver → gold`) pre-built and committed as `project/oakhaven.db`. Clone and query directly in any SQLite GUI with zero setup.

<!-- nav -->
[📖 Table of Contents](README.md) | [⏭️ Next: Tier 0 Orientation](curriculum/00-orientation/README.md)
<!-- /nav -->

> A complete, self-paced path from your very first `SELECT` to designing
> warehouse-scale dimensional models — paired with a small, real
> **bronze → silver → gold** SQLite database ready to query immediately.

SQL Practice is built around one idea: **learning SQL should feel like a
patient mentor sitting next to you**, not a reference manual dropped on
your desk. Every lesson explains the concept in plain English first and
only reaches for code once you're ready to write it.

It's also built to be **maximally portable**: no database server to
install, no credentials to manage, no OS-specific setup, and no Python to
write. Everything here is either Markdown or SQLite — the kind of thing
that runs the same on a laptop, in a CI runner, or handed to an AI
assistant. The practice database, `project/oakhaven.db`, is committed
to the repo — clone it and open the file directly in any SQLite GUI, no
build step required. (Want to generate it from scratch anyway? See the optional [Python Generation Guide](curriculum/00-orientation/03-tools-and-setup.md#building-the-database-yourself-optional).)

---

## What's inside

| Part | What it is | Where |
|---|---|---|
| **Curriculum** | Beginner → master, six tiers | `curriculum/` |
| **Exercises** | Hands-on practice, tier-paired with the curriculum | `exercises/` |
| **Applied project** | Oakhaven: a fictional retailer, modeled bronze → silver → gold as a ready-to-query SQLite database | `project/` |
| **Portfolio** | A standalone, engine-agnostic library of medallion/star-schema query patterns — the takeaway artifact | `portfolio/` |
| **Power BI (PBIP)** | `.pbip` semantic models, TMDL tooling, Python scripts, and a pipeline lineage engine | `pbip/` |
| **AI assistant guide** | Tool-agnostic instructions for any AI helping in this repo | `AGENTS.md` |
| **Web version** | Browsable GitHub Pages site | `docs/` (enable Pages on your fork, or browse the source directly) |

---

## Curriculum

Six tiers, each building on the last:

| Tier | Name | Focus |
|---|---|---|
| 0 | Orientation | What a database is, no code required; opening the practice database |
| 1 | Beginner | Asking a database simple questions |
| 2 | Intermediate | Combining tables, summarizing, cleaning messy real-world data |
| 3 | Advanced | Window functions, CTEs, recursive CTEs, time intelligence — the medallion thread begins |
| 4 | Expert | DDL, transactions, views, indexes, query optimization |
| 5 | Master | Dimensional modeling, star schema design, and the medallion architecture, end to end |

Start at Orientation if you're brand new or jump into any tier from the above list.

Starting at Tier 3, lessons lean on the applied project below instead of
hypothetical tables — you read the concept, then go run it against a
real database. Every example and every exercise solution in this
curriculum was actually run against `oakhaven.db` and its output
verified; nothing is invented.

---

## The applied project

`project/` is **Oakhaven** — a small, fictional outdoor-gear retailer modeled as a real 3-tier medallion SQLite database committed directly at `project/oakhaven.db`. You can open and query it immediately using any SQLite GUI or CLI without running any setup or build commands.

`project/oakhaven.db` contains a real medallion architecture at a scale you can hold in your head:

- **Bronze** — five raw tables (`bronze_customers`, `bronze_products`,
  `bronze_employees`, `bronze_sales`, `bronze_calendar`), generated with
  Faker and deliberately messy:
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
Faker version), so every learner's `oakhaven.db` is byte-identical. Because `project/oakhaven.db` is already committed to the repo, you don't need Python or any build step to get started.

> **Footnote: Regenerating the Database (Optional)**
> If you want to watch the deterministic pipeline run from scratch or rebuild the dataset:
> * **Python Instructions**: Follow the step-by-step [Python Database Generation Guide](curriculum/00-orientation/03-tools-and-setup.md#building-the-database-yourself-optional).
> * **AI Assistant Skill (`setup-database`)**: If working with an AI coding assistant (like Claude Code or Antigravity), use the built-in [`setup-database` skill](https://github.com/ianfinkdata/sql-practice/tree/main/.agents/skills/setup-database) to automatically handle virtual environments, dependencies, and build verification.

See `project/docs/data_dictionary.md` for the full schema and `project/docs/erd.md` for
an entity-relationship diagram.

---

## The portfolio

`portfolio/` is the repo's explicit takeaway: a standalone
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
1. Read Orientation (`curriculum/00-orientation/`).
   `oakhaven.db` is already sitting in `project/` — open it in your SQL tool of choice.
2. Work tier by tier. Each module ends with matching exercises.
3. From Tier 3 on, query `project/oakhaven.db` alongside the lesson.
4. Once you've finished Tier 5, browse `portfolio/` as a
   reference you can keep using long after this repo.

### If you just want the database, no setup at all
No Python, no CLI. Download or clone the repo, then
open `project/oakhaven.db` directly in DB Browser for SQLite or Beekeeper Studio and start
querying against `exercises/` and `project/docs/data_dictionary.md`.

### If you want the web version
Enable GitHub Pages on your fork pointing at `docs/` — see
`docs/INSTRUCTIONS.md` — or just open `docs/index.html` directly in a browser.

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
├── project/                   ← Oakhaven: pre-built bronze/silver/gold SQLite database (project/oakhaven.db)
│   ├── build.py               ← deterministic generator script (optional; see setup guide)
│   ├── requirements.txt
│   ├── build_lib/             ← precooked Faker-based generators
│   ├── bronze/  silver/  gold/← schema + view SQL, the actual "recipe" files
│   └── docs/                  ← data dictionary, ERD, facts sheet, sqlite3 CLI guide
├── portfolio/                 ← standalone, engine-agnostic medallion/star-schema pattern library
├── pbip/                      ← Power BI Projects: .pbip models, TMDL tooling, semantic layer
│   ├── pyscripts/             ← Python tooling (TMDL parser, linter, report manager, lineage)
│   ├── csharp/                ← Tabular Editor C# scripts
│   ├── projects/              ← .pbip project folders
│   └── sql_queries/           ← master SQL source files (1 per model)
├── build_pages.py             ← generates the GitHub Pages site into docs/
└── docs/                      ← GitHub Pages site
    ├── index.html
    ├── styles.css
    └── INSTRUCTIONS.md
```

---

## Resources

**Opening the project database**
- DB Browser for SQLite — free GUI, works on Windows/Mac/Linux, no install expertise required.
- Beekeeper Studio — free, modern SQL editor/GUI with SQLite support, also cross-platform.
- `sqlite.org/lang.html` — SQLite's own SQL language reference.
- `project/docs/sqlite_cli_guide.md` — a quick guide to the `sqlite3` command-line tool: dot-commands, one-liner syntax, common gotchas.

**Videos on the topics that trip people up most**
- [7 Window Functions MASTERED in 17 Minutes](https://youtu.be/vlltZIgn284)
- [What are CTEs in SQL, in 13 Minutes](https://www.youtube.com/watch?v=XUxBKO25ZyA)
- [Advanced SQL Tutorial: Subqueries](https://www.youtube.com/watch?v=m1KcNV-Zhmc)

**Web-based SQL practice exercises**
- [SQL Zoo](https://www.sqlzoo.net/wiki/SQL_Tutorial)
- [w3schools](https://www.w3schools.com/sql/)

**Interactive**
- [Gemini Notebook — Repository Mind Map](https://notebook.google.com/notebook/12d25d44-60f8-4e45-b0e0-d2ab86099874/artifact/00a8857a-ed6d-47ca-b539-ffef63fb9757) — interactive visual overview of the repository structure and curriculum.

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

---

<!-- nav -->
[📖 Table of Contents](README.md) | [⏭️ Next: Tier 0 Orientation](curriculum/00-orientation/README.md)
<!-- /nav -->
