# Window Functions: The Big Idea

> Calculate across related rows without collapsing them into one.

## The idea

You already know `GROUP BY`. It takes many rows and squeezes them into fewer — one row per group. If you group sales by region, ten thousand sales become four rows, one per region. That's powerful, but it's also lossy: the individual sales disappear.

Window functions solve a different problem. They let you calculate something *across a set of related rows* while **keeping every original row right where it is**.

Picture a classroom of students, each with a test score. `GROUP BY` is like the teacher announcing "the class average is 78" — one number, the individuals gone. A window function is like writing, *next to each student's own score*, what the class average is, and where that student ranks. Every student stays on the roster. They just gain a new column of context.

That's the whole magic: context without collapse. Each row can "look around" at its neighbors — the whole group, or the rows before it, or the row just behind — and bring back an answer, without losing itself.

The doorway to all of this is one keyword: **`OVER()`**. Wherever you'd normally write an aggregate like `SUM(amount)` and be forced into a `GROUP BY`, you can instead write `SUM(amount) OVER (...)` and keep your rows.

There are three pieces inside that `OVER(...)`, and understanding them is understanding window functions:

- **`OVER()`** — the signal that says "this is a window function; do not collapse my rows."
- **`PARTITION BY`** — divides the rows into groups, like chapters in a book. The calculation restarts inside each partition. Leave it out and the whole result is one big partition.
- **`ORDER BY`** (inside the `OVER`) — gives the rows an order *within* each partition. This matters for anything that depends on sequence: rankings, running totals, "the previous row."

A helpful way to hold it in your head: `PARTITION BY` is the *grouping* dial, `ORDER BY` is the *sequence* dial. You turn one, both, or neither depending on the question.

## Why it matters

So much of real analytics is "compare each row to its group." What share of my region's revenue did this one sale represent? How does this month stack up against the running total so far? Who's the top rep *in each* region? These are everyday questions, and a single `GROUP BY` simply can't answer them, because the moment you group, the per-row detail you wanted to keep is gone.

Window functions are the tool that unlocks this entire category. Ranking, running totals, moving averages, period-over-period change — every topic in this tier is built on the foundation you're learning right now.

## See it

Show every sale alongside the average sale amount for its region — without losing a single row:

```sql
SELECT
  s.sale_id,
  c.region,
  s.amount,
  AVG(s.amount) OVER (PARTITION BY c.region) AS region_avg
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id;
```

Every sale still appears. Next to each one sits its region's average, so you can instantly see which sales are above or below par for their region.

Contrast that with the `GROUP BY` version, which answers a *different* question — one row per region, details gone:

```sql
SELECT c.region, AVG(s.amount) AS region_avg
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id
GROUP BY c.region;
```

Same `AVG`, completely different shape of answer. That difference is the heart of this tier.

## Watch out

- **`OVER()` is what makes it a window function.** Without it you have an ordinary aggregate that demands a `GROUP BY`.
- **You can't put a window function in a `WHERE` clause.** Windows are computed *after* `WHERE`, so to filter on a window result you must wrap the query in a subquery or CTE first.
- **No `GROUP BY` needed** — in fact, mixing a naked column with an aggregate and no `GROUP BY` errors out, but the window version is perfectly legal.
- **`PARTITION BY` is optional.** Omit it and the entire result set is treated as one partition.
- **`ORDER BY` inside `OVER` is different** from the `ORDER BY` that sorts your final output. One shapes the window; the other sorts the page.

## Practice

1. In plain English, describe a question about your sales data that `GROUP BY` *cannot* answer but a window function can.
2. Write a query that lists each sale with the average sale amount across the entire table beside it (no partition).
3. Modify it so the average is computed per sales rep instead of across everything.
4. Explain why you can't filter "show only sales above their region average" using a `WHERE` clause directly, and describe the workaround.

---
**Prev:** [Tier 2: Intermediate](../02-intermediate/) · **Next:** [Ranking](./02-ranking.md)
