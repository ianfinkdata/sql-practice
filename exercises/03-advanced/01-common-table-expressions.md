# Exercises: Common Table Expressions

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Categories over a million

Using a CTE, find every product category whose total net revenue (summed
across all months, from `agg_monthly_sales_by_category`) exceeds
$1,000,000. Return `category` and `total_revenue`, highest first.

<details>
<summary>Show solution</summary>

```sql
WITH category_totals AS (
    SELECT category, ROUND(SUM(total_net_amount), 2) AS total_revenue
    FROM agg_monthly_sales_by_category
    GROUP BY category
)
SELECT category, total_revenue
FROM category_totals
WHERE total_revenue > 1000000
ORDER BY total_revenue DESC;
```

Verified output:

| category | total_revenue |
|---|---|
| Climbing | 1382563.66 |
| Winter Sports | 1238465.41 |
| Apparel | 1232915.57 |
| Nutrition & Hydration | 1158785.06 |
| Footwear | 1077329.56 |

</details>

---

### 2. High-volume managers

Using a CTE, find all employees who (a) are managers (`dim_employee.is_manager
= 1`) and (b) have processed more than 300 order lines (rows in
`fact_sales` where `fact_sales.employee_id` matches theirs). Return
`employee_id`, `full_name`, `department`, and `line_count`, highest count
first.

<details>
<summary>Show solution</summary>

```sql
WITH employee_sales AS (
    SELECT e.employee_id, e.full_name, e.department, e.is_manager, COUNT(*) AS line_count
    FROM dim_employee e
    JOIN fact_sales f ON f.employee_id = e.employee_id
    GROUP BY e.employee_id, e.full_name, e.department, e.is_manager
)
SELECT employee_id, full_name, department, line_count
FROM employee_sales
WHERE is_manager = 1 AND line_count > 300
ORDER BY line_count DESC;
```

Verified output:

| employee_id | full_name | department | line_count |
|---|---|---|---|
| 4 | Laura Williams | Support | 336 |
| 5 | Stephanie Reid | Warehouse | 327 |
| 34 | Nicholas Morris | Management | 325 |
| 6 | Christy Lee | Sales | 316 |
| 7 | Mary Boyd | Management | 314 |
| 13 | Sharon Robinson | Sales | 301 |

</details>

---

### 3. Big spenders, relative to everyone

Using a CTE to compute the overall average `lifetime_net_amount` across
*all* of `agg_customer_ltv` (not per segment), find every customer whose
own lifetime value is more than **2x** that overall average. Return
`customer_id`, `full_name`, `lifetime_net_amount`, and the overall average
for reference, ordered by lifetime value descending.

<details>
<summary>Show solution</summary>

```sql
WITH overall AS (
    SELECT AVG(lifetime_net_amount) AS avg_ltv FROM agg_customer_ltv
)
SELECT c.customer_id, c.full_name, c.lifetime_net_amount,
       ROUND(o.avg_ltv, 2) AS overall_avg
FROM agg_customer_ltv c, overall o
WHERE c.lifetime_net_amount > 2 * o.avg_ltv
ORDER BY c.lifetime_net_amount DESC;
```

Verified output (10 rows total; first 8 shown):

| customer_id | full_name | lifetime_net_amount | overall_avg |
|---|---|---|---|
| 41 | Shannon Strong | 37544.43 | 14431.64 |
| 343 | Jennifer Howard | 35024.55 | 14431.64 |
| 597 | Jessica Simpson | 33636.42 | 14431.64 |
| 173 | Ryan Bonilla | 31159.38 | 14431.64 |
| 67 | Derek Roberts | 30799.93 | 14431.64 |
| 195 | Elizabeth Casey | 29704.83 | 14431.64 |
| 406 | James Johns | 29601.91 | 14431.64 |
| 572 | Cindy Robinson | 29434.89 | 14431.64 |

