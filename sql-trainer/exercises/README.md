# SQL Trainer — Exercises

Welcome to the hands-on side of **SQL Trainer**. The
[curriculum](../curriculum/) explains every idea in plain English; this folder
is where you *practice* it. Each tier mirrors a curriculum tier, so you can read
a module, then come here and prove to yourself that it clicked.

Work through them in order, or jump to the tier that matches where you are.

---

## How to use these exercises

1. **Read the prompt first.** Each exercise is a plain-English question, the kind
   a real stakeholder might ask: *"Which customers signed up last month?"*
2. **Write your own query before peeking.** The struggle is the learning.
3. **Open the solution to check yourself.** Every exercise has a collapsible
   solution — click **▸ Show solution** to expand it. You'll see the SQL plus a
   one-line explanation of *why* it works.
4. **Run it against the shared dataset** (below) in whatever database you like.
   The solutions use standard ANSI SQL; reach for the
   [Dialect Decoder](../dialect-decoder/) if your engine spells something
   differently.

> 💡 Solutions are **collapsible** so you never spoil an exercise by accident.
> If you don't see a triangle/arrow next to "Show solution," your Markdown
> viewer may not support `<details>` — open the raw file and the SQL is right
> there.

---

## The tiers

| Tier | File | Focus |
|------|------|-------|
| **1 — Beginner** | [`tier-1-beginner.md`](tier-1-beginner.md) | `SELECT`/`FROM`, `WHERE`, `ORDER BY`/`LIMIT`, `DISTINCT`, operators |
| **2 — Intermediate** | [`tier-2-intermediate.md`](tier-2-intermediate.md) | Aggregates, `GROUP BY`/`HAVING`, joins, set ops, subqueries, `CASE`, NULLs |
| **3 — Advanced** | [`tier-3-advanced.md`](tier-3-advanced.md) | Window functions, ranking, running totals, `LEAD`/`LAG`, CTEs, dates, pivot, strings |
| **4 — Expert** | [`tier-4-expert.md`](tier-4-expert.md) | DDL, DML, upsert, transactions, views, indexing, plans, optimization, triggers, JSON |
| **5 — Master** | [`tier-5-master.md`](tier-5-master.md) | Normalization, star schemas, SCD2, medallion layers, partitioning, anti-patterns |

Difficulty climbs *within* each tier too — the last few exercises in any file are
meant to make you think.

---

## The shared dataset

Every exercise across every tier uses the **same four tables**. Learn them once
and you can focus on the SQL, not on re-reading the schema.

| Table | Columns | What a row means |
|-------|---------|------------------|
| `customers` | `customer_id`, `customer_name`, `region`, `signup_date`, `email` | One company/person who buys from us |
| `sales` | `sale_id`, `sale_date`, `customer_id`, `rep_id`, `amount` | One closed sale (the fact table) |
| `sales_rep` | `rep_id`, `rep_name`, `commission_rate`, `hire_date` | One salesperson |
| `products` | `product_id`, `product_name`, `category`, `unit_price` | One thing we sell |

### How they relate

```
  customers                sales                 sales_rep
 +-----------+   1     *  +-----------+  *   1  +-------------+
 | customer_id|----------<| customer_id|        | rep_id      |
 | customer_  |           | rep_id     |>-------| rep_name    |
 |   name     |           | sale_id    |        | commission_ |
 | region     |           | sale_date  |        |   rate      |
 | signup_date|           | amount     |        | hire_date   |
 | email      |           +-----------+        +-------------+
 +-----------+

        customers  1—*  sales  *—1  sales_rep
```

- A **customer** has many **sales**; each sale belongs to exactly one customer.
- A **sales rep** closes many **sales**; each sale is credited to one rep.
- `products` stands a little apart in this MVP dataset — use it for exercises
  about catalogs, pricing, and (in later tiers) modeling how it *would* join to
  sales through a line-item table.

> The data is intentionally small and tidy so you can reason about results by
> hand. If a query returns something surprising, that's usually a feature — go
> figure out why.

---

## Conventions in the solutions

- **Standard ANSI SQL**, keywords in `UPPERCASE`.
- SQL lives in fenced ` ```sql ` blocks.
- Solutions are wrapped in `<details>` so they stay hidden until you ask.
- Where a "right answer" is a *design decision* (mostly Tiers 4–5), the solution
  is a short written discussion, with SQL where it helps.

---

Back to the [main project README](../README.md) ·
Jump to the [curriculum](../curriculum/).
