# 9. Correlated Subqueries, EXISTS, and NOT EXISTS

<!-- nav -->
Previous: [8. Writing Your First Silver View](08-writing-your-first-silver-view.md). Next: [10. Capstone — Combining CTEs and Window Functions](10-combining-ctes-and-window-functions.md). Exercises: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](../../exercises/03-advanced/09-correlated-subqueries-exists.md).
<!-- /nav -->

## The idea

A subquery is **correlated** when it references a column from the outer
query — meaning it can't be run on its own, because its result depends on
whatever outer row is currently being evaluated. Conceptually, a
correlated subquery runs once *per outer row*, each time filtered down to
just that row's context.

```sql
SELECT p.product_id, p.product_name, p.category, p.unit_price
FROM dim_product p
WHERE p.unit_price > (
    SELECT AVG(p2.unit_price) FROM dim_product p2 WHERE p2.category = p.category
);
```

That inner `SELECT` can't run by itself — `p.category` only means
something in the context of the current outer row `p`. Compare this to an
**uncorrelated** subquery (every subquery you've used so far in this
course, including all of Module 1's CTEs): those compute one fixed result,
independent of any outer row, and can be run standalone to sanity-check
them.

`EXISTS` and `NOT EXISTS` are the most common correlated-subquery pattern:
testing whether *any* matching row exists in a related table, without
caring what that row's values actually are.

## Syntax

```sql
SELECT ... FROM outer_table o
WHERE [NOT] EXISTS (
    SELECT 1 FROM inner_table i WHERE i.key = o.key [AND ...]
);
```

`SELECT 1` (or `SELECT *`) inside an `EXISTS` is conventional — the actual
selected value is irrelevant, because `EXISTS` only asks "does at least
one row match?", not "what are the matching rows?" SQLite stops scanning
as soon as it finds one match, so this pattern is also efficient: it
doesn't have to enumerate every match, just find whether one exists.

## Example 1: products priced above their own category's average

```sql
SELECT p.product_id, p.product_name, p.category, p.unit_price
FROM dim_product p
WHERE p.unit_price > (
    SELECT AVG(p2.unit_price) FROM dim_product p2 WHERE p2.category = p.category
)
ORDER BY p.category, p.unit_price DESC
LIMIT 6;
```

Verified output:

| product_id | product_name | category | unit_price |
|---|---|---|---|
| 11 | Switchback Hat | Accessories | 525.42 |
| 72 | Switchback Multi-Tools | Accessories | 505.09 |
| 7 | Granite Sunglasse | Accessories | 490.08 |
| 93 | Basecamp Multi-Tool | Accessories | 415.92 |
| 83 | Granite Sunglasses | Accessories | 373.98 |
| 123 | Switchback Headlamps | Accessories | 370.95 |

For every outer row (each product `p`), the correlated subquery computes
`AVG(unit_price)` scoped to just that product's own category — a different
number for `Accessories` than for `Climbing`. This is genuinely different
from what a CTE + join would need: there's no single "category averages"
table being joined here, just a per-row lookup.

## Example 2: EXISTS for "has at least one related row"

*Question: which customers have never placed an Online order?* — note
"never Online" is different from "always In-Store"; a customer could have
zero orders of any kind, or a mix that just happens to exclude Online.

```sql
SELECT c.customer_id, c.full_name
FROM dim_customer c
WHERE EXISTS (SELECT 1 FROM fact_sales f WHERE f.customer_id = c.customer_id)
  AND NOT EXISTS (
      SELECT 1 FROM fact_sales f WHERE f.customer_id = c.customer_id AND f.channel = 'Online'
  )
ORDER BY c.customer_id;
```

Verified output — out of 600 customers, only **2** have ordered before but
never Online:

| customer_id | full_name |
|---|---|
| 481 | Kristi Hayes |
| 580 | Bradley Davis |

The first `EXISTS` filters to customers who've ordered *at all* (excluding
never-ordered customers from a "never ordered Online" answer, which would
be misleading — they haven't ordered any way, not specifically avoided
Online). The `NOT EXISTS` then does the actual exclusion.

## Example 3: EXISTS/NOT EXISTS vs IN/NOT IN — and the NULL trap

For simple "is this value in this list" checks, `IN` and `EXISTS` usually
produce identical results and SQLite's query planner often optimizes them
identically. But `NOT IN` has a sharp, well-known edge case that
`NOT EXISTS` doesn't share: **if the subquery's result list contains even
one `NULL`, `NOT IN` silently returns zero rows for everything** — not an
error, just quietly wrong.

