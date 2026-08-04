# 5. NULL: the Absence of a Value

<!-- nav -->
Previous: [4. Limiting with LIMIT (and OFFSET)](04-limiting-with-limit.md). Next: [6. Basic Aggregate Functions](06-basic-aggregate-functions.md). Exercises: [5. NULL: the Absence of a Value](../../exercises/01-beginner/05-null-the-absence-of-a-value.md).
<!-- /nav -->

## The idea

`NULL` is SQL's way of saying "no value here." Not zero, not an empty
string, not "unknown but exists somewhere" — genuinely, nothing was
recorded. A product with no `subcategory` recorded isn't saying its
subcategory is blank text; it's saying that piece of information was
never captured at all.

This distinction trips up almost everyone at first, because `NULL`
doesn't behave like a normal value in comparisons — and that's worth
slowing down for, because getting it wrong produces *wrong answers
that don't look like errors*, which is the most dangerous kind of
mistake in SQL.

## Why it matters

Real data has gaps. Oakhaven's bronze layer has them everywhere by
design: `bronze_products.subcategory` is missing for about 10% of
products, `bronze_products.unit_cost` is missing for a few percent,
`bronze_sales.employee_id` is missing for online orders with no rep
involved. Learning to find, filter on, and reason correctly about
`NULL` is not optional — it's a core skill for working with any
real-world table, and Oakhaven's tables have plenty of practice
material.

## Why `= NULL` never works

This is the single most important fact in this module: **you cannot
test for `NULL` with `=`.**

```sql
-- This does NOT find rows where subcategory is missing:
WHERE subcategory = NULL
```

Why not? `NULL` represents "unknown," and SQL treats any comparison
*involving* an unknown as itself unknown — not true, not false,
genuinely undetermined. `unit_cost = NULL` doesn't evaluate to true or
false; it evaluates to unknown, and `WHERE` only keeps rows where the
condition is *true* — so a row with an unknown result is silently
dropped, same as if it were false. The query doesn't error. It just
quietly returns nothing useful, every time, for any column.

The right tools are dedicated operators built for exactly this:

```sql
WHERE column_name IS NULL
WHERE column_name IS NOT NULL
```

## Syntax

```sql
SELECT columns FROM table_name
WHERE column_name IS NULL;

SELECT columns FROM table_name
WHERE column_name IS NOT NULL;
```

## Try it

### Products missing a subcategory

```sql
SELECT product_id, product_name, subcategory
FROM bronze_products
WHERE subcategory IS NULL
LIMIT 5;
```

| product_id | product_name | subcategory |
|---|---|---|
| 5 | Canyon Life Jackets |  |
| 28 | Basecamp Tents |  |
| 44 | Highline Approach Shoe |  |
| 45 | Canyon Water Filters |  |
| 51 | Alpine Camp Stove |  |

```sql
SELECT COUNT(*) FROM bronze_products WHERE subcategory IS NULL;
```

| COUNT(*) |
|---|
| 27 |

27 out of 150 products (18%) have no `subcategory` recorded — close to
the "~10% NULL" documented, and well within normal variance for a
generated dataset of this size.

### Products missing a unit cost

```sql
SELECT product_id, product_name, unit_cost
FROM bronze_products
WHERE unit_cost IS NULL
LIMIT 5;
```

| product_id | product_name | unit_cost |
|---|---|---|
| 9 | Ironpeak Base Layers |  |
| 20 | Switchback Sandals |  |
| 81 | Outrider Dry Bag |  |
| 88 | Glacier Jackets |  |
| 114 | Cascade Ski |  |

```sql
SELECT COUNT(*) FROM bronze_products WHERE unit_cost IS NULL;
```

| COUNT(*) |
|---|
| 7 |

### The flip side: IS NOT NULL

```sql
SELECT COUNT(*) FROM bronze_products WHERE subcategory IS NOT NULL;
```

| COUNT(*) |
|---|
| 123 |

123 + 27 = 150 — every product accounted for, either having a
subcategory or explicitly not.

### Proving `= NULL` doesn't work

```sql
SELECT COUNT(*) FROM bronze_products WHERE subcategory = NULL;
```

| COUNT(*) |
|---|
| 0 |

Zero — even though we just showed 27 rows really do have a `NULL`
subcategory. This is the trap in action: `subcategory = NULL` isn't
"wrong syntax" that errors out, it's *valid* SQL that always silently
returns nothing, for any column, in any table. If you ever see a query
using `= NULL` and getting suspiciously empty results, this is almost
certainly why.

## Common mistakes

- **Writing `WHERE column = NULL` or `WHERE column != NULL`.** Both
  silently return nothing useful. Always use `IS NULL` / `IS NOT
  NULL`.
- **Assuming NULL means zero or empty string.** They're three
  different things. `bronze_customers.email` can be `NULL` (missing
  entirely) *or* `''` (an empty string that was recorded) — those are
  different states, and `WHERE email IS NULL` won't catch the empty
  string case, or vice versa.
- **Forgetting NULLs when counting "everything."** `COUNT(*)` counts
  all rows regardless of NULLs, but `COUNT(column_name)` only counts
  rows where that specific column is *not* NULL — worth knowing now,
  and you'll use it directly in the next module.
- **Assuming NULL propagates predictably through arithmetic.** Not
  covered in depth here, but a preview: `5 + NULL` is `NULL`, not `5`.
  Unknown-plus-anything is still unknown.

## Key takeaways

- `NULL` means "no value recorded" — not zero, not empty string,
  genuinely absent.
- You can never test for `NULL` with `=` or `!=` — always use `IS
  NULL` / `IS NOT NULL`.
- `WHERE column = NULL` is valid SQL that silently matches nothing,
  which makes it a dangerous, quiet bug rather than a loud error.
- Oakhaven's bronze layer has real, meaningful NULLs throughout —
  `bronze_products.subcategory` and `bronze_products.unit_cost` are
  two of many you'll run into.

---

<!-- nav -->
Previous: [4. Limiting with LIMIT (and OFFSET)](04-limiting-with-limit.md). Next: [6. Basic Aggregate Functions](06-basic-aggregate-functions.md). Exercises: [5. NULL: the Absence of a Value](../../exercises/01-beginner/05-null-the-absence-of-a-value.md).
<!-- /nav -->
