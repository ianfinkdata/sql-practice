# Subqueries and Derived Tables


<!-- nav -->
Previous: [COALESCE and NULLIF](07-coalesce-and-nullif.md). Next: [Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT](09-set-operations.md).
<!-- /nav -->

## The idea

A subquery is a `SELECT` nested inside another query. You've already
seen the simplest cousin of this idea in Module 2 and 7's examples
without naming it. There are three shapes worth knowing by name:

1. **Scalar subquery** — a subquery that returns exactly one value
   (one row, one column). Used anywhere a single value is expected:
   `WHERE price > (SELECT AVG(price) FROM ...)`.
2. **Subquery in `WHERE`** — often paired with `IN`, filtering rows
   based on a *list* a subquery produces:
   `WHERE customer_id IN (SELECT ...)`.
3. **Derived table** — a subquery used in the `FROM` clause, standing
   in for a table. It has to be given an alias, and the outer query
   treats it exactly like a real table.

The common thread: a subquery runs first, produces a result, and the
outer query works with that result.

## Why it matters

Some Oakhaven questions genuinely need two steps. "Which products are
priced above average?" needs the average computed first, then
compared against — one query, two logical steps, a scalar subquery
ties them together. "Which customers have bought Climbing gear?"
needs the Climbing product ids first, then the customers who bought
any of them — a subquery in `WHERE ... IN`. "Which customers'
lifetime order-line total exceeds some threshold?" needs the per-customer
totals *computed first*, then filtered — you can't `WHERE` on an
aggregate that doesn't exist until after grouping (Module 4 covered
exactly this with `HAVING` for simple cases; a derived table gives you
the same power for more complex, multi-step logic).

## Syntax

```sql
-- Scalar subquery — used as a single value
SELECT * FROM t WHERE col > (SELECT AVG(col) FROM t);

-- Subquery in WHERE with IN — used as a list
SELECT * FROM t WHERE id IN (SELECT id FROM other_table WHERE ...);

-- Derived table — subquery in FROM, must be aliased
SELECT alias.col
FROM (SELECT ... FROM t GROUP BY ...) AS alias
WHERE alias.col > 10;
```

A subquery can appear almost anywhere a value, list, or table is
expected. SQLite evaluates the inner query as needed to satisfy the
outer one.

## Try it

**1. Scalar subquery: products priced above the average**

```sql
SELECT ROUND(AVG(unit_price), 2) AS avg_price FROM bronze_products;
```

| avg_price |
|---|
| 300.37 |

```sql
SELECT product_id, product_name, unit_price
FROM bronze_products
WHERE unit_price > (SELECT AVG(unit_price) FROM bronze_products)
ORDER BY unit_price DESC
LIMIT 5;
```

| product_id | product_name | unit_price |
|---|---|---|
| 18 | Highline Backpacks | 812.71 |
| 34 | Foothill Electrolyte Mixes | 782.32 |
| 43 | Highline Paddle | 696.3 |
| 135 | Canyon Backpacks | 687.96 |
| 90 | Meridian Chalk Bags | 669.02 |

```sql
SELECT COUNT(*) FROM bronze_products
WHERE unit_price > (SELECT AVG(unit_price) FROM bronze_products);
```

| COUNT(*) |
|---|
| 69 |

The inner query `(SELECT AVG(unit_price) FROM bronze_products)` runs
once, returns a single number (300.37), and the outer query compares
every row's `unit_price` against it — as if you'd typed `WHERE
unit_price > 300.37` directly, except it stays correct if the data
changes.

**2. Subquery in WHERE with IN: customers who bought Climbing gear**

```sql
SELECT customer_id, first_name, last_name
FROM bronze_customers
WHERE customer_id IN (
  SELECT DISTINCT customer_id FROM bronze_sales
  WHERE product_id IN (
    SELECT product_id FROM bronze_products WHERE category = 'Climbing'
  )
)
ORDER BY customer_id
LIMIT 5;
```

| customer_id | first_name | last_name |
|---|---|---|
| 5 | John | harris |
| 6 | ANTHONY | Reed |
| 7 | Brian | Schultz |
| 10 | ryan | Gonzalez |
| 11 | brian | Miller |

