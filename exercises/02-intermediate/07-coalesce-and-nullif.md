# Exercises: COALESCE and NULLIF

<!-- nav -->
Curriculum: [COALESCE and NULLIF](../../curriculum/02-intermediate/07-coalesce-and-nullif.md). Previous: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md). Next: [Subqueries and Derived Tables](08-subqueries-and-derived-tables.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Fill missing emails with a placeholder**

Return `customer_id`, `email`, and a `email_filled` column using
`COALESCE` to substitute `'unknown@oakhaven.local'` for `NULL` emails.
Show the first 5 rows where `email IS NULL`.

<details>
<summary>Show solution</summary>

```sql
SELECT customer_id, email, COALESCE(email, 'unknown@oakhaven.local') AS email_filled
FROM bronze_customers
WHERE email IS NULL
LIMIT 5;
```

| customer_id | email | email_filled |
|---|---|---|
| 14 |  | unknown@oakhaven.local |
| 32 |  | unknown@oakhaven.local |
| 50 |  | unknown@oakhaven.local |
| 85 |  | unknown@oakhaven.local |
| 122 |  | unknown@oakhaven.local |

</details>

---

**2. Fill missing `state`, catching both NULL and empty string**

`state` is `NULL` for 17 customers and `''` for another 10. Write a
query returning `customer_id`, `state`, and `state_filled` (using
`COALESCE` + `NULLIF` so both cases become `'Unknown'`), limited to
the first 5 rows matching either condition.

<details>
<summary>Show solution</summary>

```sql
SELECT customer_id, state, COALESCE(NULLIF(state, ''), 'Unknown') AS state_filled
FROM bronze_customers
WHERE state IS NULL OR state = ''
LIMIT 5;
```

| customer_id | state | state_filled |
|---|---|---|
| 7 |  | Unknown |
| 29 |  | Unknown |
| 46 |  | Unknown |
| 91 |  | Unknown |
| 97 |  | Unknown |

```sql
SELECT COUNT(*) FROM bronze_customers WHERE state IS NULL;
```

| COUNT(*) |
|---|
| 17 |

```sql
SELECT COUNT(*) FROM bronze_customers WHERE state = '';
```

| COUNT(*) |
|---|
| 10 |

27 total customers (17 + 10) needed the `NULLIF` step to be caught —
plain `COALESCE(state, 'Unknown')` alone would have left the 10
empty-string rows untouched, same bug as Module 7's email example.

</details>

---

**3. Products with an "Unspecified" subcategory, for one brand**

For brand `'Elkstone'`, group products by `COALESCE(subcategory,
'Unspecified')` and count how many products fall into each
subcategory (including the unspecified bucket).

<details>
<summary>Show solution</summary>

```sql
SELECT brand, COALESCE(subcategory, 'Unspecified') AS subcat, COUNT(*) AS n
FROM bronze_products
WHERE brand = 'Elkstone'
GROUP BY brand, subcat
ORDER BY n DESC;
```

| brand | subcat | n |
|---|---|---|
| Elkstone | Hydration Packs | 2 |
| Elkstone | Unspecified | 2 |
| Elkstone | Chalk Bags | 1 |
| Elkstone | Electrolyte Mixes | 1 |
| Elkstone | Ropes | 1 |
| Elkstone | Sleeping Bags | 1 |
| Elkstone | Trail Running Shoes | 1 |
| Elkstone | Winter Gloves | 1 |

2 of Elkstone's 10 products have no `subcategory` on file — grouping
on the raw column would have made those 2 rows vanish from the report
(`GROUP BY` treats `NULL` as its own group, but a bare `NULL` label is
easy to overlook); `COALESCE` turns them into a visible, countable
bucket instead.

</details>

---

**4. Best available contact: prefer email, fall back to phone**

For customers with a missing or empty `email` but a non-null `phone`,
show `customer_id`, `email`, `phone`, and a `best_contact` column that
picks `email` first, falls back to `phone`, and finally to `'no
contact on file'` if neither exists. Show the first 5 matching rows.

<details>
<summary>Show solution</summary>

```sql
SELECT customer_id, email, phone,
       COALESCE(NULLIF(email, ''), NULLIF(phone, ''), 'no contact on file') AS best_contact
FROM bronze_customers
WHERE (email IS NULL OR email = '') AND phone IS NOT NULL
LIMIT 5;
```

| customer_id | email | phone | best_contact |
|---|---|---|---|
| 14 |  | +1 759 362 5645 | +1 759 362 5645 |
| 32 |  | (281) 469-9386 | (281) 469-9386 |
| 50 |  | +1 250 470 6432 | +1 250 470 6432 |
| 85 |  | (519) 315-2771 | (519) 315-2771 |
| 88 |  | 541.323.1956 | 541.323.1956 |

`COALESCE` with three arguments here: try `email` (via `NULLIF` to
also catch `''`), then `phone` (same treatment), then the literal
fallback string — each argument only gets evaluated as a fallback for
the one before it.

</details>

---

**5. How many customers have neither a usable email nor phone?**

Using the same `COALESCE(NULLIF(email, ''), NULLIF(phone, ''))`
pattern (no final string fallback this time), count how many
customers get `NULL` back — meaning both fields are missing or empty.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_customers
WHERE COALESCE(NULLIF(email, ''), NULLIF(phone, '')) IS NULL;
```

| COUNT(*) |
|---|
| 2 |

Only 2 of 600 customers have no usable contact method at all —
`COALESCE` returning `NULL` here means every argument passed to it
evaluated to `NULL`, which is itself useful information, not just a
display artifact.

</details>

---

**6. Guard a ratio calculation against a hypothetical zero**

`unit_cost` never actually equals `0` in this build, but writing
defensive SQL means guarding anyway. Compute `unit_price /
NULLIF(unit_cost, 0)` as `markup_ratio` for all products where
`unit_cost` is not `NULL`, and separately confirm no `unit_cost` is
actually `0` (so you know the guard isn't currently doing anything,
but would if the data changed). Show the 5 lowest markup ratios.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_products WHERE unit_cost = 0;
```

| COUNT(*) |
|---|
| 0 |

```sql
SELECT product_id, unit_cost, unit_price,
       ROUND(unit_price / NULLIF(unit_cost, 0), 2) AS markup_ratio
FROM bronze_products
WHERE unit_cost IS NOT NULL
ORDER BY markup_ratio ASC
LIMIT 5;
```

| product_id | unit_cost | unit_price | markup_ratio |
|---|---|---|---|
| 30 | -131.94 | 240.4 | -1.82 |
| 19 | -4.19 | 6.67 | -1.59 |
| 146 | 199.28 | 259.26 | 1.3 |
| 14 | 172.07 | 225.67 | 1.31 |
| 45 | 153.36 | 201.29 | 1.31 |

The two lowest (and only negative) markup ratios come from the two
products with negative `unit_cost` documented in the data
dictionary — `NULLIF` was never the tool for that particular
messiness (negative cost isn't zero cost), which is worth noticing:
`NULLIF(unit_cost, 0)` protects against exactly one specific bad
value, not "anything weird about this column."

</details>

---

---

<!-- nav -->
Curriculum: [COALESCE and NULLIF](../../curriculum/02-intermediate/07-coalesce-and-nullif.md). Previous: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md). Next: [Subqueries and Derived Tables](08-subqueries-and-derived-tables.md).
<!-- /nav -->
