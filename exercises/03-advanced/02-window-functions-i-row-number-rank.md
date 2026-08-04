# Exercises: Window Functions I — ROW_NUMBER, RANK, DENSE_RANK

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Rank products by price within category

For `dim_product` rows in the `Footwear` category, rank each product by
`unit_price` descending using `RANK()`. Return `product_id`,
`product_name`, `unit_price`, and `price_rank`, top 5 only.

<details>
<summary>Show solution</summary>

```sql
SELECT product_id, product_name, unit_price,
       RANK() OVER (ORDER BY unit_price DESC) AS price_rank
FROM dim_product
WHERE category = 'Footwear'
ORDER BY unit_price DESC
LIMIT 5;
```

Verified output:

| product_id | product_name | unit_price | price_rank |
|---|---|---|---|
| 1 | Canyon Hiking Boots | 649.26 | 1 |
| 25 | Ironpeak Hiking Boot | 553.01 | 2 |
| 109 | Basecamp Sandals | 511.03 | 3 |
| 87 | Foothill Hiking Boot | 484.61 | 4 |
| 99 | Outrider Sandals | 458.12 | 5 |

</details>

---

### 2. Each customer's most recent order

Using `ROW_NUMBER()` partitioned by `customer_id` and ordered by
`order_date` descending, find the single most recent order for customers
41, 67, and 343. (Hint: dedupe `fact_sales` to distinct `(customer_id,
order_id, order_date)` first, since `fact_sales` has multiple rows per
order.) Filter to `rn = 1` in an outer query.

<details>
<summary>Show solution</summary>

```sql
WITH ranked_orders AS (
    SELECT customer_id, order_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM (SELECT DISTINCT customer_id, order_id, order_date FROM fact_sales WHERE order_date IS NOT NULL)
)
SELECT customer_id, order_id, order_date
FROM ranked_orders
WHERE rn = 1 AND customer_id IN (41, 343, 67)
ORDER BY customer_id;
```

Verified output:

| customer_id | order_id | order_date |
|---|---|---|
| 41 | 529 | 2026-03-17 |
| 67 | 6287 | 2026-06-05 |
| 343 | 3898 | 2026-06-25 |

</details>

---

### 3. Employees ranked by sales volume, within region

Using `DENSE_RANK()`, rank employees in the `West` region by the number of
`fact_sales` order lines they processed, most first. Return
`employee_id`, `full_name`, `line_count`, `region_rank`, top 6 only.

<details>
<summary>Show solution</summary>

```sql
WITH emp_counts AS (
    SELECT e.employee_id, e.full_name, e.region, COUNT(*) AS line_count
    FROM dim_employee e
    JOIN fact_sales f ON f.employee_id = e.employee_id
    GROUP BY e.employee_id, e.full_name, e.region
)
SELECT employee_id, full_name, line_count,
       DENSE_RANK() OVER (ORDER BY line_count DESC) AS region_rank
FROM emp_counts
WHERE region = 'West'
ORDER BY line_count DESC
LIMIT 6;
```

Verified output:

| employee_id | full_name | line_count | region_rank |
|---|---|---|---|
| 22 | Robert Anderson | 353 | 1 |
| 29 | Daniel Ramsey | 338 | 2 |
| 34 | Nicholas Morris | 325 | 3 |
| 6 | Christy Lee | 316 | 4 |
| 1 | Alexa Garcia | 301 | 5 |
| 23 | Nicholas Campos | 299 | 6 |

</details>

---

### 4. The near-duplicate customer dedup pattern

Recall from the data dictionary: `bronze_customers` has 30 intentional
near-duplicate rows (`customer_id` 571–600), detectable by matching
`LOWER(TRIM(email))`. Using `ROW_NUMBER() OVER (PARTITION BY
LOWER(TRIM(email)) ORDER BY customer_id)`, count how many rows land at
`rn = 1` vs `rn = 2` (excluding `NULL`/empty emails). Then explain, in a
sentence, why the `rn = 2` count doesn't exactly match the "30" from the
data dictionary.

<details>
<summary>Show solution</summary>

```sql
WITH ranked AS (
    SELECT customer_id, email,
           ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) AS rn
    FROM bronze_customers
    WHERE email IS NOT NULL AND TRIM(email) != ''
)
SELECT rn, COUNT(*) FROM ranked GROUP BY rn;
```

Verified output:

| rn | COUNT(*) |
|---|---|
| 1 | 536 |
| 2 | 29 |

Only **29**, not 30, land at `rn = 2`. The missing pair is `customer_id`
572 (`Cindy Robinson`, email `CINDY.ROBINSON@ICLOUD.COM`) and its true
base counterpart, `customer_id = 14` — but customer 14's `email` is an
empty string (`''`), which the `WHERE email IS NOT NULL AND TRIM(email) !=
''` filter excludes entirely, so this one near-duplicate pair has no
matching email key to group on and never shows up as a detected
duplicate. An email-only dedup strategy structurally cannot catch a pair
where one side's email is blank.

</details>

---

### 5. Top 2 products by revenue, per category

Using `ROW_NUMBER()` in a CTE, find the top 2 products by total net
revenue (`SUM(fact_sales.net_amount)`, joined through `dim_product`) in
the `Winter Sports` category. Return `product_name` and `total_revenue`.

<details>
<summary>Show solution</summary>

```sql
WITH product_revenue AS (
    SELECT p.category, p.product_id, p.product_name,
           ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    WHERE p.category = 'Winter Sports'
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT product_name, total_revenue,
           ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS rn
    FROM product_revenue
)
SELECT product_name, total_revenue
FROM ranked
WHERE rn <= 2;
```

Verified output:

| product_name | total_revenue |
|---|---|
| Alpine Snowboards | 117472.48 |
| Backcountry Ski | 88323.00 |

</details>
