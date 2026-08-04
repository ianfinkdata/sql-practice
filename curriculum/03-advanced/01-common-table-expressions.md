# 1. Common Table Expressions (CTEs)

## The idea

A **Common Table Expression** (CTE) is a named, temporary result set that
exists only for the duration of one query. You define it with a `WITH`
clause, give it a name, and then reference that name later in the query
exactly as if it were a real table.

```sql
WITH short_name AS (
    SELECT ...
)
SELECT * FROM short_name;
```

That's the whole mechanism. What makes CTEs worth a whole lesson isn't the
syntax — it's what they replace: **nested subqueries**. Every CTE you'll
write in this course could, in principle, be written as a subquery buried
inside a `FROM` clause or a `WHERE` clause instead. CTEs exist because that
alternative gets unreadable fast.

## Why CTEs beat nested subqueries

Compare two ways of asking the same question against Oakhaven:
*"Which VIP customers have a lifetime value above the average VIP lifetime
value?"*

**Nested subquery version** — the logic is inside-out. You have to read the
`WHERE` clause's subquery first, mentally hold onto what it computes, then
come back up to the outer query:

```sql
SELECT c.customer_id, c.full_name, c.customer_segment, c.lifetime_net_amount
FROM agg_customer_ltv c
WHERE c.customer_segment = 'VIP'
  AND c.lifetime_net_amount > (
        SELECT AVG(lifetime_net_amount) FROM agg_customer_ltv c2
        WHERE c2.customer_segment = c.customer_segment
  )
ORDER BY c.lifetime_net_amount DESC
LIMIT 5;
```

**CTE version** — the logic reads top-to-bottom, in the order you'd explain
it out loud: "first compute the segment averages, then compare each
customer against theirs."

```sql
WITH segment_avg AS (
    SELECT customer_segment, ROUND(AVG(lifetime_net_amount), 2) AS avg_ltv
    FROM agg_customer_ltv
    WHERE customer_segment IS NOT NULL
    GROUP BY customer_segment
)
SELECT c.customer_id, c.full_name, c.customer_segment,
       c.lifetime_net_amount, sa.avg_ltv
FROM agg_customer_ltv c
JOIN segment_avg sa ON sa.customer_segment = c.customer_segment
WHERE c.customer_segment = 'VIP' AND c.lifetime_net_amount > sa.avg_ltv
ORDER BY c.lifetime_net_amount DESC
LIMIT 5;
```

Verified output (identical for both versions):

| customer_id | full_name | customer_segment | lifetime_net_amount | avg_ltv |
|---|---|---|---|---|
| 343 | Jennifer Howard | VIP | 35024.55 | 14542.34 |
| 186 | Angela Fischer | VIP | 28985.84 | 14542.34 |
| 408 | Shawn Jacobs | VIP | 28149.78 | 14542.34 |
| 338 | Kristin Baker | VIP | 28089.28 | 14542.34 |
| 68 | Michele Perez | VIP | 27836.74 | 14542.34 |

Same result, same performance in SQLite — but the CTE version names its
intermediate step (`segment_avg`), which means you can read it, and you can
debug it: run `SELECT * FROM segment_avg` (well, the standalone `SELECT`
inside it) on its own to sanity-check that piece before trusting the whole
query.

## Syntax

```sql
WITH cte_name AS (
    SELECT ...
)
SELECT ... FROM cte_name ...;
```

You can chain multiple CTEs, separated by commas, and later CTEs can
reference earlier ones:

```sql
WITH cte_one AS (
    SELECT ...
),
cte_two AS (
    SELECT ... FROM cte_one ...
)
SELECT ... FROM cte_two ...;
```

A CTE is **not** a materialized table — it's not written to disk, and (in
SQLite) it's typically inlined into the surrounding query at execution
time. Think of it as a readability tool first, not a performance tool.

## Worked example: a real multi-step CTE chain over Oakhaven

*Question: which product category generated the most revenue in each
calendar year?* This needs two steps — first roll sales up to
category-per-year, then rank categories within each year — so it's a
natural two-CTE chain:

```sql
WITH category_year AS (
    SELECT year, category, ROUND(SUM(total_net_amount), 2) AS year_revenue
    FROM agg_monthly_sales_by_category
    GROUP BY year, category
),
ranked AS (
    SELECT year, category, year_revenue,
           RANK() OVER (PARTITION BY year ORDER BY year_revenue DESC) AS rnk
    FROM category_year
)
SELECT year, category, year_revenue
FROM ranked
WHERE rnk = 1
ORDER BY year;
```

Verified output:

| year | category | year_revenue |
|---|---|---|
| 2021 | Climbing | 243934.82 |
| 2022 | Nutrition & Hydration | 268912.10 |
| 2023 | Climbing | 253598.69 |
| 2024 | Climbing | 264295.25 |
| 2025 | Climbing | 242061.82 |
| 2026 | Climbing | 113911.92 |

(2026's total is naturally lower — Oakhaven's data only runs through
2026-06-30, so that's a half-year figure, not a full one. `RANK()` is
covered properly in the next module; for now just notice how naturally the
second CTE builds on the first one's output.)

Don't worry if `RANK() OVER (...)` looks unfamiliar — that's the whole
subject of the next module. The point here is the *shape*: each CTE does
one clear job, and the final `SELECT` just consumes the last one's output.

## Common mistakes

- **Forgetting a CTE only lives for one statement.** You can't `WITH x AS
  (...)` in one query and reference `x` in a separate query later — it's
  scoped to the single statement it's attached to.
- **Referencing a later CTE from an earlier one.** CTEs (except recursive
  ones — a later lesson) can only reference CTEs defined *before* them in
  the same `WITH` clause, not after.
- **Reaching for a CTE when a plain `JOIN` would do.** If you're not
  aggregating or filtering an intermediate result, you may not need a CTE
  at all — don't add ceremony where a simple join reads just as clearly.
- **One giant CTE instead of several small ones.** If a single CTE is
  doing three unrelated things, split it. The whole point is readability;
  a CTE that's as tangled as the subquery it replaced defeats the purpose.

## Key takeaways

- A CTE is a named, temporary result set, scoped to a single statement,
  defined with `WITH name AS (SELECT ...)`.
- CTEs and equivalent nested subqueries usually produce identical results
  and performance in SQLite — the difference is entirely about
  readability and debuggability.
- Chain multiple CTEs with commas; each one can reference the CTEs
  defined before it.
- A good rule of thumb: reach for a CTE whenever you catch yourself
  writing a subquery you'd want to name if you could.
