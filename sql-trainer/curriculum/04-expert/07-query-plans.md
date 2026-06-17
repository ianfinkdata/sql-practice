# Reading Query Plans

> EXPLAIN shows you the route the database plans to take through your query — the first step to making it faster.

## The idea

When you ask the database a question, it doesn't just blindly run your SQL. A part of it called the **query planner** thinks first: "What's the cheapest way to get this answer? Should I scan the whole table or use an index? In what order should I join these tables? Which join method is best?" It writes out a step-by-step plan, then executes it.

**EXPLAIN** lets you read that plan before it runs. It's like asking a GPS to show the route before you drive — which roads, in what order, and how long it thinks each leg will take. **EXPLAIN ANALYZE** goes further: it actually drives the route and reports the *real* times and row counts. The gap between what the planner guessed and what actually happened is often where your performance problems hide.

A plan is a tree of steps. The vocabulary you need is small:

**How it reads a table:**
- **Sequential scan (seq scan)** — read every row. Fine for small tables or when you genuinely need most rows; a red flag on a big table you're filtering narrowly.
- **Index scan** — use an index to jump to matching rows. What you usually want for selective filters.
- **Index-only scan** — answer entirely from the index, never touching the table (the covering index from the last module).

**How it combines tables (join strategies):**
- **Nested loop** — for each row on the left, look up matches on the right. Great when one side is tiny; terrible when both are big.
- **Hash join** — build a hash table of one side, then probe it with the other. Strong for large, unindexed equality joins.
- **Merge join** — sort both sides and zip them together. Efficient when inputs are already sorted, often by an index.

**The two numbers to watch:** every step shows an **estimated** row count and, under `ANALYZE`, an **actual** one. When the estimate says 10 and reality is 2,000,000, the planner was working from bad information — usually stale statistics — and probably picked a poor plan. That mismatch is the single most useful thing to look for.

## Why it matters

You can't tune what you can't see. A query might be slow because it's scanning a huge table you thought was indexed, or joining in a wasteful order, or because the planner badly misjudged how many rows would come back. EXPLAIN turns "it's slow, I don't know why" into "it's doing a seq scan on ten million rows because my index isn't being used." Reading plans is the diagnostic skill that makes the optimization in the next module purposeful instead of guesswork.

## See it

Ask for the plan without running the query:

```sql
EXPLAIN
SELECT s.sale_id, c.customer_name
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.amount > 1000;
```

Run it and get real timings and row counts to compare against the estimates:

```sql
EXPLAIN ANALYZE
SELECT s.sale_id, c.customer_name
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.amount > 1000;
```

A simplified plan might read top to bottom as: a *hash join* of the two tables, where `sales` is reached by a *seq scan* (because `amount > 1000` matches many rows) and `customers` is reached by an *index scan* on its primary key. If `EXPLAIN ANALYZE` shows the sales seq scan returning far more or fewer rows than estimated, that's your clue to refresh statistics or rethink the filter.

> **Dialect note:** Syntax varies. PostgreSQL uses `EXPLAIN` / `EXPLAIN ANALYZE` (add `BUFFERS`, `FORMAT JSON`); MySQL uses `EXPLAIN` and `EXPLAIN ANALYZE` (and `FORMAT=TREE`); SQL Server uses estimated/actual execution plans (often graphical, or `SET SHOWPLAN_ALL ON`); Oracle uses `EXPLAIN PLAN FOR` then queries `DBMS_XPLAN`. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **EXPLAIN ANALYZE actually runs the query.** On an `UPDATE` or `DELETE` it will really change data — wrap it in a transaction you roll back if you must test those.
- **Read estimates skeptically.** A plan that *looks* fine on estimates can be catastrophic if the actual row counts diverge wildly.
- **Big estimate-vs-actual gaps usually mean stale statistics.** Re-run the engine's analyze/stats command so the planner has fresh numbers.
- **A seq scan isn't always bad.** On a small table, or when you need most rows, scanning is cheaper than hopping through an index. Context matters.
- **Costs are unitless and relative.** The planner's "cost" numbers compare plans to each other; they aren't milliseconds. Use `ANALYZE` for real time.

## Practice

1. In plain English, describe the difference between what `EXPLAIN` tells you and what `EXPLAIN ANALYZE` adds.
2. A plan shows a sequential scan over a ten-million-row `sales` table for a query filtering `WHERE rep_id = 7`. What would you check or change?
3. Explain when a nested-loop join is a good choice and when a hash join is better.
4. A plan estimates 12 rows from a step but `ANALYZE` reports 900,000 actual rows. What does that mismatch suggest, and what's your first move?

---
**Prev:** [Indexes](06-indexes.md) · **Next:** [Query Optimization](08-query-optimization.md)
