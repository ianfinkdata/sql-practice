# Exercises: Subqueries and Derived Tables

<!-- nav -->
Curriculum: [Subqueries and Derived Tables](../../curriculum/02-intermediate/08-subqueries-and-derived-tables.md). Previous: [COALESCE and NULLIF](07-coalesce-and-nullif.md). Next: [Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT](09-set-operations.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Products cheaper (by cost) than average**

First find the average `unit_cost` (excluding `NULL`s). Then, using a
scalar subquery, find the 5 cheapest products by `unit_cost` that fall
below that average.

<details>
<summary>Show solution</summary>

```sql
SELECT ROUND(AVG(unit_cost), 2) FROM bronze_products WHERE unit_cost IS NOT NULL;
```

| ROUND(AVG(unit_cost), 2) |
|---|
| 159.05 |

```sql
SELECT product_id, product_name, unit_cost
FROM bronze_products
WHERE unit_cost < (SELECT AVG(unit_cost) FROM bronze_products WHERE unit_cost IS NOT NULL)
ORDER BY unit_cost ASC
LIMIT 5;
```

| product_id | product_name | unit_cost |
|---|---|---|
| 30 | Outrider Multi-Tools | -131.94 |
| 19 | Cascade Hiking Boots | -4.19 |
| 122 | Canyon Hats | 8.48 |
| 27 | Trailhead Sleeping Bags | 10.4 |
| 112 | Outrider Sleeping Bag | 13.63 |

Note the subquery's own `WHERE unit_cost IS NOT NULL` — without it,
`AVG()` would just skip `NULL`s anyway (aggregates always do), but
being explicit makes the intent clear, and matters more once the
comparison logic gets more complex.

```sql
SELECT COUNT(*) FROM bronze_products
WHERE unit_cost < (SELECT AVG(unit_cost) FROM bronze_products WHERE unit_cost IS NOT NULL);
```

| COUNT(*) |
|---|
| 70 |

</details>

---

**2. Confirm no product has zero sales, using `NOT IN`**

Using a subquery with `NOT IN`, count how many `bronze_products` rows
have a `product_id` that never appears in `bronze_sales`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_products
WHERE product_id NOT IN (SELECT product_id FROM bronze_sales WHERE product_id IS NOT NULL);
```

| COUNT(*) |
|---|
| 0 |

Same answer Module 2 found with a `LEFT JOIN` — `NOT IN` over a
subquery is an alternative way to ask the same "does this ever
appear" question. (The `WHERE product_id IS NOT NULL` inside the
subquery matters here: `NOT IN` against a list containing a `NULL`
can behave counterintuitively in SQL generally, so it's good practice
to exclude `NULL`s explicitly when building the list for `NOT IN`.)

</details>

---

**3. Customer 41's running total, as a scalar subquery baseline**

Find customer 41's rough total spend (`quantity * unit_price`, summed
across all their order lines).

<details>
<summary>Show solution</summary>

```sql
SELECT ROUND(SUM(quantity * unit_price), 2) FROM bronze_sales WHERE customer_id = 41;
```

| ROUND(SUM(quantity * unit_price), 2) |
|---|
| 44030.55 |

Worth confirming this matches Module 8's derived-table example, which
found the same $44,030.55 for customer 41 through a
`GROUP BY`-in-a-subquery instead of a direct filter — two different
routes to the same number is a good sanity check that both are
correct.

</details>

---

**4. Top 5 employees by rough revenue — derived table**

Build a derived table that computes each employee's order-line count
and rough total revenue (excluding `NULL` `employee_id`), then select
the top 5 by revenue from it.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM (
  SELECT employee_id, COUNT(*) AS n, ROUND(SUM(quantity * unit_price), 2) AS rough_total
  FROM bronze_sales
  WHERE employee_id IS NOT NULL
  GROUP BY employee_id
) AS totals
ORDER BY rough_total DESC
LIMIT 5;
```

| employee_id | n | rough_total |
|---|---|---|
| 29 | 338 | 298518.4 |
| 22 | 353 | 298400.48 |
| 34 | 325 | 290989.75 |
| 12 | 354 | 282111.68 |
| 2 | 365 | 282075.68 |

Note employee 29 tops revenue with fewer lines (338) than employees
12 and 2 — the derived table makes it trivial to sort on the computed
`rough_total` rather than the raw line count, which a plain `GROUP
BY`/`ORDER BY` in one step can already do, but which becomes essential
once you need to filter or join on the computed value afterward
(see #6).

</details>

---

**5. Customers who bought from 15+ distinct raw category spellings**

Using a derived table, compute how many distinct raw `category`
values each customer has purchased from, then filter to customers
with 15 or more, top 5 by that count.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM (
  SELECT s.customer_id, COUNT(DISTINCT p.category) AS distinct_categories
  FROM bronze_sales s
  JOIN bronze_products p ON s.product_id = p.product_id
  GROUP BY s.customer_id
) AS spread
WHERE spread.distinct_categories >= 15
ORDER BY distinct_categories DESC
LIMIT 5;
```

| customer_id | distinct_categories |
|---|---|
| 41 | 26 |
| 535 | 24 |
| 67 | 23 |
| 572 | 23 |
| 130 | 22 |

Customer 41 (already familiar as the top spender from earlier
modules) also touches 26 distinct *raw category spellings* — a
reminder that even one heavy-ordering customer's history is enough to
surface most of the category messiness in this database. A real
report on "how many different categories does this customer buy
from" would need Module 6's cleaning applied to `p.category` first,
or this number massively overstates genuine category variety.

</details>

---

**6. Employees whose revenue beats the average employee's revenue**

Using a derived table for per-employee rough revenue (like #4), find
employees whose revenue exceeds the *average* revenue across all
employees — combining a derived table with a scalar subquery in the
same query.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM (
  SELECT employee_id, ROUND(SUM(quantity * unit_price), 2) AS rough_total
  FROM bronze_sales
  WHERE employee_id IS NOT NULL
  GROUP BY employee_id
) AS totals
WHERE totals.rough_total > (
  SELECT AVG(emp_total) FROM (
    SELECT SUM(quantity * unit_price) AS emp_total
    FROM bronze_sales
    WHERE employee_id IS NOT NULL
    GROUP BY employee_id
  )
)
ORDER BY totals.rough_total DESC
LIMIT 5;
```

| employee_id | rough_total |
|---|---|
| 29 | 298518.4 |
| 22 | 298400.48 |
| 34 | 290989.75 |
| 12 | 282111.68 |
| 2 | 282075.68 |

17 of the 35 employees clear the average (confirmed with a `COUNT(*)`
version of the same query). This is a three-layer query — a derived
table for display, compared against a scalar subquery that itself
wraps *another* derived table to get a true per-employee average
(rather than an average-per-line, which `AVG()` over raw
`bronze_sales` rows would incorrectly weight toward employees with
more, smaller line items). Building it up one layer at a time —
testing each inner piece standalone first, per Module 8's debugging
tip — is much more manageable than writing all three levels at once.

</details>

---

---

<!-- nav -->
Curriculum: [Subqueries and Derived Tables](../../curriculum/02-intermediate/08-subqueries-and-derived-tables.md). Previous: [COALESCE and NULLIF](07-coalesce-and-nullif.md). Next: [Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT](09-set-operations.md).
<!-- /nav -->
