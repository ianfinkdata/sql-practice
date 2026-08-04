# Exercises: Cleaning Text (TRIM, UPPER, LOWER, REPLACE)

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. How many raw `payment_method` spellings exist?**

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(DISTINCT payment_method) FROM bronze_sales;
```

| COUNT(DISTINCT payment_method) |
|---|
| 10 |

</details>

---

**2. TRIM + UPPER — how far does that get you?**

Apply `UPPER(TRIM(payment_method))` and count the distinct results.
List them.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(DISTINCT UPPER(TRIM(payment_method))) FROM bronze_sales;
```

| COUNT(...) |
|---|
| 6 |

```sql
SELECT DISTINCT UPPER(TRIM(payment_method)) AS cleaned
FROM bronze_sales ORDER BY cleaned;
```

| cleaned |
|---|
| CASH |
| CC |
| CREDIT CARD |
| DEBIT CARD |
| GIFT CARD |
| PAYPAL |

10 → 6. Casing and whitespace are fully resolved, but `CC` is still
sitting there as its own group, separate from `CREDIT CARD` — they
mean the same payment method but aren't the same *substring*, so
`UPPER`/`TRIM` alone can't merge them.

</details>

---

**3. Finish the job: fold `CC` into `CREDIT CARD`, and total revenue per clean method**

Add one `REPLACE` to the chain from #2 to merge `CC` into `CREDIT
CARD`, getting down to the 5 real payment methods. Then compute order
line count and rough revenue (`quantity * unit_price`) per clean
method.

<details>
<summary>Show solution</summary>

```sql
SELECT REPLACE(UPPER(TRIM(payment_method)), 'CC', 'CREDIT CARD') AS clean_method,
       COUNT(*) AS n, ROUND(SUM(quantity * unit_price), 2) AS rough_total
FROM bronze_sales
GROUP BY clean_method
ORDER BY rough_total DESC;
```

| clean_method | n | rough_total |
|---|---|---|
| CREDIT CARD | 3568 | 2949162.22 |
| DEBIT CARD | 2426 | 2010484.07 |
| PAYPAL | 2401 | 1989985.17 |
| CASH | 2373 | 1981618.13 |
| GIFT CARD | 1232 | 948907.59 |

Exactly 5 rows now, matching the canonical payment methods from the
data dictionary (`Credit Card`, `Cash`, `Debit Card`, `Gift Card`,
`PayPal`). Compare this cleanly-summed `CREDIT CARD` total against
Module 3's messy per-spelling breakdown — this is what that report
should have looked like all along.

*Careful with `REPLACE` order here:* because `REPLACE` matches
substrings, replacing `'CC'` with `'CREDIT CARD'` on the already-fully
uppercased string is safe — but if you ever apply a `'CC'` replacement
*before* fully normalizing case or on a column where `'CC'` could
appear as a substring of something else, double check it isn't
matching more than you intend.

</details>

---

**4. Measure (don't fully fix) the `state` mess**

Count distinct raw `state` values, then count distinct
`TRIM(UPPER(state))` values. Report both numbers.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(DISTINCT state) FROM bronze_customers;
```

| COUNT(DISTINCT state) |
|---|
| 190 |

```sql
SELECT COUNT(DISTINCT TRIM(UPPER(state))) FROM bronze_customers;
```

| COUNT(DISTINCT TRIM(UPPER(state))) |
|---|
| 105 |

190 → 105. Real, measurable progress from just two functions — but
still nearly double the ~50 states that should exist, because
`TRIM`/`UPPER` can't merge `'CA'` and `'California'` (different words,
not just different case). That gap is the honest limit of this
module's toolkit, called out directly in the lesson.

</details>

---

**5. Standardize `channel` into 2 canonical values, then total revenue**

`channel` has 4 raw spellings (`Online`, `online`, `In-Store`, `in
store`) but only 2 real values. Use a `CASE` expression built on
`LOWER(TRIM(channel))` to standardize, then total rough revenue per
clean channel.

<details>
<summary>Show solution</summary>

```sql
SELECT CASE WHEN LOWER(TRIM(channel)) = 'online' THEN 'Online' ELSE 'In-Store' END AS clean_channel,
       COUNT(*) AS n, ROUND(SUM(quantity * unit_price), 2) AS rough_total
FROM bronze_sales
GROUP BY clean_channel
ORDER BY rough_total DESC;
```

| clean_channel | n | rough_total |
|---|---|---|
| In-Store | 5960 | 4961504.4 |
| Online | 6040 | 4918652.78 |

Notice this uses `LOWER(TRIM(...))` inside a `CASE`, not a chain of
`REPLACE`s — for a column with only two real outcomes, a `CASE`
expression built on the normalized value is often more direct than
trying to `REPLACE` your way to the exact target spelling.

</details>

---

**6. Two-dimensional clean report: category × channel revenue**

Combine the full `category` cleaning chain from the lesson (`TRIM` +
`UPPER` + the two `REPLACE`s, getting to the 8 canonical categories)
with the `channel` cleaning from #5, and produce a clean revenue
breakdown by both dimensions together.

<details>
<summary>Show solution</summary>

```sql
SELECT
  REPLACE(REPLACE(TRIM(UPPER(p.category)), ' AND ', ' & '), 'FOOT WEAR', 'FOOTWEAR') AS clean_category,
  CASE WHEN LOWER(TRIM(s.channel)) = 'online' THEN 'Online' ELSE 'In-Store' END AS clean_channel,
  ROUND(SUM(s.quantity * s.unit_price), 2) AS rough_total
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
GROUP BY clean_category, clean_channel
ORDER BY clean_category, clean_channel;
```

| clean_category | clean_channel | rough_total |
|---|---|---|
| ACCESSORIES | In-Store | 531919.33 |
| ACCESSORIES | Online | 536556.35 |
| APPAREL | In-Store | 720531.61 |
| APPAREL | Online | 678295.03 |
| CAMPING & HIKING | In-Store | 520629.27 |
| CAMPING & HIKING | Online | 503526.77 |
| CLIMBING | In-Store | 754222.58 |
| CLIMBING | Online | 810813.14 |
| FOOTWEAR | In-Store | 607592.55 |
| FOOTWEAR | Online | 603656.97 |
| NUTRITION & HYDRATION | In-Store | 664561.18 |
| NUTRITION & HYDRATION | Online | 663290.56 |
| WATER SPORTS | In-Store | 405760.59 |
| WATER SPORTS | Online | 412633.11 |
| WINTER SPORTS | In-Store | 729704.99 |
| WINTER SPORTS | Online | 678758.11 |

Exactly 16 rows — 8 real categories times 2 real channels, no more,
no less. Both messy columns cleaned in the same query, joined
together, and grouped on the cleaned versions rather than the raw
ones. This is the shape a real report should take; compare it against
what Module 3's raw `GROUP BY p.category` produced (25+ noisy rows)
to see the full value of this module end to end.

</details>

---
