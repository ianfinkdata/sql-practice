# HAVING


<!-- nav -->
Previous: [GROUP BY](03-group-by.md). Next: [CASE Expressions](05-case-expressions.md).
<!-- /nav -->

## The idea

`WHERE` filters individual rows *before* grouping happens. `HAVING`
filters *groups*, after `GROUP BY` has already collapsed rows and
computed aggregates. They look similar and sit close together in a
query, but they operate at different stages — that's the whole
concept.

Rule of thumb: if your filter mentions a raw column (`channel =
'Online'`, `order_date > '2024-01-01'`), it's a `WHERE`. If it
mentions an aggregate (`COUNT(*) > 10`, `SUM(quantity) < 0`), it's a
`HAVING`.

## Why it matters

"Which categories have more than 500 order lines?" and "which
customers have placed more than 30 orders?" are both questions about
*groups*, not individual rows — you can't answer them until after
`GROUP BY` has run. Oakhaven's messy `category` column (40 raw
variants, from Module 3) makes a great `HAVING` example precisely
because the groups are lopsided: a few variants dominate, most are
small. `HAVING` lets you filter straight to the ones that matter for a
given question, without pre-cleaning anything.

## Syntax

```sql
SELECT grouping_column, AGG_FUNC(some_column) AS agg_alias
FROM table
WHERE row_level_condition
GROUP BY grouping_column
HAVING aggregate_condition
ORDER BY agg_alias;
```

Clause order in the query is fixed: `WHERE` → `GROUP BY` → `HAVING` →
`ORDER BY`. That's also the logical order of execution — SQLite
filters rows, then groups them, then filters groups, then sorts.

## Try it

**1. WHERE fails on an aggregate — see the error yourself**

```sql
SELECT customer_id, COUNT(*)
FROM bronze_sales
WHERE COUNT(*) > 30
GROUP BY customer_id;
```

```
Error: in prepare, misuse of aggregate: COUNT()
```

SQLite is telling you exactly what's wrong: `COUNT()` isn't allowed in
`WHERE` because `WHERE` runs before any grouping/aggregating happens —
there's no count to compare yet at that stage.

**2. Fix it with HAVING**

```sql
SELECT customer_id, COUNT(*) AS order_lines
FROM bronze_sales
GROUP BY customer_id
HAVING COUNT(*) > 30
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

Same shape of question as Module 3's top-10, but now filtered to only
the customers clearing a specific threshold, computed with the
threshold applied at the group level.

**3. Which raw category variants have more than 500 lines?**

```sql
SELECT p.category, COUNT(*) AS line_count
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
GROUP BY p.category
HAVING COUNT(*) > 500
ORDER BY line_count DESC;
```

| category | line_count |
|---|---|
| Winter Sports | 838 |
| Apparel | 766 |
| Climbing | 717 |
| Accessories | 690 |
| WINTER SPORTS | 567 |
| climbing | 557 |
| Water Sports | 534 |

Seven of the 40 raw variants clear 500 lines each — the rest are
scattered across dozens of much smaller groups. `HAVING` cut straight
to "the ones that matter for this question" without needing to clean
anything first.

**4. Combine WHERE and HAVING in the same query**

```sql
SELECT p.category, COUNT(*) AS line_count,
       ROUND(SUM(s.quantity * s.unit_price), 2) AS rough_total
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE s.channel IN ('Online', 'online')
GROUP BY p.category
HAVING COUNT(*) > 100
ORDER BY rough_total DESC;
```

| category | line_count | rough_total |
|---|---|---|
| Apparel | 373 | 340488.16 |
| Climbing | 370 | 275824.19 |
| climbing | 297 | 272878.21 |
| Winter Sports | 424 | 263070.58 |
| WINTER SPORTS | 278 | 236817.67 |
| Nutrition & Hydration | 232 | 234442.91 |
| Water Sports | 265 | 226684.84 |
| FOOTWEAR | 214 | 217963.79 |
| CLIMBING | 164 | 196336.01 |
| Accessories | 330 | 191214.68 |
| CAMPING & HIKING | 167 | 190833.14 |
| footwear | 144 | 190264.52 |
| Camping & Hiking | 201 | 180905.62 |

`WHERE s.channel IN (...)` throws out non-online rows *before*
grouping (row-level filter); `HAVING COUNT(*) > 100` then throws out
small groups *after* grouping (group-level filter). Both clauses,
doing their separate jobs, in one query.

## Common mistakes

- **Using `HAVING` for a row-level condition.** `HAVING channel =
  'Online'` technically might work in SQLite in some cases, but it's
  the wrong tool and can behave unexpectedly once aggregates are
  involved — filter individual rows with `WHERE`, always, when the
  condition doesn't involve an aggregate.
- **Using `WHERE` for a group-level condition** — produces the exact
  error shown above. If you're comparing against `COUNT()`, `SUM()`,
  `AVG()`, etc., it belongs in `HAVING`.
- **Forgetting `HAVING` runs after `GROUP BY`, not instead of `WHERE`.**
  You can — and often should — use both in the same query; they're not
  alternatives to each other.
- **Referring to a `SELECT`-list alias inside `HAVING` and assuming
  it's guaranteed to work everywhere.** SQLite generally allows
  `HAVING order_lines > 30` if `order_lines` is aliased in `SELECT`,
  but writing out the full aggregate expression (`HAVING COUNT(*) >
  30`) is more portable and avoids surprises in stricter databases.

## Key takeaways

- `WHERE` filters rows before grouping; `HAVING` filters groups after
  aggregation.
- Putting an aggregate function in `WHERE` is a hard error in SQLite.
- Clause order is fixed: `WHERE` → `GROUP BY` → `HAVING` → `ORDER BY`.
- `WHERE` and `HAVING` combine naturally in one query — row-level
  filtering, then group-level filtering.
- `HAVING` is exactly the tool for "which groups clear a threshold" —
  no cleaning required first, even on a messy column like
  `bronze_products.category`.

---

<!-- nav -->
Previous: [GROUP BY](03-group-by.md). Next: [CASE Expressions](05-case-expressions.md).
<!-- /nav -->
