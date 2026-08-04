# Exercises: LEFT JOIN and Missing Data

<!-- nav -->
Curriculum: [LEFT JOIN and Missing Data](../../curriculum/02-intermediate/02-left-join-and-missing-data.md). Previous: [Combining Tables with JOIN](01-combining-tables-with-join.md). Next: [GROUP BY](03-group-by.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Verify products with zero sales — the honest way**

Don't assume every product has sold at least once. Write a `LEFT
JOIN` from `bronze_products` to `bronze_sales` and check for any
product with no matching sale row.

<details>
<summary>Show solution</summary>

```sql
SELECT p.product_id, p.product_name
FROM bronze_products p
LEFT JOIN bronze_sales s ON p.product_id = s.product_id
WHERE s.order_id IS NULL;
```

*(no rows)*

Every one of the 150 products in `bronze_products` has at least one
matching row in `bronze_sales`. Worth verifying rather than assuming —
this is the same `LEFT JOIN ... WHERE ... IS NULL` pattern used for
finding orphans, just pointed in the other direction.

</details>

---

**2. Verify employees with zero sales, the same way**

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_employees e
LEFT JOIN bronze_sales s ON e.employee_id = s.employee_id
WHERE s.order_id IS NULL;
```

| COUNT(*) |
|---|
| 0 |

Same result as products — every employee has at least one sale
attributed to them in this build. Two "expected gaps" checked, two
zeros found; both are still useful, verified facts, not wasted
queries.

</details>

---

**3. The 5 worst offenders for orphan `customer_id`**

Using a `LEFT JOIN` from `bronze_sales` to `bronze_customers`, find
the 5 distinct orphan `customer_id` values responsible for the most
order lines, along with how many lines each contributes.

<details>
<summary>Show solution</summary>

```sql
SELECT s.customer_id, COUNT(*) AS orphan_lines
FROM bronze_sales s
LEFT JOIN bronze_customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
GROUP BY s.customer_id
ORDER BY orphan_lines DESC
LIMIT 5;
```

| customer_id | orphan_lines |
|---|---|
| 9498 | 3 |
| 8297 | 3 |
| 7902 | 3 |
| 6718 | 3 |
| 6441 | 3 |

Notice these `customer_id` values (9498, 8297, ...) are nowhere close
to the real range of 1–600 — a strong tell that these are fabricated
bad ids rather than off-by-one typos of real ones.

</details>

---

**4. How many distinct orders are affected by the orphan `customer_id` problem?**

The 103 orphan rows from Module 1/2's lesson group into how many
distinct `order_id`s? (Recall from the data dictionary: bad
`customer_id`s are injected at the order level, so every line of a
bad order shares the same id.)

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(DISTINCT s.order_id)
FROM bronze_sales s
LEFT JOIN bronze_customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

| COUNT(DISTINCT s.order_id) |
|---|
| 61 |

61 distinct orders account for all 103 orphan lines — consistent with
orders averaging just under 2 lines each, and confirming the "bad id
at the order level, shared across lines" pattern from the data
dictionary.

</details>

---

**5. Revenue lost to orphan products — quantify it**

Using a `LEFT JOIN` from `bronze_sales` to `bronze_products`, compute
the rough revenue (`quantity * unit_price`) split into two groups:
rows that matched a real product, and rows that didn't (orphan
`product_id`). Use a `CASE` expression to build the grouping label.

<details>
<summary>Show solution</summary>

```sql
SELECT CASE WHEN p.product_id IS NULL THEN 'orphan' ELSE 'matched' END AS match_status,
       COUNT(*) AS n,
       ROUND(SUM(s.quantity * s.unit_price), 2) AS rough_total
FROM bronze_sales s
LEFT JOIN bronze_products p ON s.product_id = p.product_id
GROUP BY match_status;
```

| match_status | n | rough_total |
|---|---|---|
| matched | 11878 | 9822452.14 |
| orphan | 122 | 57705.04 |

$57,705.04 worth of "rough total" revenue sits on order lines
referencing a product that doesn't exist. An `INNER JOIN`-only report
would have reported the smaller `matched` total as if it were the
whole picture, with no indication that ~$57.7K was silently excluded.

</details>

---

**6. Combine LEFT JOIN with an aggregate: per-customer orphan-line exposure**

For customers who have at least one orphan-`product_id` order line
(their `customer_id` is valid, but some line they ordered references
a bad `product_id`), find their `customer_id`, name, and count of
affected lines. Order by affected-line count descending, limit 5.

<details>
<summary>Show solution</summary>

```sql
SELECT c.customer_id, c.first_name, c.last_name, COUNT(*) AS orphan_product_lines
FROM bronze_sales s
JOIN bronze_customers c ON s.customer_id = c.customer_id
LEFT JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.product_id IS NULL
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY orphan_product_lines DESC
LIMIT 5;
```

| customer_id | first_name | last_name | orphan_product_lines |
|---|---|---|---|
| 68 | michele | PEREZ | 2 |
| 72 | Molly | Herrera | 2 |
| 284 | travis | Lewis | 2 |
| 346 | KELLY | cruz | 2 |
| 360 | JOHN | martin | 2 |

This mixes an `INNER JOIN` (to `bronze_customers`, since we only care
about real customers) with a `LEFT JOIN` (to `bronze_products`, since
we're specifically hunting for the non-matches) in the same query —
a preview of how the two join types combine once you're solving a
real, specific question instead of demonstrating one concept at a
time.

</details>

---

---

<!-- nav -->
Curriculum: [LEFT JOIN and Missing Data](../../curriculum/02-intermediate/02-left-join-and-missing-data.md). Previous: [Combining Tables with JOIN](01-combining-tables-with-join.md). Next: [GROUP BY](03-group-by.md).
<!-- /nav -->
