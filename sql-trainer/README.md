# SQL Trainer

> A complete, self-paced path from your very first `SELECT` to designing
> warehouse-scale data models — paired with a **Dialect Decoder** that
> translates cleanly between Oracle, Databricks, MySQL, and Postgres.

SQL Trainer is built around one idea: **learning SQL should feel like a patient
mentor sitting next to you**, not a reference manual dropped on your desk. The
curriculum explains every concept in plain English first and only reaches for
code when you're ready to write it.

---

## What's inside

| Part | What it is | Where |
|------|------------|-------|
| 📚 **Curriculum** | Five tiers, beginner → master, ~40 modules | [`curriculum/`](curriculum/) |
| 🔄 **Dialect Decoder** | Side-by-side translations across 4 SQL dialects | [`dialect-decoder/`](dialect-decoder/) |
| 🧑‍🏫 **Persona Guide** | How the trainer ("SQRL") talks to you | [`persona_instructions.md`](persona_instructions.md) |
| 🌐 **Web version** | Browsable GitHub Pages site | [`docs/`](docs/) |
| 🏋️ **Exercises** | Hands-on practice prompts per tier | [`exercises/`](exercises/) |

---

## The five tiers

| Tier | Name | You'll be able to... |
|------|------|----------------------|
| **1** | [Beginner](curriculum/01-beginner/) | Ask a database simple questions and get answers back |
| **2** | [Intermediate](curriculum/02-intermediate/) | Combine tables, summarize data, and handle the messy parts |
| **3** | [Advanced](curriculum/03-advanced/) | Run analytics: window functions, CTEs, time intelligence |
| **4** | [Expert](curriculum/04-expert/) | Build and tune: DDL, transactions, indexes, performance |
| **5** | [Master](curriculum/05-master/) | Design data models and architectures that scale |

Start at [`curriculum/00-orientation/`](curriculum/00-orientation/) if you're
brand new, or jump to any tier you're ready for.

---

## The Dialect Decoder

The same idea is often spelled four different ways. The Dialect Decoder gives
you the exact phrasing for **your** database and the equivalent in the others —
so you never get stuck because a tutorial assumed a different system.

Prioritized dialects:

- 🟥 **Oracle SQL** (Oracle Database 19c+)
- 🧱 **Databricks SQL** (Spark SQL / Photon)
- 🐬 **MySQL** (8.0+)
- 🐘 **PostgreSQL** (14+)

See [`dialect-decoder/README.md`](dialect-decoder/README.md) and the
[full translation matrix](dialect-decoder/reference-matrix.md).

---

## How to use this repo

### If you're learning on your own
1. Read [`curriculum/00-orientation/`](curriculum/00-orientation/).
2. Work tier by tier. Each module ends with exercises.
3. Keep the [Dialect Decoder](dialect-decoder/) open in another tab for your
   database.

### If you're learning with an AI assistant
Point the assistant at [`persona_instructions.md`](persona_instructions.md).
It will adopt **SQRL**, a mentor who keeps things simple and only shows code
when you need it. Then just say where you are: *"I've never written SQL"* or
*"I know joins but not window functions."*

### If you want the web version
Open the [GitHub Pages site](docs/index.html) (or enable Pages on this repo,
pointing at the `docs/` folder — see [`docs/INSTRUCTIONS.md`](docs/INSTRUCTIONS.md)).

---

## Project structure

```
sql-trainer/
├── README.md                  ← you are here
├── persona_instructions.md    ← how the trainer talks to learners
├── curriculum/                ← the full beginner→master path
│   ├── 00-orientation/
│   ├── 01-beginner/
│   ├── 02-intermediate/
│   ├── 03-advanced/
│   ├── 04-expert/
│   └── 05-master/
├── dialect-decoder/           ← Oracle · Databricks · MySQL · Postgres
│   ├── README.md
│   ├── reference-matrix.md
│   ├── oracle.md
│   ├── databricks.md
│   ├── mysql.md
│   └── postgres.md
├── exercises/                 ← practice prompts + solutions
└── docs/                      ← GitHub Pages site
    ├── index.html
    ├── styles.css
    └── INSTRUCTIONS.md
```

This folder is fully self-contained. It can be split off into its own
repository without dragging along anything else — see
[`docs/INSTRUCTIONS.md`](docs/INSTRUCTIONS.md) for the one-command split.

---

## A note on philosophy

You will notice the curriculum talks *a lot* and shows code *a little*. That's
deliberate. Most people don't get stuck on syntax — they get stuck on the
*idea*. Once the idea is clear, the syntax is a five-minute lookup (and the
Dialect Decoder is right there for it). SQL Trainer optimizes for
understanding first, typing second.

---

*Built as an MVP. Contributions, corrections, and new dialect entries welcome.*
