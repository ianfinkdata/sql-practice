# Exercises: NULL — the Absence of a Value

### 1. Missing emails

Write a query that shows `employee_id`, `first_name`, `last_name`,
`email` for every employee with no email on file.

<details>
<summary>Show solution</summary>

```sql
SELECT employee_id, first_name, last_name, email
FROM bronze_employees
WHERE email IS NULL;
```

| employee_id | first_name | last_name | email |
|---|---|---|---|
| 5 | stephanie | REID |  |
| 11 | Adam | Mcneil |  |
| 21 | Ashlee | Hall |  |
| 33 | Derek | Brown |  |

4 employees have no email recorded.

</details>

### 2. Still employed

`bronze_employees.termination_date` is `NULL` for anyone still
employed (as of the snapshot date). Count how many employees are still
employed, and how many have been terminated.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_employees WHERE termination_date IS NULL;
```

| COUNT(*) |
|---|
| 27 |

```sql
SELECT COUNT(*) FROM bronze_employees WHERE termination_date IS NOT NULL;
```

| COUNT(*) |
|---|
| 8 |

27 + 8 = 35, the full employee roster.

</details>

### 3. Two NULLs at once

Write a query for products that are missing **both** `subcategory`
*and* `unit_cost`. How many rows come back?

<details>
<summary>Show solution</summary>

```sql
SELECT product_id, product_name
FROM bronze_products
WHERE subcategory IS NULL AND unit_cost IS NULL;
```

Zero rows come back — none of the 150 products happen to be missing
*both* fields at once in this build. That's a legitimate, useful
result: it tells you these two kinds of missingness don't overlap
here, not that the query is broken. (Try running the two `IS NULL`
conditions separately — 27 and 7 rows respectively, from the
curriculum module — to convince yourself neither set is empty on its
own.)

</details>

### 4. Confirm the trap yourself

Write a query using `= NULL` (not `IS NULL`) to try to find employees
with a missing email. What do you get, and why?

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_employees WHERE email = NULL;
```

| COUNT(*) |
|---|
| 0 |

Zero, even though exercise 1 just showed 4 employees really do have a
missing email. `= NULL` never matches anything — any comparison
against `NULL` evaluates to unknown, not true, so `WHERE` drops every
row. The correct version is `WHERE email IS NULL`.

</details>

### 5. NULL in the biggest table

`bronze_sales.employee_id` is `NULL` for online orders with no
employee involved. Count how many of the 12,000 order-line rows have
a `NULL` `employee_id`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_sales WHERE employee_id IS NULL;
```

| COUNT(*) |
|---|
| 1243 |

About 10.4% of all order lines have no employee attached — consistent
with "represents an online/no-rep sale" from the data dictionary.

</details>

### 6. Combine WHERE, IS NOT NULL, and ORDER BY

Write a query for the 5 cheapest products, but only among products
that actually *have* a recorded `unit_cost` (i.e. exclude the ones
with `unit_cost IS NULL`).

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_cost
FROM bronze_products
WHERE unit_cost IS NOT NULL
ORDER BY unit_cost ASC
LIMIT 5;
```

| product_name | unit_cost |
|---|---|
| Outrider Multi-Tools | -131.94 |
| Cascade Hiking Boots | -4.19 |
| Canyon Hats | 8.48 |
| Trailhead Sleeping Bags | 10.4 |
| Outrider Sleeping Bag | 13.63 |

The `unit_cost IS NOT NULL` filter did its job — no missing values
snuck in. But look at the top two: **negative** unit costs. That's not
a bug in your query; `bronze_products.unit_cost` really does have a
small number of deliberately negative values (a data-entry error baked
into the practice data on purpose). NULL isn't the only kind of "bad"
data you'll need to watch for — it's just the one this module is
about. Negative/implausible values like these get their own attention
starting in Tier 2.



</details>
