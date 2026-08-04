# Exercises: SELECT and FROM

<!-- nav -->
Curriculum: [1. SELECT and FROM](../../curriculum/01-beginner/01-select-and-from.md). Previous: [4. Meet Oakhaven](../00-orientation/04-meet-oakhaven.md). Next: [2. Filtering with WHERE](02-filtering-with-where.md).
<!-- /nav -->

### 1. Everything, a few rows

Write a query that returns every column of `bronze_employees`, limited
to 5 rows.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM bronze_employees LIMIT 5;
```

| employee_id | first_name | last_name | department | region | hire_date | termination_date | is_manager | email |
|---|---|---|---|---|---|---|---|---|
| 1 | Alexa | garcia | Management | West | 04/09/2024 |  | N | alexa.garcia@oakhaven.com |
| 2 | sandra | Thompson | WAREHOUSE | NORTHEAST | 05/25/2018 |  | false | sandra.thompson@oakhaven.com |
| 3 | Alexandria | CUNNINGHAM | management | East | 2018-12-07 | 2021-05-01 06:37:09 | false | alexandria.cunningham@oakhaven.com |
| 4 | Laura | williams | Support | EAST | 2020-05-28 |  | 1 | laura.williams@oakhaven.com |
| 5 | stephanie | REID | Warehouse | CENTRAL | 2023-08-10 03:22:34 |  | y | (blank) |

</details>

### 2. Three columns

Write a query that shows just `product_name`, `category`, and
`unit_price` for the first 5 rows of `bronze_products`.

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, category, unit_price
FROM bronze_products
LIMIT 5;
```

| product_name | category | unit_price |
|---|---|---|
| Canyon Hiking Boots | footwear | 649.26 |
| Ridge Jackets | APPAREL | 348.55 |
| Trailhead Trekking Pole | CAMPING & HIKING | 286.86 |
| Meridian Chalk Bags | Climbing | 155.94 |
| Canyon Life Jackets | Water Sports | 310.93 |

</details>

### 3. Just enough to send an email blast

You need a mailing list of employee emails paired with their
department, so you can filter by department later. Write a query for
just those two columns, first 5 rows of `bronze_employees`.

<details>
<summary>Show solution</summary>

```sql
SELECT email, department
FROM bronze_employees
LIMIT 5;
```

| email | department |
|---|---|
| alexa.garcia@oakhaven.com | Management |
| sandra.thompson@oakhaven.com | WAREHOUSE |
| alexandria.cunningham@oakhaven.com | management |
| laura.williams@oakhaven.com | Support |
| (blank) | Warehouse |

Notice row 5's email is blank — a preview of the NULL/missing-data
topics coming up in module 5.

</details>

### 4. Reorder on purpose

Write a query on `bronze_products` that shows `weight_kg` *before*
`sku` in the output (first 5 rows) — deliberately not matching the
table's actual column order.

<details>
<summary>Show solution</summary>

```sql
SELECT weight_kg, sku
FROM bronze_products
LIMIT 5;
```

| weight_kg | sku |
|---|---|
| 24.7 kg | FOO-0001 |
| 5.3 | APP-0002 |
| 3.43 kg | CAM-0003 |
| 18.5 kg | CLI-0004 |
| 9.01 | WAT-0005 |

The output column order always follows the order you list them in
`SELECT`, regardless of how they're defined in the table.

</details>

### 5. Spot the error

What's wrong with this query, and what error would you expect from
running it?

```sql
SELECT product_name brand, FROM bronze_products;
```

<details>
<summary>Show solution</summary>

Two things: `product_name brand` (with no comma between them) would
actually be parsed as `product_name` aliased to the name `brand` — not
an error by itself, but almost certainly not what was intended, and
easy to mistake for a typo of `product_name, brand`. The real syntax
error is the trailing comma right before `FROM` — SQLite expects
another column name after a comma, not the `FROM` keyword, and will
raise a syntax error. The fix:

```sql
SELECT product_name, brand FROM bronze_products;
```

</details>

---

<!-- nav -->
Curriculum: [1. SELECT and FROM](../../curriculum/01-beginner/01-select-and-from.md). Previous: [4. Meet Oakhaven](../00-orientation/04-meet-oakhaven.md). Next: [2. Filtering with WHERE](02-filtering-with-where.md).
<!-- /nav -->