```sql
SELECT COUNT(*) FROM bronze_customers
WHERE customer_id IN (
  SELECT DISTINCT customer_id FROM bronze_sales
  WHERE product_id IN (
    SELECT product_id FROM bronze_products WHERE category = 'Climbing'
  )
);
```

| COUNT(*) |
|---|
| 403 |

Two nested subqueries here: the innermost finds Climbing
`product_id`s, the middle one finds `customer_id`s from `bronze_sales`
that bought one of those products, and the outer query filters
`bronze_customers` down to that list. Worth flagging honestly: `category
= 'Climbing'` matches only the one exact-cased spelling — Module 3
showed `category` has 6+ raw variants meaning "Climbing." A fully
correct version of this query would use the cleaning chain from Module
6 inside that innermost subquery. This version undercounts on purpose,
to keep the subquery pattern itself the focus.

**3. Derived table: per-customer totals, computed then filtered**

```sql
SELECT *
FROM (
  SELECT customer_id, COUNT(*) AS line_count,
         ROUND(SUM(quantity * unit_price), 2) AS rough_total
  FROM bronze_sales
  GROUP BY customer_id
) AS totals
WHERE totals.line_count > 30
ORDER BY totals.rough_total DESC
LIMIT 5;
```

| customer_id | line_count | rough_total |
|---|---|---|
| 41 | 43 | 44030.55 |
| 343 | 39 | 39539.78 |
| 597 | 34 | 38494.27 |
| 572 | 39 | 34442.36 |
| 173 | 37 | 34371.42 |

The inner query computes `line_count` and `rough_total` per customer
first, as its own independent result. The outer query then treats that
result as if it were a table named `totals`, filtering and sorting on
columns (`line_count`, `rough_total`) that only exist *because* they
were computed inside the subquery. You could get the same `line_count
> 30` result with `HAVING COUNT(*) > 30` directly (Module 4) — derived
tables earn their keep once you need to filter or join on a computed
value *after* other logic has already run on top of it.

**4. A subquery is just a query — test it standalone first**

Before nesting a subquery, run it by itself to make sure it returns
what you expect:

```sql
SELECT product_id FROM bronze_products WHERE category = 'Climbing';
```

Confirming the inner piece works in isolation, on its own, before
wrapping an outer query around it, is the single best debugging habit
for subqueries — it turns "this complicated query returns nothing,
somehow" into "step 2 of 3 is the problem."

## Common mistakes

- **A scalar subquery returning more than one row.** `WHERE unit_price
  > (SELECT unit_price FROM bronze_products)` (no `AVG`, no filter to
  guarantee one row) is an error in SQLite if the subquery finds
  multiple rows — scalar-subquery position needs a query guaranteed to
  return exactly one row/column, typically via an aggregate.
- **Forgetting to alias a derived table.** `FROM (SELECT ...) WHERE
  ...` without `AS alias` is invalid in SQLite — every subquery in
  `FROM` needs a name so the outer query can refer to its columns.
- **Using `=` instead of `IN` when the subquery can return multiple
  rows.** `WHERE product_id = (SELECT product_id FROM bronze_products
  WHERE category = 'Climbing')` breaks the moment more than one row
  matches — `IN` is the safe default whenever the inner query's row
  count isn't guaranteed to be exactly one.
- **Not testing the inner query by itself first.** A subquery buried
  three levels deep that returns nothing is much easier to debug one
  level at a time (see example 4) than by staring at the whole nested
  query at once.

## Key takeaways

- Scalar subqueries return a single value and slot in anywhere a
  literal value would go.
- Subqueries in `WHERE ... IN (...)` filter against a list produced by
  another query.
- Derived tables (`FROM (subquery) AS alias`) let the outer query
  build on top of an already-computed, already-aggregated result.
- Test the innermost subquery standalone before nesting — it's the
  fastest way to isolate a broken piece.
- Subqueries and `HAVING`/`JOIN` often solve overlapping problems;
  reach for a derived table specifically when you need to filter or
  join on something computed by an earlier step.

---

<!-- nav -->
Previous: [COALESCE and NULLIF](07-coalesce-and-nullif.md). Next: [Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT](09-set-operations.md).
<!-- /nav -->