Minimal reproduction, isolated from Oakhaven's scale so the mechanism is
easy to see:

```sql
WITH ids(id) AS (VALUES (1), (2), (3)),
     excluded(id) AS (VALUES (2), (NULL))
SELECT id FROM ids WHERE id NOT IN (SELECT id FROM excluded);
```

Verified output: **zero rows.** The correct answer is obviously `{1, 3}`
(2 is excluded, 1 and 3 aren't) — but SQL's three-valued logic means `1
NOT IN (2, NULL)` evaluates to `UNKNOWN`, not `TRUE`, because SQL can't
prove 1 doesn't equal the unknown `NULL` value. `UNKNOWN` doesn't pass a
`WHERE` filter, so every row is silently dropped.

The `NOT EXISTS` equivalent doesn't have this problem, because it never
compares against `NULL` as a value — it just checks row existence:

```sql
WITH ids(id) AS (VALUES (1), (2), (3)),
     excluded(id) AS (VALUES (2), (NULL))
SELECT id FROM ids i WHERE NOT EXISTS (SELECT 1 FROM excluded e WHERE e.id = i.id);
```

Verified output: `{1, 3}` — correct.

This isn't a purely academic risk in Oakhaven. `fact_sales.employee_id` is
`NULL` for 1,243 rows (~10.4% — online/no-rep sales, per the data
dictionary). Every one of Oakhaven's 35 employees happens to have at least
one sale, so a query like `SELECT * FROM dim_employee e WHERE e.employee_id
NOT IN (SELECT employee_id FROM fact_sales)` currently returns 0 rows — the
*correct* answer, coincidentally. But that query is a latent bug: if
Oakhaven ever added employee #36 with zero sales, `NOT IN` against a
column with NULLs in it would **still** silently report 0 rows — the new
employee would be invisible to this exact query, not because they made a
sale, but because the NULL-poisoned list makes `NOT IN` always return
false. `NOT EXISTS` (or `NOT IN (... WHERE employee_id IS NOT NULL)`, which
explicitly filters the poison out) would report it correctly.

## Common mistakes

- **Reaching for `NOT IN` against any column/subquery that might contain
  `NULL`s, without checking first.** This is the single most common
  correlated-subquery-adjacent SQL bug in production code — it doesn't
  error, it just quietly returns wrong (often empty) results. Default to
  `NOT EXISTS` for "not in this list" checks unless you're certain the
  subquery's column is `NOT NULL`.
- **Writing a correlated subquery that could be an uncorrelated CTE
  instead.** If the "per-row" computation is really just "per-group" (like
  Example 1's category averages), a CTE that computes it once per group
  and joins is often clearer — and sometimes faster, since a correlated
  subquery conceptually re-evaluates per outer row. Reach for the
  correlated form when the comparison genuinely can't be pre-computed
  per-group (e.g. Example 2's "no matching row of any kind" existence
  checks).
- **Using `SELECT *` inside `EXISTS` and thinking it matters which columns
  come back.** It doesn't — `EXISTS` only cares about row presence. Use
  `SELECT 1` as the idiomatic convention; it signals "the columns are
  irrelevant" to anyone reading the query.
- **Forgetting the correlation condition entirely**, accidentally writing
  an uncorrelated subquery when a correlated one was intended (e.g.
  omitting `WHERE f.customer_id = c.customer_id`), which silently changes
  "does *this* customer have an order" into "does *any* customer have an
  order."

## Key takeaways

- A correlated subquery references a column from its outer query, so it
  conceptually re-evaluates per outer row — unlike the uncorrelated
  subqueries/CTEs used everywhere earlier in this course.
- `EXISTS`/`NOT EXISTS` test row *presence*, not values — `SELECT 1` is
  the idiomatic placeholder inside them.
- `NOT IN` silently returns zero rows for everything if its subquery's
  result list contains a `NULL` — a real risk in Oakhaven wherever a
  column like `fact_sales.employee_id` (1,243 NULLs) is used as the source
  list. `NOT EXISTS` doesn't have this failure mode.
- When in doubt between `IN`/`NOT IN` and `EXISTS`/`NOT EXISTS`: `EXISTS`
  family is safer by default, especially for `NOT` forms.

---

<!-- nav -->
Previous: [8. Writing Your First Silver View](08-writing-your-first-silver-view.md). Next: [10. Capstone — Combining CTEs and Window Functions](10-combining-ctes-and-window-functions.md). Exercises: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](../../exercises/03-advanced/09-correlated-subqueries-exists.md).
<!-- /nav -->
