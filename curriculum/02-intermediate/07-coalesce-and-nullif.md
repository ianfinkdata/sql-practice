# COALESCE and NULLIF


<!-- nav -->
Previous: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md). Next: [Subqueries and Derived Tables](08-subqueries-and-derived-tables.md).
<!-- /nav -->

## The idea

Two small, opposite-purposed functions for handling `NULL`:

- **`COALESCE(a, b, c, ...)`** returns the first argument in the list
  that is *not* `NULL`. Its most common form is two arguments:
  `COALESCE(column, 'fallback')` — "use `column`, but if it's `NULL`,
  use this default instead."
- **`NULLIF(a, b)`** returns `NULL` if `a` equals `b`, otherwise
  returns `a`. It turns a specific *value* into `NULL` — the reverse
  direction of `COALESCE`.

They're often used together: `NULLIF` first converts an "empty but not
technically NULL" value (like `''`) into a real `NULL`, then
`COALESCE` supplies the fallback for it.

## Why it matters

`bronze_products.subcategory` is `NULL` for about 10% of products —
`COALESCE` is the direct fix for displaying those rows sensibly
instead of a blank cell. `bronze_customers.email` is messier: it's
`NULL` for ~4.3% of customers *and* an empty string `''` for another
~1.5%. Those are two different problems that look almost identical in
a result grid, and `COALESCE` alone only catches one of them —
`COALESCE(email, 'x')` does nothing for a row where `email` is `''`,
because `''` is a value, not `NULL`. That's exactly what `NULLIF` is
for, and you'll see the bug happen live below.

## Syntax

```sql
COALESCE(expr1, expr2, ..., exprN)  -- first non-NULL wins
NULLIF(expr1, expr2)                -- NULL if expr1 = expr2, else expr1
```

- `COALESCE` accepts two or more arguments and evaluates left to
  right, stopping at the first non-`NULL` value.
- `NULLIF(a, b)` is shorthand for `CASE WHEN a = b THEN NULL ELSE a
  END`.
- Combine them: `COALESCE(NULLIF(column, 'bad_value'), 'fallback')` —
  "treat `bad_value` as if it were `NULL`, then apply the fallback."

## Try it

**1. Fill in missing `subcategory` values**

```sql
SELECT product_id, product_name, subcategory,
       COALESCE(subcategory, 'Unspecified') AS subcategory_filled
FROM bronze_products
WHERE subcategory IS NULL
LIMIT 5;
```

| product_id | product_name | subcategory | subcategory_filled |
|---|---|---|---|
| 5 | Canyon Life Jackets | NULL | Unspecified |
| 28 | Basecamp Tents | NULL | Unspecified |
| 44 | Highline Approach Shoe | NULL | Unspecified |
| 45 | Canyon Water Filters | NULL | Unspecified |
| 51 | Alpine Camp Stove | NULL | Unspecified |

27 of 150 products have `subcategory IS NULL`. Grouping on the
`COALESCE`d version instead of the raw column keeps those 27 visible
as their own labeled group rather than either erroring or vanishing:

```sql
SELECT COALESCE(subcategory, 'Unspecified') AS subcat, COUNT(*) AS n
FROM bronze_products
GROUP BY subcat
ORDER BY n DESC
LIMIT 6;
```

| subcat | n |
|---|---|
| Unspecified | 27 |
| Chalk Bags | 7 |
| Jackets | 6 |
| Energy Bars | 6 |
| Sleeping Bags | 5 |
| Hydration Packs | 5 |

**2. `email` has two different kinds of "missing" — see them both**

```sql
SELECT
  CASE WHEN email IS NULL THEN 'NULL'
       WHEN email = '' THEN 'empty string'
       ELSE 'has value' END AS email_state,
  COUNT(*) AS n
FROM bronze_customers
GROUP BY email_state;
```

| email_state | n |
|---|---|
| NULL | 26 |
| empty string | 9 |
| has value | 565 |

**3. Catch `COALESCE` doing nothing for empty strings — the bug, live**

```sql
SELECT customer_id, email,
       COALESCE(email, 'no-email-on-file') AS coalesce_only,
       COALESCE(NULLIF(email, ''), 'no-email-on-file') AS coalesce_plus_nullif
FROM bronze_customers
WHERE email = ''
LIMIT 5;
```

