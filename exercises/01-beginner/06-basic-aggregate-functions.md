# Exercises: Basic Aggregate Functions

<!-- nav -->
Curriculum: [6. Basic Aggregate Functions](../../curriculum/01-beginner/06-basic-aggregate-functions.md). Previous: [5. NULL: the Absence of a Value](05-null-the-absence-of-a-value.md). Next: [7. Pattern Matching with LIKE](07-pattern-matching-with-like.md).
<!-- /nav -->

### 1. How many employees?

Write a query that counts every row in `bronze_employees`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_employees;
```

| COUNT(*) |
|---|
| 35 |

</details>

### 2. How many have an email on file?

Write a query counting how many employees have a non-NULL `email`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(email) FROM bronze_employees;
```

| COUNT(email) |
|---|
| 31 |

35 total employees, 31 with an email — matching the 4 missing emails
from the previous module's exercises.

</details>

### 3. Price range within a category

Write a query showing the minimum, maximum, and (rounded to 2 decimal
places) average `unit_price` for `Climbing`-category products.

<details>
<summary>Show solution</summary>

```sql
SELECT
    MIN(unit_price) AS min_p,
    MAX(unit_price) AS max_p,
    ROUND(AVG(unit_price), 2) AS avg_p
FROM bronze_products
WHERE category = 'Climbing';
```

| min_p | max_p | avg_p |
|---|---|---|
| 77.97 | 669.02 | 273.74 |

Notice `WHERE` runs first, narrowing to the 9 exact-cased `Climbing`
rows, and only *then* do the aggregates summarize that filtered set.

</details>

### 4. Count and total, together

Write a query that shows both how many products cost less than $100,
and the (rounded) total of their prices combined.

<details>
<summary>Show solution</summary>

```sql
SELECT
    COUNT(*) AS n,
    ROUND(SUM(unit_price), 2) AS total
FROM bronze_products
WHERE unit_price < 100;
```

| n | total |
|---|---|
| 21 | 1097.07 |

</details>

### 5. COUNT(*) vs COUNT(column)

Write a single query with two columns: the total number of products,
and the number of products that have a non-NULL `subcategory`. What's
the difference between the two numbers, and what does that difference
represent?

<details>
<summary>Show solution</summary>

```sql
SELECT
    COUNT(*) AS total,
    COUNT(subcategory) AS with_subcat
FROM bronze_products;
```

| total | with_subcat |
|---|---|
| 150 | 123 |

The difference, 150 − 123 = 27, is exactly the number of products with
a `NULL` subcategory (matching the `subcategory IS NULL` count from
the previous module).

</details>

### 6. Cost vs. price

Oakhaven marks products up from cost to price. Write a query showing
the (rounded) average `unit_cost` and average `unit_price` across all
products, side by side, and eyeball roughly how big the markup looks.

<details>
<summary>Show solution</summary>

```sql
SELECT
    ROUND(AVG(unit_cost), 2) AS avg_cost,
    ROUND(AVG(unit_price), 2) AS avg_price
FROM bronze_products;
```

| avg_cost | avg_price |
|---|---|
| 159.05 | 300.37 |

Average price is roughly 1.9x average cost. (Two things worth
noticing if you want to think harder about this: `avg_cost` only
averages over the 143 non-NULL-cost rows while `avg_price` averages
over all 150 rows with a price, so these two averages aren't computed
over quite the same set of rows — and a handful of negative
`unit_cost` values, seen in the previous module's exercises, are
pulling `avg_cost` down slightly too. Neither invalidates the query,
but both are worth keeping in mind before treating "1.9x" as a precise
markup figure.)

</details>

---

<!-- nav -->
Curriculum: [6. Basic Aggregate Functions](../../curriculum/01-beginner/06-basic-aggregate-functions.md). Previous: [5. NULL: the Absence of a Value](05-null-the-absence-of-a-value.md). Next: [7. Pattern Matching with LIKE](07-pattern-matching-with-like.md).
<!-- /nav -->
