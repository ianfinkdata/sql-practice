# 2. Filtering with WHERE

<!-- nav -->
Previous: [1. SELECT and FROM](01-select-and-from.md). Next: [3. Sorting with ORDER BY](03-sorting-with-order-by.md). Exercises: [2. Filtering with WHERE](../../exercises/01-beginner/02-filtering-with-where.md).
<!-- /nav -->

## The idea

`SELECT ... FROM` gets you every row in a table. Almost immediately,
that's too much — you rarely want *every* product or *every*
employee, you want the ones that match some condition: products over
$500, employees in the Sales department, orders placed after a certain
date. `WHERE` is how you say "only rows where this is true."

```sql
SELECT columns
FROM table_name
WHERE condition;
```

SQLite checks the condition against every row and keeps only the ones
where it evaluates to true. Everything else is dropped before it ever
reaches your output.

## Why it matters

Oakhaven has 150 products and 12,000 sales rows. Almost no real
question you'd ask ("what climbing gear do we sell," "which orders
were cancelled," "which employees are managers") wants *all* of that —
it wants a slice of it. `WHERE` is the tool that carves out that
slice. You'll use it in essentially every query from here on, often
combined with several conditions at once.

## Syntax: comparison operators

| Operator | Meaning |
|---|---|
| `=` | equal to |
| `!=` or `<>` | not equal to |
| `>` | greater than |
| `<` | less than |
| `>=` | greater than or equal to |
| `<=` | less than or equal to |

Text values go in single quotes (`'Climbing'`); numbers don't
(`unit_price > 500`).

## Syntax: combining conditions

- `AND` — both conditions must be true.
- `OR` — at least one condition must be true.
- `NOT` — flips a condition's truth.
- `IN (...)` — shorthand for "equals any of these values" (avoids a
  long chain of `OR category = ... OR category = ...`).

```sql
SELECT columns FROM table_name
WHERE condition_a AND condition_b;

SELECT columns FROM table_name
WHERE condition_a OR condition_b;

SELECT columns FROM table_name
WHERE column_name IN ('value_a', 'value_b');
```

## Try it

### A single equality condition

```sql
SELECT product_name, category, unit_price
FROM bronze_products
WHERE category = 'Climbing'
LIMIT 5;
```

| product_name | category | unit_price |
|---|---|---|
| Meridian Chalk Bags | Climbing | 155.94 |
| Backcountry Chalk Bags | Climbing | 141.92 |
| Glacier Carabiners | Climbing | 113.71 |
| Trailhead Ropes | Climbing | 87.28 |
| Meridian Chalk Bags | Climbing | 669.02 |

Note this only matches rows spelled exactly `Climbing` — 9 rows, all
told:

```sql
SELECT COUNT(*) FROM bronze_products WHERE category = 'Climbing';
```

| COUNT(*) |
|---|
| 9 |

But recall from Tier 0 that `category` has messy variants — `CLIMBING`,
`climbing`, `Climbing `. Text comparisons with `=` are exact and
case-sensitive by default, so this query *misses* every other-cased
climbing product. That's not a bug in your query — it's a preview of
exactly why Tier 2 exists. (Module 7 of this tier covers a
case-insensitive alternative, `LIKE`.)

### A numeric comparison

```sql
SELECT product_name, unit_price
FROM bronze_products
WHERE unit_price > 500
LIMIT 5;
```

| product_name | unit_price |
|---|---|
| Canyon Hiking Boots | 649.26 |
| Switchback Hat | 525.42 |
| Highline Backpacks | 812.71 |
| Ironpeak Hiking Boot | 553.01 |
| Foothill Electrolyte Mixes | 782.32 |

22 products in total are over $500:

```sql
SELECT COUNT(*) FROM bronze_products WHERE unit_price > 500;
```

| COUNT(*) |
|---|
| 22 |

### Combining conditions with AND

```sql
SELECT product_name, category, unit_price
FROM bronze_products
WHERE category = 'Climbing' AND unit_price > 200;
```

| product_name | category | unit_price |
|---|---|---|
| Meridian Chalk Bags | Climbing | 669.02 |
| Cascade Harnesse | Climbing | 379.33 |
| Alpine Harnesse | Climbing | 640.45 |

Only 3 of the 9 exact-cased `Climbing` products clear $200 — `AND`
narrows the results down from either condition alone.

### Combining conditions with OR and IN

These two queries are equivalent — `IN` is just cleaner to read once
you have more than one or two alternatives:

```sql
SELECT COUNT(*) FROM bronze_products
WHERE category = 'Climbing' OR category = 'Water Sports';
```

```sql
SELECT COUNT(*) FROM bronze_products
WHERE category IN ('Climbing', 'Water Sports');
```

Both return:

| COUNT(*) |
|---|
| 16 |

### NOT / not-equal

```sql
SELECT COUNT(*) FROM bronze_employees WHERE department != 'Sales';
```

| COUNT(*) |
|---|
| 30 |

Out of 35 total employees, 30 have a `department` that isn't exactly
`Sales` (5 do — try `WHERE department = 'Sales'` yourself to confirm).
Same caveat as above: `!=` is exact-match, so this also picks up
`SALES`/`sales` as "not equal to `Sales`," which is arguably wrong —
another reason messy casing needs real cleaning, not just careful
`WHERE` clauses, in the long run.

## Common mistakes

- **Using `=` for text and expecting case-insensitivity.** `WHERE
  category = 'climbing'` will *not* match `'Climbing'` — SQL string
  comparison is exact by default. (There is an exception you'll meet
  in module 7: `LIKE` is case-insensitive for ASCII text.)
- **Forgetting quotes around text values.** `WHERE category =
  Climbing` (no quotes) is interpreted as comparing to a column named
  `Climbing`, which doesn't exist — you'll get an error, not silently
  wrong results.
- **`AND` vs `OR` confusion.** `WHERE category = 'Climbing' AND
  category = 'Footwear'` returns *nothing* — a single row's `category`
  can't equal both values at once. If you mean "either of these," you
  want `OR` (or `IN`).
- **Forgetting `WHERE` filters before aggregating.** This isn't
  relevant yet (aggregates are module 6), but it's worth flagging
  early: `WHERE` filters *individual rows*, before any grouping or
  summarizing happens.

## Key takeaways

- `WHERE` filters rows to only the ones matching a condition — it's
  evaluated per-row, before the results are returned.
- Comparison operators: `=`, `!=`/`<>`, `>`, `<`, `>=`, `<=`.
- Combine conditions with `AND` (all must hold), `OR` (any can hold),
  and use `IN (...)` as shorthand for "equals one of these."
- Text comparisons with `=` are exact and case-sensitive — a fact
  that matters a lot once you're working with real, messy text
  columns like Oakhaven's `category`.

---

<!-- nav -->
Previous: [1. SELECT and FROM](01-select-and-from.md). Next: [3. Sorting with ORDER BY](03-sorting-with-order-by.md). Exercises: [2. Filtering with WHERE](../../exercises/01-beginner/02-filtering-with-where.md).
<!-- /nav -->
