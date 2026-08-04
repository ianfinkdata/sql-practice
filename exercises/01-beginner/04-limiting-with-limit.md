# Exercises: Limiting with LIMIT (and OFFSET)

<!-- nav -->
Curriculum: [4. Limiting with LIMIT (and OFFSET)](../../curriculum/01-beginner/04-limiting-with-limit.md). Previous: [3. Sorting with ORDER BY](03-sorting-with-order-by.md). Next: [5. NULL: the Absence of a Value](05-null-the-absence-of-a-value.md).
<!-- /nav -->

### 1. First page

Write a query showing the first 3 employees alphabetically by last
name (`first_name`, `last_name`).

<details>
<summary>Show solution</summary>

```sql
SELECT first_name, last_name
FROM bronze_employees
ORDER BY last_name ASC
LIMIT 3;
```

| first_name | last_name |
|---|---|
| Robert | ANDERSON |
| ANTONIO | Bailey |
| Mary | Boyd |

</details>

### 2. Second page

Using the same sort as exercise 1, write a query for the *next* 3
employees (ranks 4–6).

<details>
<summary>Show solution</summary>

```sql
SELECT first_name, last_name
FROM bronze_employees
ORDER BY last_name ASC
LIMIT 3 OFFSET 3;
```

| first_name | last_name |
|---|---|
| JENNIFER | Brown |
| Derek | Brown |
| Alexandria | CUNNINGHAM |

</details>

### 3. The 3rd most expensive product

Write a query that returns exactly one row: the 3rd most expensive
product in `bronze_products`.

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price DESC
LIMIT 1 OFFSET 2;
```

| product_name | unit_price |
|---|---|
| Highline Paddle | 696.3 |

`OFFSET 2` skips the top 2 (ranks 1 and 2), then `LIMIT 1` takes just
the next row — rank 3.

</details>

### 4. Combine WHERE, ORDER BY, and LIMIT

Write a query for all `Climbing`-category products, sorted by price
from highest to lowest, with no `LIMIT` — just to see the whole list
and how many there are.

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM bronze_products
WHERE category = 'Climbing'
ORDER BY unit_price DESC;
```

| product_name | unit_price |
|---|---|
| Meridian Chalk Bags | 669.02 |
| Alpine Harnesse | 640.45 |
| Cascade Harnesse | 379.33 |
| Ridge Carabiners | 198.04 |
| Meridian Chalk Bags | 155.94 |
| Backcountry Chalk Bags | 141.92 |
| Glacier Carabiners | 113.71 |
| Trailhead Ropes | 87.28 |
| Alpine Climbing Shoes | 77.97 |

9 rows total (matching the exact-cased `'Climbing'` count from module
2's exercises).

</details>

### 5. Paginate that list

Using the same filter and sort as exercise 4, write a query for just
the *second page* of results, using a page size of 5.

<details>
<summary>Show solution</summary>

Page 1 is `LIMIT 5 OFFSET 0` (or just `LIMIT 5`); page 2 skips the
first 5:

```sql
SELECT product_name, unit_price
FROM bronze_products
WHERE category = 'Climbing'
ORDER BY unit_price DESC
LIMIT 5 OFFSET 5;
```

| product_name | unit_price |
|---|---|
| Backcountry Chalk Bags | 141.92 |
| Glacier Carabiners | 113.71 |
| Trailhead Ropes | 87.28 |
| Alpine Climbing Shoes | 77.97 |

Only 4 rows come back, not 5 — because there are only 9 matching rows
total, and page 2 (rows 6–10) only has 4 rows to give (rows 6, 7, 8,
9). `OFFSET` past the end of the data just returns fewer rows, not an
error.

</details>

---

<!-- nav -->
Curriculum: [4. Limiting with LIMIT (and OFFSET)](../../curriculum/01-beginner/04-limiting-with-limit.md). Previous: [3. Sorting with ORDER BY](03-sorting-with-order-by.md). Next: [5. NULL: the Absence of a Value](05-null-the-absence-of-a-value.md).
<!-- /nav -->
