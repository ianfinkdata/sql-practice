# Exercises: Set Operations (UNION, UNION ALL, INTERSECT, EXCEPT)

<!-- nav -->
Curriculum: [Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT](../../curriculum/02-intermediate/09-set-operations.md). Previous: [Subqueries and Derived Tables](08-subqueries-and-derived-tables.md). Next: [1. Common Table Expressions (CTEs)](../03-advanced/01-common-table-expressions.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Confirm `'Completed'` is already present in `order_status` using UNION**

Combine the distinct raw `order_status` values with a single-row query
returning the literal `'Completed'`, using `UNION`. If the combined
list is the same size as the original distinct list, the value was
already present.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT order_status FROM bronze_sales
UNION
SELECT 'Completed'
ORDER BY 1;
```

| order_status |
|---|
| *(blank/NULL)* |
| CANCELLED |
| Cancelled |
| Completed |
| Returned |
| completed |

6 rows — the same count as `SELECT DISTINCT order_status FROM
bronze_sales` alone would return, confirming `'Completed'` (exact
casing) was already one of the 6 raw values, so `UNION` added
nothing new.

</details>

---

**2. INTERSECT: Wholesale customers who bought exactly-spelled `'Footwear'`**

`bronze_customers.customer_segment = 'Wholesale'` has 95 exact-cased
matches. Using `INTERSECT`, find how many of those customers also
bought a product from the exact-cased `'Footwear'` category.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_customers WHERE customer_segment = 'Wholesale';
```

| COUNT(*) |
|---|
| 95 |

```sql
SELECT customer_id FROM bronze_customers WHERE customer_segment = 'Wholesale'
INTERSECT
SELECT customer_id FROM bronze_sales
  WHERE product_id IN (SELECT product_id FROM bronze_products WHERE category = 'Footwear')
ORDER BY customer_id
LIMIT 10;
```

| customer_id |
|---|
| 5 |
| 26 |
| 31 |
| 65 |
| 92 |
| 110 |
| 113 |
| 159 |
| 160 |
| 174 |

```sql
SELECT COUNT(*) FROM (
  SELECT customer_id FROM bronze_customers WHERE customer_segment = 'Wholesale'
  INTERSECT
  SELECT customer_id FROM bronze_sales
    WHERE product_id IN (SELECT product_id FROM bronze_products WHERE category = 'Footwear')
);
```

| COUNT(*) |
|---|
| 33 |

33 of the 95 exact-cased `'Wholesale'` customers bought from the
exact-cased `'Footwear'` category. Both numbers undercount the real
answer, since both `customer_segment` and `category` have other raw
spellings not included here — a fair exercise in seeing how set
operations compose cleanly even when the underlying filters are still
partial.

</details>

---

**3. EXCEPT: verify every real customer has placed at least one order**

Using `EXCEPT` instead of a `LEFT JOIN`, find `customer_id`s present in
`bronze_customers` but absent from `bronze_sales`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM (
  SELECT customer_id FROM bronze_customers
  EXCEPT
  SELECT customer_id FROM bronze_sales
);
```

| COUNT(*) |
|---|
| 0 |

Same answer Module 2 found with `LEFT JOIN ... WHERE ... IS NULL` —
`EXCEPT` is a different, equally valid way to ask "what's in A but not
in B."

</details>

---

**4. EXCEPT: which raw `payment_method` spellings aren't one of the 5 canonical, exact-cased forms?**

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT payment_method FROM bronze_sales
EXCEPT
SELECT * FROM (
  SELECT 'Credit Card' AS payment_method
  UNION ALL SELECT 'Cash'
  UNION ALL SELECT 'Debit Card'
  UNION ALL SELECT 'Gift Card'
  UNION ALL SELECT 'PayPal'
)
ORDER BY 1;
```

| payment_method |
|---|
| CC |
| cash  |
| credit card |
| debit card |
| paypal |

5 "wrong" spellings out of 10 total raw values — exactly half. Notice
`cash ` has a trailing space, invisible in the rendered table but
real to `EXCEPT`'s comparison; that's the same lesson from Module 6
resurfacing here.

</details>

---

**5. UNION ALL: how many total first names exist across customers and employees?**

Stack `bronze_customers.first_name` and `bronze_employees.first_name`
with `UNION ALL` and confirm the row count equals the sum of both
tables' row counts.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM (
  SELECT first_name FROM bronze_customers
  UNION ALL
  SELECT first_name FROM bronze_employees
);
```

| COUNT(*) |
|---|
| 635 |

600 (customers) + 35 (employees) = 635 — `UNION ALL` never
deduplicates, so this is pure addition, confirming no rows were
silently dropped or merged.

</details>

---

**6. Build your own audit: which raw `channel` values aren't `'Online'` or `'In-Store'` exactly?**

Using the `EXCEPT` pattern from #4, find every raw `channel` value
that doesn't exactly match `'Online'` or `'In-Store'`. Then write a
second query using `UNION` to confirm your 2-value canonical list,
combined with the full raw distinct list, doesn't grow past 6
distinct values total (4 raw + the same 2 canonical, since 2 raw
values already match exactly).

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT channel FROM bronze_sales
EXCEPT
SELECT * FROM (SELECT 'Online' AS channel UNION ALL SELECT 'In-Store')
ORDER BY 1;
```

| channel |
|---|
| in store |
| online |

```sql
SELECT COUNT(*) FROM (
  SELECT channel FROM bronze_sales
  UNION
  SELECT * FROM (SELECT 'Online' AS channel UNION ALL SELECT 'In-Store')
);
```

| COUNT(*) |
|---|
| 4 |

Only 4, not 6 — because `'Online'` and `'In-Store'` (exact casing)
were already among the 4 raw values, so adding them again via `UNION`
contributed nothing new. `UNION`'s dedup behavior is exactly what
makes it a reliable way to check "is this value already present"
without first needing to know the answer.

</details>

---

---

<!-- nav -->
Curriculum: [Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT](../../curriculum/02-intermediate/09-set-operations.md). Previous: [Subqueries and Derived Tables](08-subqueries-and-derived-tables.md). Next: [1. Common Table Expressions (CTEs)](../03-advanced/01-common-table-expressions.md).
<!-- /nav -->
