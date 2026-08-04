# Exercises: Pattern Matching with LIKE

<!-- nav -->
Curriculum: [7. Pattern Matching with LIKE](../../curriculum/01-beginner/07-pattern-matching-with-like.md). Previous: [6. Basic Aggregate Functions](06-basic-aggregate-functions.md). Next: [8. DISTINCT and Duplicates](08-distinct-and-duplicates.md).
<!-- /nav -->

### 1. Contains a word

Write a query for every product whose `product_name` contains the
word "Jacket" anywhere in it.

<details>
<summary>Show solution</summary>

```sql
SELECT product_name
FROM bronze_products
WHERE product_name LIKE '%Jacket%';
```

| product_name |
|---|
| Ridge Jackets |
| Canyon Life Jackets |
| Northbound Jackets |
| Ridge Jackets |
| Wayfinder Jacket |
| Backcountry Jackets |
| Ridge Jackets |
| Glacier Jackets |
| Northbound Life Jacket |
| Ironpeak Life Jackets |
| Basecamp Life Jackets |

11 rows — note `%Jacket%` catches both "Jacket" and "Jackets" since
the trailing `%` absorbs the extra "s".

</details>

### 2. Starts with a letter, case-insensitively

Write a query for employees whose `last_name` starts with "H" — and
notice whether it catches lowercase-starting names too.

<details>
<summary>Show solution</summary>

```sql
SELECT first_name, last_name
FROM bronze_employees
WHERE last_name LIKE 'H%';
```

| first_name | last_name |
|---|---|
| Carol | Harrison |
| Keith | HUNT |
| Scott | henderson |
| Ashlee | Hall |

4 rows — including `henderson` (lowercase h), because `LIKE` is
case-insensitive. A `WHERE last_name LIKE 'h%'` (lowercase pattern)
would return the exact same 4 rows.

</details>

### 3. Contains, on a different column

Write a query for the distinct brand names that contain "gear"
anywhere, in any casing.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT brand
FROM bronze_products
WHERE brand LIKE '%gear%';
```

| brand |
|---|
| Stonepine Gear |
| Windrow Gear |
| Ambervale Gear |
| Bramblewood Gear |

(`DISTINCT` here is a preview of module 8 — it just removes duplicate
brand names from the output, since several products can share the
same brand.)

</details>

### 4. Ends with a domain

Write a query for every employee email ending in `oakhaven.com`. How
many are there, and does that match what you'd expect given how many
employees have a non-NULL email at all?

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_employees WHERE email LIKE '%oakhaven.com';
```

| COUNT(*) |
|---|
| 31 |

31 — exactly matching the `COUNT(email)` result from module 6's
exercises. That makes sense: every non-NULL employee email in this
dataset follows the `first.last@oakhaven.com` pattern, so "has an
email" and "email ends in oakhaven.com" describe the same 31 rows.

</details>

### 5. Underscore wildcard

Write a query for products whose `sku` matches the pattern
`CLI-000_` — "CLI-000" followed by exactly one more character.

<details>
<summary>Show solution</summary>

```sql
SELECT sku FROM bronze_products WHERE sku LIKE 'CLI-000_';
```

| sku |
|---|
| CLI-0004 |

Just one row in this range — `CLI-0004` (the 4th digit is the one
`_` character). If Oakhaven had a `CLI-00010` or higher, it would *not*
match this pattern (too many trailing characters for a single `_`) —
you'd need `CLI-000%` or `CLI-00__` to catch those.

</details>

### 6. LIKE vs = on a messy column

Compare exact match against `LIKE` for `category = 'CLIMBING'` — count
both ways.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_products WHERE category = 'CLIMBING';
```

| COUNT(*) |
|---|
| 4 |

```sql
SELECT COUNT(*) FROM bronze_products WHERE category LIKE 'CLIMBING';
```

| COUNT(*) |
|---|
| 20 |

`=` only finds the 4 rows spelled exactly `CLIMBING` (all caps).
`LIKE` finds 20 — all rows spelled `CLIMBING`, `Climbing`, or
`climbing` (4 + 9 + 7), since `LIKE` ignores case entirely. It still
wouldn't catch a hypothetical `CLIMBING ` (trailing space) as a
*different* value from `CLIMBING` — `LIKE` fixes casing, not
whitespace.

</details>

---

<!-- nav -->
Curriculum: [7. Pattern Matching with LIKE](../../curriculum/01-beginner/07-pattern-matching-with-like.md). Previous: [6. Basic Aggregate Functions](06-basic-aggregate-functions.md). Next: [8. DISTINCT and Duplicates](08-distinct-and-duplicates.md).
<!-- /nav -->