| customer_id | email | coalesce_only | coalesce_plus_nullif |
|---|---|---|---|
| 88 |  |  | no-email-on-file |
| 135 |  |  | no-email-on-file |
| 228 |  |  | no-email-on-file |
| 295 |  |  | no-email-on-file |
| 322 |  |  | no-email-on-file |

Look at the `coalesce_only` column: still blank. `COALESCE(email,
'no-email-on-file')` only substitutes when `email` **IS NULL** — an
empty string `''` is a perfectly valid non-`NULL` value as far as
`COALESCE` is concerned, so it sails through untouched. Wrapping
`email` in `NULLIF(email, '')` first converts `''` into a real `NULL`,
*then* `COALESCE` catches it. This is the single most common
`COALESCE` mistake, so seeing it fail before fixing it is worth the
extra step.

**4. `NULLIF` for its classic purpose: guarding a division**

```sql
SELECT product_id, unit_cost, unit_price,
       ROUND(unit_price / NULLIF(unit_cost, 0), 2) AS markup_ratio
FROM bronze_products
WHERE unit_cost IS NOT NULL
ORDER BY product_id
LIMIT 5;
```

| product_id | unit_cost | unit_price | markup_ratio |
|---|---|---|---|
| 1 | 269.63 | 649.26 | 2.41 |
| 2 | 231.98 | 348.55 | 1.5 |
| 3 | 136.25 | 286.86 | 2.11 |
| 4 | 72.33 | 155.94 | 2.16 |
| 5 | 193.92 | 310.93 | 1.6 |

`unit_cost` never actually equals `0` in this build (verified —
`SELECT COUNT(*) FROM bronze_products WHERE unit_cost = 0` returns
`0`), so this particular guard never triggers here. It's still worth
writing defensively: `unit_price / unit_cost` would throw a
divide-by-zero error the moment a `0` did show up, and `NULLIF`
sidesteps that by turning a `0` divisor into `NULL` first — `x / NULL`
is just `NULL`, not an error. (`unit_cost` does go *negative* for 2
products here — a different, real messiness that division-guarding
doesn't touch; that's a `WHERE`/`CASE` problem, not a `NULLIF` one.)

## Common mistakes

- **Expecting `COALESCE` to catch empty strings.** As shown above, it
  only reacts to `NULL`. Pre-process with `NULLIF(column, '')` if
  empty string should be treated the same as missing.
- **Forgetting `COALESCE` evaluates left to right and stops early.**
  `COALESCE(a, b, c)` never even looks at `c` if `a` is non-`NULL` —
  order your fallback arguments from most-preferred to
  least-preferred.
- **Using `NULLIF` backwards.** `NULLIF(a, b)` returns `NULL` when `a
  = b` — it does *not* mean "a unless null, then b" (that's
  `COALESCE`). Mixing the two up is an easy naming-based mistake.
- **Applying `COALESCE`'s fallback where it changes the meaning of an
  aggregate.** `COALESCE(subcategory, 'Unspecified')` is fine for
  display/grouping, but don't forget the fallback label itself is now
  a made-up string — don't accidentally treat "Unspecified" rows as if
  they were a real subcategory in downstream logic.

## Key takeaways

- `COALESCE(a, b, ...)` returns the first non-`NULL` argument — a
  general-purpose default/fallback tool.
- `NULLIF(a, b)` returns `NULL` when `a` equals `b` — used to turn a
  specific "junk" value into a real `NULL` so other `NULL`-aware logic
  (like `COALESCE`) can catch it.
- `bronze_customers.email` is `NULL` for 26 customers and `''` for 9
  more — two distinct kinds of missing that `COALESCE(email, ...)`
  alone only half-solves; `COALESCE(NULLIF(email, ''), ...)` solves
  both.
- `NULLIF(divisor, 0)` is the standard idiom for guarding against
  divide-by-zero without an error.

---

<!-- nav -->
Previous: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md). Next: [Subqueries and Derived Tables](08-subqueries-and-derived-tables.md).
<!-- /nav -->
