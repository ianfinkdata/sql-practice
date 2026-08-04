# CASE Expressions


<!-- nav -->
Previous: [HAVING](04-having.md). Next: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md).
<!-- /nav -->

## The idea

`CASE` is SQL's if/else-if/else, used inside a `SELECT` list (or
`WHERE`, or `ORDER BY`, or almost anywhere an expression is allowed).
It checks a list of conditions top to bottom and returns the value
tied to the first one that's true — like a chain of `if / elif / elif
/ else` in Python, but as an expression that produces a value per row.

Two shapes:

```sql
-- "searched" form: each WHEN has its own condition
CASE
  WHEN condition1 THEN result1
  WHEN condition2 THEN result2
  ELSE fallback
END

-- "simple" form: compares one expression against a list of values
CASE column
  WHEN 'a' THEN result1
  WHEN 'b' THEN result2
  ELSE fallback
END
```

## Why it matters

Two everyday jobs `CASE` is built for, both real Oakhaven needs:

1. **Bucketing a continuous number into readable tiers** — "was this a
   small, medium, or large order line?" There's no column for that; you
   derive it.
2. **Standardizing a messy value into a small, known set of outputs**
   — `bronze_customers.is_active` stores eleven different raw text
   values (`Y`, `y`, `yes`, `true`, `1`, `N`, `n`, `no`, `false`, `0`,
   and `NULL`) that really only mean three things: active, inactive,
   or unknown. `CASE` is how you collapse eleven strings down to three
   meaningful buckets in one expression.

## Syntax

```sql
SELECT column,
  CASE
    WHEN condition1 THEN 'label1'
    WHEN condition2 THEN 'label2'
    ELSE 'label_default'
  END AS derived_column
FROM table;
```

- Conditions are checked **in order**; the first match wins, later
  `WHEN`s are never evaluated once one matches.
- `ELSE` is optional — if you omit it and no `WHEN` matches, the
  result is `NULL`. Usually safer to include an explicit `ELSE`.
- `CASE` produces one value per row; it's an expression, not a
  standalone statement, so it can be used anywhere a column can:
  `SELECT`, `WHERE`, `ORDER BY`, even inside `SUM(CASE WHEN ... THEN 1
  ELSE 0 END)` for conditional counting.

## Try it

**1. Bucket order-line amounts into size tiers**

```sql
SELECT order_id, order_line_id,
       ROUND(quantity * unit_price, 2) AS line_amount,
       CASE
         WHEN quantity * unit_price < 50 THEN 'Small'
         WHEN quantity * unit_price < 200 THEN 'Medium'
         ELSE 'Large'
       END AS size_bucket
FROM bronze_sales
LIMIT 5;
```

| order_id | order_line_id | line_amount | size_bucket |
|---|---|---|---|
| 1 | 1 | 1227.32 | Large |
| 1 | 2 | 1208.25 | Large |
| 2 | 1 | 325.89 | Large |
| 2 | 2 | 433.36 | Large |
| 3 | 1 | 106.14 | Medium |

**2. Combine CASE with GROUP BY to count each bucket**

```sql
SELECT
  CASE
    WHEN quantity * unit_price < 50 THEN 'Small'
    WHEN quantity * unit_price < 200 THEN 'Medium'
    ELSE 'Large'
  END AS size_bucket,
  COUNT(*) AS n
FROM bronze_sales
GROUP BY size_bucket
ORDER BY n DESC;
```

| size_bucket | n |
|---|---|
| Large | 9755 |
| Medium | 1408 |
| Small | 837 |

`GROUP BY` can group directly on a `CASE` expression, not just a raw
column — the derived label becomes the grouping key.

**3. Standardize `is_active`'s eleven raw values into three buckets**

First, the raw mess (already seen in the data dictionary, confirmed
live):

```sql
SELECT is_active, COUNT(*) AS n
FROM bronze_customers
GROUP BY is_active
ORDER BY is_active;
```

| is_active | n |
|---|---|
| *(NULL)* | 31 |
| 0 | 18 |
| 1 | 103 |
| N | 29 |
| Y | 101 |
| false | 9 |
| n | 21 |
| no | 14 |
| true | 93 |
| y | 92 |
| yes | 89 |

Eleven groups for a value that's fundamentally yes/no/unknown. `CASE`
collapses it:

```sql
SELECT
  CASE
    WHEN LOWER(TRIM(is_active)) IN ('y', 'yes', 'true', '1') THEN 'Active'
    WHEN LOWER(TRIM(is_active)) IN ('n', 'no', 'false', '0') THEN 'Inactive'
    ELSE 'Unknown'
  END AS status,
  COUNT(*) AS n
FROM bronze_customers
GROUP BY status
ORDER BY n DESC;
```

| status | n |
|---|---|
| Active | 478 |
| Inactive | 91 |
| Unknown | 31 |

478 + 91 + 31 = 600 — every customer accounted for. Note the `ELSE
'Unknown'` catch-all: it's what turns the 31 `NULL` rows (and any
future unexpected value) into a labeled bucket instead of vanishing or
erroring.

**4. CASE inside an aggregate — conditional counting**

```sql
SELECT
  SUM(CASE WHEN channel IN ('Online', 'online') THEN 1 ELSE 0 END) AS online_lines,
  SUM(CASE WHEN channel IN ('In-Store', 'in store') THEN 1 ELSE 0 END) AS instore_lines,
  COUNT(*) AS total_lines
FROM bronze_sales;
```

This is a common pattern: `CASE` turns a condition into a 1-or-0 per
row, and `SUM()` adds those up — effectively a conditional `COUNT`
without needing a separate query per condition.

## Common mistakes

- **Relying on WHEN order when conditions overlap.** `CASE` uses the
  *first* matching `WHEN`, top to bottom. If your ranges aren't
  written in the order you think (e.g. checking `> 200` after already
  checking `> 50`), you can get silently wrong buckets. Write ranges
  narrowest/most-specific first if there's any ambiguity.
- **Omitting `ELSE` and being surprised by `NULL`.** Without an
  `ELSE`, any row matching no `WHEN` becomes `NULL` in the result —
  which then often disappears from `GROUP BY` output or fails
  comparisons downstream. Default to writing an explicit `ELSE`.
- **Forgetting to normalize case/whitespace before comparing.**
  `WHEN is_active = 'Y'` alone misses `'y'`. That's why the example
  above wraps the column in `LOWER(TRIM(is_active))` before comparing
  — Module 6 covers those functions in depth.
- **Using `CASE` where a simple boolean expression would do.** `CASE
  WHEN quantity > 0 THEN 1 ELSE 0 END` is fine, but sometimes you
  don't need the label at all — know when a plain `WHERE quantity > 0`
  answers the actual question more directly.

## Key takeaways

- `CASE WHEN ... THEN ... ELSE ... END` is an expression that returns
  one value per row based on the first matching condition.
- It works anywhere an expression is valid: `SELECT`, `WHERE`, `ORDER
  BY`, inside aggregates.
- Great for bucketing continuous values (order amounts into size
  tiers) and for standardizing messy categorical text
  (`is_active`'s 11 raw values into Active/Inactive/Unknown).
- Always include an explicit `ELSE` unless you deliberately want
  unmatched rows to become `NULL`.
- Combine with `LOWER(TRIM(...))` when comparing against text that
  might vary in case or whitespace — Module 6 goes deep on that.

---

<!-- nav -->
Previous: [HAVING](04-having.md). Next: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md).
<!-- /nav -->
