# SQL Practice

> A complete, self-paced path from your very first `SELECT` to designing
> warehouse-scale data models — paired with a small, real
> **bronze → silver → gold** project you can query with nothing but a clone
> of this repo.

SQL Practice is built around one idea: **learning SQL should feel like a
patient mentor sitting next to you**, not a reference manual dropped on your
desk. The curriculum explains every concept in plain English first and only
reaches for code when you're ready to write it.

It's also built to be **portable**: no database server to install, no
credentials to manage, no OS-specific setup. Everything here is either
Markdown or a single committed SQLite file. Clone the repo, on any machine,
with any tool that can read a GitHub repository — a browser, a local editor,
an AI assistant — and everything works immediately.

---

## What's inside

| Part | What it is | Where |
|------|------------|-------|
| 📚 **Curriculum** | Beginner → master, tier by tier | [`curriculum/`](curriculum/) |
| 🏋️ **Exercises** | Hands-on practice prompts per tier | [`exercises/`](exercises/) |
| 🧪 **Applied project** | A small retailer, modeled bronze → silver → gold, as one SQLite file | [`project/`](project/) |
| 🤖 **AI assistant guide** | Tool-agnostic instructions for any AI helping in this repo | [`AGENTS.md`](AGENTS.md) |
| 🌐 **Web version** | Browsable GitHub Pages site | [ianfinkdata.github.io/sqrl-practice](https://ianfinkdata.github.io/sqrl-practice/) |

---

## Curriculum

Five tiers, each building on the last:

| Tier | Name | Focus |
|------|------|--------|
| **0** | [Orientation](curriculum/00-orientation/) | What a database is, no code required |
| **1** | [Beginner](curriculum/01-beginner/) | Asking a database simple questions |
| **2** | [Intermediate](curriculum/02-intermediate/) | Combining tables, summarizing, handling the messy parts |
| **3** | [Advanced](curriculum/03-advanced/) | Window functions, CTEs, recursive CTEs, time intelligence |
| **4** | [Expert](curriculum/04-expert/) | DDL, transactions, views, indexes, query optimization |
| **5** | [Master](curriculum/05-master/) | Dimensional modeling and the medallion architecture |

Start at [`curriculum/00-orientation/`](curriculum/00-orientation/) if you're
brand new, or jump to any tier you're ready for — see
[`curriculum/README.md`](curriculum/README.md) for the full module list.

Starting at Tier 3, lessons lean on the applied project below instead of
hypothetical tables — you read the concept, then go run it against a real
database.

---

## The applied project

[`project/`](project/) is **Oakhaven** — a small, fictional outdoor-gear
retailer, generated deterministically into a single SQLite file
(`project/oakhaven.db`). It's a real medallion pipeline at a scale you can
actually hold in your head:

- **Bronze** — raw tables, including deliberately dirty data (inconsistent
  state formatting, mixed-format booleans, an untrustworthy order-total
  column). The `calendar` table is generated with a recursive CTE.
- **Silver** — views that clean, standardize, and derive (this is where a
  calendar date turns into a year/month/quarter).
- **Gold** — business-ready views: monthly sales by category, customer
  lifetime value, daily sales including zero-order days.
---

## How to use this repo

### If you're learning on your own
1. Read [`curriculum/00-orientation/`](curriculum/00-orientation/).
2. Work tier by tier. Each module ends with exercises.
3. From Tier 3 on, query [`project/`](project/) alongside the lesson.

### If you want the web version
Open the [GitHub Pages site](docs/index.html), or enable Pages on your own
fork pointing at `docs/` — see [`docs/INSTRUCTIONS.md`](docs/INSTRUCTIONS.md).

---

## Project structure

```
sqrl-practice/
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
├── project/                   ← Oakhaven: a real bronze/silver/gold SQLite database
│   ├── oakhaven.db
│   ├── build.py
│   ├── bronze/  silver/  gold/  docs/
└── docs/                      ← GitHub Pages site
    ├── index.html
    ├── styles.css
    └── INSTRUCTIONS.md
```

---

## Resources

A short list of things worth having open alongside this repo, beyond what's
in `curriculum/` already.

**Opening the project database**
- [DB Browser for SQLite](https://sqlitebrowser.org/) — free GUI, works on
  Windows/Mac/Linux, no install expertise required.
- [`sqlite.org/lang.html`](https://sqlite.org/lang.html) — SQLite's own SQL
  language reference, useful for anything SQLite-specific that isn't covered
  in the curriculum.
- [`project/docs/sqlite_cli_guide.md`](project/docs/sqlite_cli_guide.md) —
  a quick guide to the `sqlite3` command-line tool itself: dot-commands,
  one-liner syntax, and common gotchas.

**Videos on the topics that trip people up most**
- [7 Window Functions MASTERED in 17 Minutes](https://youtu.be/vlltZIgn284) — ROW_NUMBER, RANK, DENSE_RANK, running totals, LEAD/LAG.
- [What are CTEs in SQL, in 13 Minutes](https://www.youtube.com/watch?v=XUxBKO25ZyA)
- [Advanced SQL Tutorial: Subqueries](https://www.youtube.com/watch?v=m1KcNV-Zhmc)

**Web-based SQL practice exercises**
- [SQL Zoo](https://www.sqlzoo.net/wiki/SQL_Tutorial)
- [w3schools](https://www.w3schools.com/sql/)

**Creators and courses**
- [Jess Ramos](https://www.youtube.com/playlist?list=PL1P1MQiF_DNHzpV6fqypuL75bpK553vaN)
- [Analyst Builder](https://www.analystbuilder.com/courses)

Have a resource that belongs here? Add it — this list is meant to grow.

---

## A note on philosophy

You will notice the curriculum talks *a lot* and shows code *a little*. That's
deliberate. Most people don't get stuck on syntax — they get stuck on the
*idea*. Once the idea is clear, the syntax is a five-minute lookup. SQRL
Practice optimizes for understanding first, typing second.

---

*Contributions and corrections welcome.*
