# 6. Basic Aggregate Functions

<!-- nav -->
Previous: [5. NULL: the Absence of a Value](05-null-the-absence-of-a-value.md). Next: [7. Pattern Matching with LIKE](07-pattern-matching-with-like.md). Exercises: [6. Basic Aggregate Functions](../../exercises/01-beginner/06-basic-aggregate-functions.md).
<!-- /nav -->

## The idea

Everything so far has returned a set of individual rows — filtered,
sorted, limited, but still one row per record. Aggregate functions do
something different: they collapse many rows down into a single
summary number. "How many products do we have?" "What's our average
price?" "What's the cheapest and most expensive item we sell?" — these
aren't questions about any one row, they're questions about the whole
table (or a filtered slice of it).

## Why it matters

Aggregates are how you go from a pile of rows to an actual answer.
"150 products" is more useful than scrolling through 150 rows and
counting by eye. This is also the foundation for `GROUP BY` later
(Tier 2/3), where you'll compute these same summaries *per category*
or *per employee* instead of across the whole table — but that's a
later step. For now: one summary number per query, computed over
every row that makes it past any `WHERE` clause.

## Syntax: the five essentials

| Function | What it computes |
|---|---|
| `COUNT(*)` | Number of rows |
| `COUNT(column)` | Number of rows where `column` is **not NULL** |
| `SUM(column)` | Total of a numeric column |
| `AVG(column)` | Average of a numeric column |
| `MIN(column)` | Smallest value |
| `MAX(column)` | Largest value |

```sql
SELECT COUNT(*), SUM(column_name), AVG(column_name)
FROM table_name;
```

You can compute several aggregates in one query — each one collapses
the same set of rows down to one number, and they all show up as one
combined output row.

Note the important asymmetry between `COUNT(*)` and `COUNT(column)`:
`COUNT(*)` counts *rows*, full stop. `COUNT(column)` counts rows where
that specific column has a non-NULL value — which you learned about
last module. These can (and often do) give different numbers on the
same table.

## Try it

### How many products, total?

```sql
SELECT COUNT(*) FROM bronze_products;
```

| COUNT(*) |
|---|
| 150 |

### How many products actually have a recorded cost?

```sql
SELECT COUNT(unit_cost) FROM bronze_products;
```

| COUNT(unit_cost) |
|---|
| 143 |

150 total rows, but only 143 have a non-NULL `unit_cost` — the
remaining 7 are exactly the `NULL` rows you found in the previous
module. `COUNT(*)` and `COUNT(unit_cost)` disagreeing by 7 *is* the
NULL count, without having to write a separate `WHERE unit_cost IS
NULL` query.

### The full spread of prices, in one query

```sql
SELECT
    SUM(unit_price) AS total,
    AVG(unit_price) AS avg_price,
    MIN(unit_price) AS min_price,
    MAX(unit_price) AS max_price
FROM bronze_products;
```

| total | avg_price | min_price | max_price |
|---|---|---|---|
| 45056.1 | 300.374 | 6.67 | 812.71 |

One query, four different summary numbers about the same column —
`unit_price` across all 150 products sums to $45,056.10, averages
$300.37, and ranges from $6.67 to $812.71. Note the aliases (`AS
total`, `AS avg_price`, etc.) — without them, the output columns would
just be labeled with the raw expression (`SUM(unit_price)`), which
works but reads worse.

### Rounding a noisy average

```sql
SELECT ROUND(AVG(unit_price), 2) AS avg_price
FROM bronze_products;
```

| avg_price |
|---|
| 300.37 |

`AVG` on real data almost always produces more decimal places than
you want to look at. `ROUND(expression, decimal_places)` isn't an
aggregate function itself — it's a regular function that happens to
work nicely wrapped around one. You'll use this combination constantly.

### Multiple aggregates, mixing COUNT and AVG

```sql
SELECT
    COUNT(*) AS n_products,
    COUNT(unit_cost) AS n_with_cost,
    ROUND(AVG(unit_cost), 2) AS avg_cost
FROM bronze_products;
```

| n_products | n_with_cost | avg_cost |
|---|---|---|
| 150 | 143 | 159.05 |

Worth noticing: `AVG(unit_cost)` only averages over the 143 rows that
*have* a cost — the 7 NULL rows are excluded from the average
entirely, not treated as zero. That's usually exactly what you want,
but it's worth being deliberate about, since it can be easy to assume
"average over all 150 products" when it's really "average over the
143 that had data."

## Common mistakes

- **Mixing an aggregate with a plain column in `SELECT`, without
  `GROUP BY`.** `SELECT product_name, AVG(unit_price) FROM
  bronze_products;` doesn't do what it looks like — SQLite (unlike
  some databases) will actually let this run, but it silently picks an
  arbitrary `product_name` to pair with the single aggregated average,
  which is almost never meaningful. Combining row-level and
  whole-table-aggregate columns properly needs `GROUP BY`, which
  you'll meet in a later tier — for now, keep aggregate queries as
  *only* aggregate functions (plus maybe a `WHERE`), not a mix.
- **Assuming NULLs count as zero in SUM/AVG.** They don't — they're
  excluded entirely, which changes the denominator for `AVG`
  specifically. `AVG` is `SUM / COUNT(column)`, not `SUM /
  COUNT(*)`.
- **Forgetting `COUNT(*)` vs `COUNT(column)` are different
  questions.** `COUNT(*)` = "how many rows." `COUNT(column)` = "how
  many rows have a value in this column." Mixing them up gives you a
  subtly wrong row count whenever NULLs are present.
- **Not rounding.** `AVG` and `SUM` on `REAL` columns often produce
  long, ugly decimals. `ROUND(x, 2)` is cheap and makes output far
  more readable, especially for money.

## Key takeaways

- `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` collapse many rows into one
  summary number.
- `COUNT(*)` counts rows; `COUNT(column)` counts non-NULL values in
  that column — they can differ.
- `SUM` and `AVG` silently skip `NULL` values rather than treating
  them as zero.
- `ROUND(expression, n)` is your friend for cleaning up aggregate
  output.
- This module only covers whole-table aggregates — summarizing *per
  group* (e.g. per category) is `GROUP BY`, coming in a later tier.

---

<!-- nav -->
Previous: [5. NULL: the Absence of a Value](05-null-the-absence-of-a-value.md). Next: [7. Pattern Matching with LIKE](07-pattern-matching-with-like.md). Exercises: [6. Basic Aggregate Functions](../../exercises/01-beginner/06-basic-aggregate-functions.md).
<!-- /nav -->
