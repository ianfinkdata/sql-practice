# Exercises: CASE Expressions

<!-- nav -->
Curriculum: [CASE Expressions](../../curriculum/02-intermediate/05-case-expressions.md). Previous: [HAVING](04-having.md). Next: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Bucket products into price tiers**

Using `unit_price`, bucket every product into `'Budget'` (< 100),
`'Mid-range'` (< 400), or `'Premium'` (everything else), and count how
many products fall into each.

<details>
<summary>Show solution</summary>

```sql
SELECT
  CASE
    WHEN unit_price < 100 THEN 'Budget'
    WHEN unit_price < 400 THEN 'Mid-range'
    ELSE 'Premium'
  END AS price_tier,
  COUNT(*) AS n
FROM bronze_products
GROUP BY price_tier
ORDER BY n DESC;
```

| price_tier | n |
|---|---|
| Mid-range | 80 |
| Premium | 49 |
| Budget | 21 |

</details>

---

**2. Standardize `order_status` into 4 clean buckets**

`bronze_sales.order_status` has 6 raw values: `Completed`, `completed`,
`CANCELLED`, `Cancelled`, `Returned`, and `NULL`. Collapse them into
`'Completed'`, `'Cancelled'`, `'Returned'`, and `'Unknown'` (for
`NULL`), then count each bucket.

<details>
<summary>Show solution</summary>

```sql
SELECT
  CASE
    WHEN LOWER(order_status) = 'completed' THEN 'Completed'
    WHEN LOWER(order_status) = 'cancelled' THEN 'Cancelled'
    WHEN order_status = 'Returned' THEN 'Returned'
    ELSE 'Unknown'
  END AS clean_status,
  COUNT(*) AS n
FROM bronze_sales
GROUP BY clean_status
ORDER BY n DESC;
```

| clean_status | n |
|---|---|
| Completed | 7108 |
| Cancelled | 1916 |
| Returned | 1736 |
| Unknown | 1240 |

7108 + 1916 + 1736 + 1240 = 12000 — every row lands in exactly one
bucket, `NULL` included, thanks to the `ELSE 'Unknown'` catch-all.

</details>

---

**3. Flag the `discount_pct` whole-number bug**

The data dictionary documents a known bug: ~1% of rows with a nonzero
discount stored the whole-number form (e.g. `25` instead of `0.25`).
Use `CASE` to flag every row as `'likely_bugged'` (`discount_pct > 1`)
or `'normal'`, and count each group.

<details>
<summary>Show solution</summary>

```sql
SELECT
  CASE WHEN discount_pct > 1 THEN 'likely_bugged' ELSE 'normal' END AS discount_flag,
  COUNT(*) AS n
FROM bronze_sales
GROUP BY discount_flag;
```

| discount_flag | n |
|---|---|
| likely_bugged | 110 |
| normal | 11890 |

Exactly 110 rows — matching the facts sheet's documented count for
this exact bug (`bronze_sales.discount_pct whole-number bug (> 1)` =
110, ~0.92% of 12,000).

</details>

---

**4. CASE inside ORDER BY: list active customers first**

Using the same active/inactive logic from the lesson
(`LOWER(TRIM(is_active)) IN ('y','yes','true','1')`), sort
`bronze_customers` so likely-active customers come first, then by
`customer_id` ascending within each group. Show `customer_id` and
`is_active` for the first 5 rows.

<details>
<summary>Show solution</summary>

```sql
SELECT customer_id, is_active
FROM bronze_customers
ORDER BY CASE WHEN LOWER(TRIM(is_active)) IN ('y', 'yes', 'true', '1') THEN 0 ELSE 1 END,
         customer_id
LIMIT 5;
```

| customer_id | is_active |
|---|---|
| 1 | yes |
| 2 | yes |
| 3 | true |
| 4 | 1 |
| 5 | true |

`CASE` doesn't have to appear in `SELECT` — here it's used directly
inside `ORDER BY` to compute a sort key (`0` for likely-active, `1`
for everything else) without needing a subquery or a separate column.

</details>

---

**5. Conditional SUM: revenue split by the discount bug flag**

Using `SUM(CASE WHEN ... THEN ... ELSE 0 END)`, compute two totals in
one query: rough revenue (`quantity * unit_price`) for rows flagged as
`likely_bugged` (`discount_pct > 1`), and rough revenue for everything
else.

<details>
<summary>Show solution</summary>

```sql
SELECT
  SUM(CASE WHEN discount_pct > 1 THEN quantity * unit_price ELSE 0 END) AS bugged_total,
  SUM(CASE WHEN discount_pct <= 1 OR discount_pct IS NULL THEN quantity * unit_price ELSE 0 END) AS normal_total
FROM bronze_sales;
```

| bugged_total | normal_total |
|---|---|
| 97127.55 | 9783029.63 |

Two conditional sums, one pass over the table, no `GROUP BY` needed —
a common pattern once you need multiple differently-filtered totals
side by side in a single row instead of stacked as separate groups.

</details>

---

**6. Bucket order-line size AND standardize channel, together**

Combine two `CASE` expressions in one query: bucket `quantity *
unit_price` into `'Small'` (< 50), `'Medium'` (< 200), `'Large'`
(everything else), and standardize `channel` into `'Online'` or
`'In-Store'` (collapsing the 4 raw spellings). Count rows for each
combination.

<details>
<summary>Show solution</summary>

```sql
SELECT
  CASE
    WHEN quantity * unit_price < 50 THEN 'Small'
    WHEN quantity * unit_price < 200 THEN 'Medium'
    ELSE 'Large'
  END AS size_bucket,
  CASE
    WHEN LOWER(TRIM(channel)) = 'online' THEN 'Online'
    ELSE 'In-Store'
  END AS clean_channel,
  COUNT(*) AS n
FROM bronze_sales
GROUP BY size_bucket, clean_channel
ORDER BY size_bucket, clean_channel;
```

| size_bucket | clean_channel | n |
|---|---|---|
| Large | In-Store | 4858 |
| Large | Online | 4897 |
| Medium | In-Store | 684 |
| Medium | Online | 724 |
| Small | In-Store | 418 |
| Small | Online | 419 |

Two independent `CASE` expressions sitting side by side in the same
`SELECT`/`GROUP BY`, each solving its own piece of messiness (numeric
bucketing and text standardization), combining into one clean,
six-row summary out of what would otherwise be dozens of noisy raw
groups.

</details>

---

---

<!-- nav -->
Curriculum: [CASE Expressions](../../curriculum/02-intermediate/05-case-expressions.md). Previous: [HAVING](04-having.md). Next: [Cleaning Text: TRIM, UPPER, LOWER, REPLACE](06-cleaning-text-trim-upper-replace.md).
<!-- /nav -->
