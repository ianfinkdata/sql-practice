# GROUP BY

## The idea

Aggregate functions like `COUNT()`, `SUM()`, and `AVG()` collapse many
rows into one number. By itself, `SELECT COUNT(*) FROM bronze_sales`
collapses the *entire table* into a single row. `GROUP BY` changes
that: it collapses rows into one row **per distinct value** of
whatever you group on, running the aggregate separately within each
group. "Total sales per category" and "order count per customer" are
both `GROUP BY` questions.

## Why it matters

Oakhaven's data begs for this: "how many order lines per category?"
"what's the total revenue per category?" are exactly the questions a
retailer asks constantly. But there's a trap waiting in this
particular database, and it's worth hitting it on purpose so you
recognize it later: `bronze_products.category` is messy. The 8 real
categories (`Footwear`, `Apparel`, `Camping & Hiking`, `Climbing`,
`Water Sports`, `Winter Sports`, `Accessories`, `Nutrition &
Hydration`) exist in the data as **40 different raw text variants** —
different casing, trailing spaces, `&` vs `and`. `GROUP BY` has no
idea `'CLIMBING'`, `'Climbing'`, and `'climbing'` mean the same thing
to a human — it groups on exact string equality, full stop. You'll see
this play out below. Module 6 (`TRIM`/`UPPER`/`REPLACE`) is the fix;
today's job is just to understand `GROUP BY` well enough to feel the
problem.

## Syntax

```sql
SELECT grouping_column, AGG_FUNC(some_column)
FROM table
GROUP BY grouping_column;
```

- Every column in the `SELECT` list must be either (a) named in
  `GROUP BY`, or (b) wrapped in an aggregate function. SQLite is more
  lenient about this than most databases, but relying on that
  leniency produces confusing results — stick to the rule.
- Common aggregates: `COUNT(*)`, `COUNT(column)` (skips `NULL`s),
  `SUM()`, `AVG()`, `MIN()`, `MAX()`.
- `GROUP BY` can list multiple columns, producing one row per unique
  *combination*.
- `GROUP BY` runs after `WHERE` (row-level filtering) but before
  `ORDER BY`.

## Try it

**1. Count and total order lines per raw category — the messy result**

```sql
SELECT p.category, COUNT(*) AS line_count,
       ROUND(SUM(s.quantity * s.unit_price), 2) AS rough_total
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY p.category
LIMIT 8;
```

| category | line_count | rough_total |
|---|---|---|
| ACCESSORIES | 238 | 230499.13 |
| ACCESSORIES  | 380 | 232172.76 |
| APPAREL | 223 | 203459.33 |
| APPAREL  | 324 | 310877.52 |
| Accessories | 690 | 403360.09 |
| Apparel | 766 | 695885.38 |
| CAMPING & HIKING | 77 | 96846.61 |
| CAMPING & HIKING  | 330 | 361686.68 |
| Camping and Hiking | 160 | 57385.13 |
| Climbing | 717 | 561782.81 |

Look closely at rows 1 and 2 (or 7 and 8) — those are *the same
category*, split into two groups because one string has a trailing
space and the other doesn't. "Accessories" revenue isn't $403,360.09;
it's scattered across at least four differently-spelled groups. This
is `GROUP BY` doing exactly what it's supposed to do (group on exact
matches) applied to a column that isn't clean yet.

**2. Confirm the scale of the problem**

```sql
SELECT COUNT(DISTINCT p.category)
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id;
```

| COUNT(DISTINCT p.category) |
|---|
| 40 |

40 groups for 8 real categories. Any report built directly on this
`GROUP BY` — a category leaderboard, a pie chart, anything — would be
wrong, not because `GROUP BY` is buggy, but because the input data has
40 spellings of 8 ideas. (Module 6 shows the fix; this module is about
recognizing the symptom.)

**3. Group by customer instead — a cleaner column, a cleaner result**

`bronze_sales.customer_id` is a plain integer, no casing problems
possible. Which customers order the most?

```sql
SELECT customer_id, COUNT(*) AS order_lines
FROM bronze_sales
GROUP BY customer_id
ORDER BY order_lines DESC
LIMIT 10;
```

| customer_id | order_lines |
|---|---|
| 41 | 43 |
| 408 | 41 |
| 67 | 40 |
| 572 | 39 |
| 343 | 39 |
| 318 | 37 |
| 173 | 37 |
| 402 | 36 |
| 344 | 36 |
| 174 | 36 |

**4. Group on more than one column**

```sql
SELECT p.category, s.channel, COUNT(*) AS line_count
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.category IN ('Climbing', 'CLIMBING', 'climbing')
GROUP BY p.category, s.channel
ORDER BY p.category, s.channel;
```

Grouping by `(category, channel)` together gives one row per
*combination* that actually occurs — a preview of how multi-column
`GROUP BY` behaves, still riding the same messy-category problem.

## Common mistakes

- **Selecting a column that's neither grouped nor aggregated.** e.g.
  `SELECT customer_id, product_id, COUNT(*) FROM bronze_sales GROUP BY
  customer_id` — SQLite will run this and silently pick *some*
  `product_id` value per group (usually the first one seen), which is
  almost never what you want. If a column isn't in `GROUP BY`, wrap it
  in an aggregate or drop it.
- **Assuming distinct-looking category counts mean distinct
  categories.** As shown above, `GROUP BY category` on
  `bronze_products` produces 40 groups, not 8 — always sanity-check
  `COUNT(DISTINCT column)` against what you expect before trusting a
  grouped report.
- **Trying to filter on an aggregate with `WHERE`.** `WHERE COUNT(*) >
  10` is invalid SQL — `WHERE` runs before grouping happens, so it has
  no aggregate to filter on yet. That's what `HAVING` (Module 4) is
  for.
- **Forgetting `ORDER BY` after `GROUP BY`.** Grouped results come
  back in whatever order SQLite happens to produce them, not sorted by
  count or total — add an explicit `ORDER BY` if order matters.

## Key takeaways

- `GROUP BY column` collapses rows into one row per distinct value of
  `column`, with aggregates computed per group.
- Every non-aggregated `SELECT` column must appear in `GROUP BY`.
- `GROUP BY` groups on *exact string equality* — it has no concept of
  "these mean the same thing."
- `bronze_products.category` groups into 40 raw variants instead of 8
  real categories — a direct, measurable consequence of messy source
  data, and the motivating problem for Module 6.
- Always ask "how many distinct values do I expect?" before trusting a
  `GROUP BY` result on an unfamiliar column.
