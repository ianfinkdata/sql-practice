# LEFT JOIN and Missing Data

<!-- nav -->
Previous: [Combining Tables with JOIN](01-combining-tables-with-join.md). Next: [GROUP BY](03-group-by.md). Exercises: [LEFT JOIN and Missing Data](../../exercises/02-intermediate/02-left-join-and-missing-data.md).
<!-- /nav -->

## The idea

Module 1 showed that `INNER JOIN` drops any row that doesn't find a
match on the other side — silently. `LEFT JOIN` fixes that by keeping
**every row from the left (first-listed) table**, whether or not it
finds a match. When there's no match, the columns coming from the
right table are simply filled in with `NULL`.

That gives you a superpower: **rows where the right-side columns are
`NULL` are exactly the rows that had no match** — the orphans, the
gaps, the "this doesn't exist" cases. Instead of INNER JOIN quietly
deleting them from your result, LEFT JOIN hands them to you, flagged.

## Why it matters

We measured in Module 1 that joining `bronze_sales` to
`bronze_products` on `product_id` loses 122 rows to `INNER JOIN`. With
`LEFT JOIN`, those 122 rows don't disappear — they show up with every
`bronze_products` column as `NULL`, and you can filter directly for
`WHERE p.product_id IS NULL` to pull up the exact broken rows. That's
the difference between "my report total looks a little off, no idea
why" and "here are the 122 order lines referencing a product that
doesn't exist, go investigate." This is a first taste of the
data-quality work Tier 3/4 dig into much more deeply.

## Syntax

```sql
SELECT columns
FROM table_a AS a
LEFT JOIN table_b AS b
  ON a.shared_column = b.shared_column;
```

- Every row from `table_a` appears in the result at least once,
  matched or not.
- When there's no match, all of `table_b`'s columns come back `NULL`
  for that row.
- To find the unmatched rows specifically, filter on a column from
  `table_b` that can never legitimately be `NULL` for a real match —
  typically its id column: `WHERE b.some_id IS NULL`.
- `LEFT OUTER JOIN` is the same thing as `LEFT JOIN` in SQLite; the
  `OUTER` keyword is optional.

## Try it

**1. Surface the orphan `product_id` rows an INNER JOIN would hide**

```sql
SELECT s.order_id, s.order_line_id, s.product_id, p.product_name
FROM bronze_sales s
LEFT JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.product_id IS NULL
LIMIT 5;
```

| order_id | order_line_id | product_id | product_name |
|---|---|---|---|
| 4 | 1 | 8289 | NULL |
| 38 | 1 | 5299 | NULL |
| 79 | 1 | 3672 | NULL |
| 82 | 1 | 4440 | NULL |
| 89 | 2 | 4573 | NULL |

Each `product_id` here (8289, 5299, ...) is a number that simply
doesn't exist in `bronze_products` (which only has ids 1–150). The
`LEFT JOIN` kept the sale row anyway and filled `product_name` with
`NULL` because there was nothing to match.

```sql
SELECT COUNT(*) FROM bronze_sales s
LEFT JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.product_id IS NULL;
```

| COUNT(*) |
|---|
| 122 |

Same 122 rows Module 1 showed disappearing under `INNER JOIN` — now
in hand, ready to investigate.

**2. Same pattern against `bronze_customers`**

```sql
SELECT s.order_id, s.customer_id, c.first_name, c.last_name
FROM bronze_sales s
LEFT JOIN bronze_customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
LIMIT 5;
```

| order_id | customer_id | first_name | last_name |
|---|---|---|---|
| 97 | 9318 | NULL | NULL |
| 97 | 9318 | NULL | NULL |
| 190 | 4124 | NULL | NULL |
| 190 | 4124 | NULL | NULL |
| 190 | 4124 | NULL | NULL |

Notice orders 97 and 190 each contribute multiple lines — the data
dictionary explains why: bad `customer_id` values are injected at the
*order* level, so every line of an affected order shares the same
nonexistent id. 103 rows total match this pattern (confirmed in
Module 1), spread across 61 distinct bad `customer_id` values.

**3. Every real Oakhaven customer has ordered — verified, not assumed**

You might expect a `LEFT JOIN` from customers to sales to surface
customers with zero orders. Worth checking, not assuming:

```sql
SELECT COUNT(*) FROM bronze_customers c
LEFT JOIN bronze_sales s ON c.customer_id = s.customer_id
WHERE s.order_id IS NULL;
```

| COUNT(*) |
|---|
| 0 |

Zero. With 12,000 order lines spread across 600 customers, every one
of them shows up at least once in `bronze_sales` in this build. This
is a good habit regardless of the answer: run the `LEFT JOIN ... WHERE
... IS NULL` check rather than assuming gaps exist. Here it tells you
"no zero-order customers this time" — genuinely useful to know before
you write a report that assumes otherwise.

**4. `LEFT JOIN` still returns everything `INNER JOIN` would, plus the gaps**

```sql
SELECT COUNT(*) FROM bronze_sales s
LEFT JOIN bronze_products p ON s.product_id = p.product_id;
```

| COUNT(*) |
|---|
| 12000 |

All 12,000 rows survive — the 11,878 matched ones plus the 122
orphans, `NULL`-padded. `INNER JOIN` on the same pair returned 11,878
(Module 1). The difference between those two numbers is always your
orphan count.

## Common mistakes

- **Filtering on the wrong table's column to find gaps.** `WHERE
  p.category IS NULL` and `WHERE p.product_id IS NULL` are not the
  same check if `category` itself can be legitimately `NULL` for a
  *matched* row. Always test the matched table's id column (or another
  column guaranteed `NOT NULL` for real matches).
- **Putting the "is it missing" filter in the `ON` clause instead of
  `WHERE`.** `ON` decides how rows match; moving your missing-row
  filter into `ON` changes the join's behavior in ways that are easy
  to get wrong. Do the match in `ON`, then filter the result in
  `WHERE`.
- **Reading `LEFT JOIN` as "only the non-matching rows."** By default
  it returns *all* left-table rows — matched and unmatched. You add
  `WHERE right_table.id IS NULL` yourself to narrow down to just the
  gaps.
- **Getting left/right backwards.** `A LEFT JOIN B` keeps everything
  from `A`. If you meant to keep everything from `B` instead, either
  swap the table order or use `RIGHT JOIN` (SQLite supports it, but
  swapping is usually clearer).

## Key takeaways

- `LEFT JOIN` keeps every row from the left table; unmatched right-side
  columns come back `NULL`.
- `WHERE right_table.id IS NULL` after a `LEFT JOIN` is the standard
  pattern for finding rows with no match — orphans, gaps, missing
  relationships.
- In Oakhaven this surfaces the exact 122 orphan-`product_id` and 103
  orphan-`customer_id` sale rows that `INNER JOIN` would have deleted
  without comment.
- Not every hypothesis pans out — checking for customers with zero
  orders here returns 0 rows, and that's a useful, verified answer,
  not a wasted query.

---

<!-- nav -->
Previous: [Combining Tables with JOIN](01-combining-tables-with-join.md). Next: [GROUP BY](03-group-by.md). Exercises: [LEFT JOIN and Missing Data](../../exercises/02-intermediate/02-left-join-and-missing-data.md).
<!-- /nav -->
