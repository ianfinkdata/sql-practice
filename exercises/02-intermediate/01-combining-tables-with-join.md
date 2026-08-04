# Exercises: Combining Tables with JOIN

<!-- nav -->
Curriculum: [Combining Tables with JOIN](../../curriculum/02-intermediate/01-combining-tables-with-join.md). Previous: [8. DISTINCT and Duplicates](../01-beginner/08-distinct-and-duplicates.md). Next: [LEFT JOIN and Missing Data](02-left-join-and-missing-data.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Product names for the first 5 order lines**

Join `bronze_sales` to `bronze_products` and return `order_id`,
`order_line_id`, and `product_name` for the first 5 rows, ordered by
`order_id` then `order_line_id`.

<details>
<summary>Show solution</summary>

```sql
SELECT s.order_id, s.order_line_id, p.product_name
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
ORDER BY s.order_id, s.order_line_id
LIMIT 5;
```

| order_id | order_line_id | product_name |
|---|---|---|
| 1 | 1 | Trailhead Trekking Pole |
| 1 | 2 | Alpine Water Filters |
| 2 | 1 | Switchback Trail Running Shoes |
| 2 | 2 | Ironpeak Fleece |
| 3 | 1 | Canyon Backpack |

</details>

---

**2. Everything about order 5**

Join `bronze_sales`, `bronze_customers`, and `bronze_products` to show
the customer's full name, the product name, and the quantity for
every line of `order_id = 5`.

<details>
<summary>Show solution</summary>

```sql
SELECT s.order_id, c.first_name || ' ' || c.last_name AS customer,
       p.product_name, s.quantity
FROM bronze_sales s
JOIN bronze_customers c ON s.customer_id = c.customer_id
JOIN bronze_products p ON s.product_id = p.product_id
WHERE s.order_id = 5;
```

| order_id | customer | product_name | quantity |
|---|---|---|---|
| 5 | Susan TURNER | Driftwood Base Layers | 3 |

(Just one line for this order — and note `TURNER` is uppercase, a
reminder that `bronze_customers` names are messy too, unrelated to
today's topic.)

</details>

---

**3. Rough total revenue for exactly-spelled `'Footwear'`**

Join sales to products and sum `quantity * unit_price` for rows where
`category` is exactly `'Footwear'` (don't worry about other spellings
yet — that's later modules).

<details>
<summary>Show solution</summary>

```sql
SELECT ROUND(SUM(s.quantity * s.unit_price), 2) AS rough_total
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.category = 'Footwear';
```

| rough_total |
|---|
| 116142.88 |

</details>

---

**4. How many order lines have a real employee attached?**

`bronze_sales.employee_id` is `NULL` for ~10% of rows (representing an
online/no-rep sale). Join `bronze_sales` to `bronze_employees` with an
`INNER JOIN` and count the result. Then separately count how many
`bronze_sales` rows have `employee_id IS NULL`. Confirm the two
numbers plus each other roughly reconstruct 12,000.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_sales s
JOIN bronze_employees e ON s.employee_id = e.employee_id;
```

| COUNT(*) |
|---|
| 10757 |

```sql
SELECT COUNT(*) FROM bronze_sales WHERE employee_id IS NULL;
```

| COUNT(*) |
|---|
| 1243 |

10757 + 1243 = 12000 — every row is accounted for either as a
successful join match or a `NULL` employee_id. `INNER JOIN` alone
drops the 1,243 `NULL`-employee rows with no explanation; if your goal
was "sales with or without a rep," `INNER JOIN` would silently give
you the wrong denominator.

</details>

---

**5. Stack two INNER JOINs — how much data survives both?**

Join `bronze_sales` to *both* `bronze_customers` and `bronze_products`
(two `INNER JOIN`s in one query) and count the rows. Compare against
the individual counts from the lesson (11,897 for the customers join
alone, 11,878 for the products join alone) and explain in a comment
why the combined count isn't just `12000 - 103 - 122`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_sales s
JOIN bronze_customers c ON s.customer_id = c.customer_id
JOIN bronze_products p ON s.product_id = p.product_id;
```

| COUNT(*) |
|---|
| 11776 |

`12000 - 103 - 122 = 11775`, one row off from the actual 11776. The
orphan `customer_id` and orphan `product_id` rows aren't guaranteed to
be entirely separate sets of rows — in general they *could* overlap
(a single order line could have both a bad `customer_id` and a bad
`product_id`), and simple subtraction assumes no overlap. Always
verify the combined count directly rather than assuming losses add up
linearly.

</details>

---

**6. Which product categories does customer 41 (the top spender from
earlier modules) actually buy?**

Join `bronze_sales` to `bronze_products` for `customer_id = 41`, and
return the distinct raw `category` values that appear, along with how
many lines each contributed.

<details>
<summary>Show solution</summary>

```sql
SELECT p.category, COUNT(*) AS line_count
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE s.customer_id = 41
GROUP BY p.category
ORDER BY line_count DESC;
```

| category | line_count |
|---|---|
| ACCESSORIES | 5 |
| apparel | 3 |
| Winter Sports | 3 |
| Apparel | 3 |
| water sports | 2 |
| nutrition & hydration | 2 |
| camping and hiking | 2 |
| WINTER SPORTS | 2 |
| FOOTWEAR | 2 |
| CAMPING & HIKING | 2 |
| ...(16 more rows, one per remaining raw spelling) | |

26 groups for one customer's order history, most with just 1-2 lines
— notice how many *different raw spellings* of the same category show
up even at this small scale, foreshadowing Module 3 and Module 6.

</details>

---

---

<!-- nav -->
Curriculum: [Combining Tables with JOIN](../../curriculum/02-intermediate/01-combining-tables-with-join.md). Previous: [8. DISTINCT and Duplicates](../01-beginner/08-distinct-and-duplicates.md). Next: [LEFT JOIN and Missing Data](02-left-join-and-missing-data.md).
<!-- /nav -->