(This CTE joins to `agg_customer_ltv` with a plain comma-join since
`overall` produces exactly one row — a scalar-like CTE used as a constant
in every outer row's comparison.)

</details>

---

### 4. Rewrite this nested subquery as a CTE

Here's a working but hard-to-read nested-subquery query. Rewrite it using
one or more CTEs so it reads top-to-bottom, and confirm it produces
identical output:

```sql
SELECT c.customer_id, c.full_name, c.customer_segment, c.lifetime_net_amount
FROM agg_customer_ltv c
WHERE c.customer_segment = 'Wholesale'
  AND c.lifetime_net_amount > (
        SELECT AVG(lifetime_net_amount) FROM agg_customer_ltv c2
        WHERE c2.customer_segment = c.customer_segment
  )
ORDER BY c.lifetime_net_amount DESC
LIMIT 5;
```

<details>
<summary>Show solution</summary>

```sql
WITH segment_avg AS (
    SELECT customer_segment, AVG(lifetime_net_amount) AS avg_ltv
    FROM agg_customer_ltv
    WHERE customer_segment IS NOT NULL
    GROUP BY customer_segment
)
SELECT c.customer_id, c.full_name, c.customer_segment, c.lifetime_net_amount
FROM agg_customer_ltv c
JOIN segment_avg sa ON sa.customer_segment = c.customer_segment
WHERE c.customer_segment = 'Wholesale' AND c.lifetime_net_amount > sa.avg_ltv
ORDER BY c.lifetime_net_amount DESC
LIMIT 5;
```

Verified output (identical for both versions):

| customer_id | full_name | customer_segment | lifetime_net_amount |
|---|---|---|---|
| 597 | Jessica Simpson | Wholesale | 33636.42 |
| 128 | Angela Barnes | Wholesale | 24623.53 |
| 273 | Nicole Rogers | Wholesale | 22752.36 |
| 431 | Randy Kaiser | Wholesale | 22453.13 |
| 260 | Cody Wood | Wholesale | 21739.32 |

</details>

---

### 5. Best category per year (multi-CTE chain)

Using two chained CTEs — the first rolling `agg_monthly_sales_by_category`
up to one row per `(year, category)`, the second ranking categories within
each year by that total — find the single best-selling category for every
year in the data. (This previews `RANK()`/window functions from the next
module; try using `ORDER BY total DESC LIMIT 1` per year with a
correlated subquery instead if you haven't covered window functions yet,
then compare the two approaches once you have.)

<details>
<summary>Show solution</summary>

Window-function version (cleanest once you've seen Module 2):

```sql
WITH category_year AS (
    SELECT year, category, ROUND(SUM(total_net_amount), 2) AS year_revenue
    FROM agg_monthly_sales_by_category
    GROUP BY year, category
),
ranked AS (
    SELECT year, category, year_revenue,
           RANK() OVER (PARTITION BY year ORDER BY year_revenue DESC) AS rnk
    FROM category_year
)
SELECT year, category, year_revenue
FROM ranked
WHERE rnk = 1
ORDER BY year;
```

Correlated-subquery version (CTE-only, no window functions):

```sql
WITH category_year AS (
    SELECT year, category, ROUND(SUM(total_net_amount), 2) AS year_revenue
    FROM agg_monthly_sales_by_category
    GROUP BY year, category
)
SELECT cy.year, cy.category, cy.year_revenue
FROM category_year cy
WHERE cy.year_revenue = (
    SELECT MAX(cy2.year_revenue) FROM category_year cy2 WHERE cy2.year = cy.year
)
ORDER BY cy.year;
```

Verified output (both versions):

| year | category | year_revenue |
|---|---|---|
| 2021 | Climbing | 243934.82 |
| 2022 | Nutrition & Hydration | 268912.10 |
| 2023 | Climbing | 253598.69 |
| 2024 | Climbing | 264295.25 |
| 2025 | Climbing | 242061.82 |
| 2026 | Climbing | 113911.92 |

(2026 is a partial year — Oakhaven's data ends 2026-06-30 — so its total is
naturally lower than a full year's.)

</details>
