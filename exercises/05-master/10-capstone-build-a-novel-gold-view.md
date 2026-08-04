# Capstone Exercises: Build a Novel Gold View

Three original gold-style views, none of which exist in
`project/gold/`. Each was designed and solved by hand, then verified
against real output from `project/oakhaven.db` — grade your own
solution against the exact tables shown here, not just "does it look
plausible."

Attempt each one yourself before expanding the solution. Query
`project/oakhaven.db` directly with `sqlite3` to check your work.

## 1. Graded capstone: customer order-frequency segmentation

**Grain:** one row per `(customer_segment, frequency_tier)` pair.

Build a view that buckets every customer in `dim_customer` into a
frequency tier based on their distinct `order_id` count in
`fact_sales`, then rolls that up by `customer_segment`:

- `No Orders` — 0 orders
- `Light (1-8 orders)` — 1 to 8 orders
- `Regular (9-14 orders)` — 9 to 14 orders
- `Frequent (15+ orders)` — 15 or more orders

Start from `dim_customer` (LEFT JOIN order counts on), so customers
with zero orders would still appear if any existed. Treat a NULL
`customer_segment` as `'Unknown'` rather than dropping those rows from
the `GROUP BY`. Return `customer_segment`, `frequency_tier`,
`num_customers`, and `avg_orders` (average order count within that
bucket, rounded to 2 decimals).

<details>
<summary>Show solution</summary>

```sql
WITH orders_per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
    FROM fact_sales
    GROUP BY customer_id
),
tiered AS (
    SELECT
        c.customer_id,
        COALESCE(c.customer_segment, 'Unknown') AS customer_segment,
        COALESCE(o.order_count, 0) AS order_count,
        CASE
            WHEN COALESCE(o.order_count, 0) = 0 THEN 'No Orders'
            WHEN o.order_count <= 8 THEN 'Light (1-8 orders)'
            WHEN o.order_count <= 14 THEN 'Regular (9-14 orders)'
            ELSE 'Frequent (15+ orders)'
        END AS frequency_tier
    FROM dim_customer c
    LEFT JOIN orders_per_customer o ON o.customer_id = c.customer_id
)
SELECT
    customer_segment,
    frequency_tier,
    COUNT(*) AS num_customers,
    ROUND(AVG(order_count), 2) AS avg_orders
FROM tiered
GROUP BY customer_segment, frequency_tier
ORDER BY customer_segment,
    CASE frequency_tier
        WHEN 'No Orders' THEN 0
        WHEN 'Light (1-8 orders)' THEN 1
        WHEN 'Regular (9-14 orders)' THEN 2
        ELSE 3
    END;
```

**GRADED EXPECTED RESULT** (exact — 12 rows, real verified output):

| customer_segment | frequency_tier | num_customers | avg_orders |
|---|---|---|---|
| Retail | Light (1-8 orders) | 30 | 6.73 |
| Retail | Regular (9-14 orders) | 105 | 11.6 |
| Retail | Frequent (15+ orders) | 38 | 17.05 |
| Unknown | Light (1-8 orders) | 2 | 6.0 |
| Unknown | Regular (9-14 orders) | 9 | 11.78 |
| Unknown | Frequent (15+ orders) | 3 | 15.33 |
| VIP | Light (1-8 orders) | 31 | 7.06 |
| VIP | Regular (9-14 orders) | 130 | 11.42 |
| VIP | Frequent (15+ orders) | 46 | 17.11 |
| Wholesale | Light (1-8 orders) | 31 | 6.87 |
| Wholesale | Regular (9-14 orders) | 133 | 11.34 |
| Wholesale | Frequent (15+ orders) | 42 | 16.52 |

**Quick self-check if your row-by-row output doesn't match exactly:**
your result should have exactly 12 rows, no `No Orders` row (every real
customer has placed at least 3 orders in this dataset), and
`SUM(num_customers)` across all 12 rows must equal **600** — the exact
`dim_customer` row count from the facts sheet. If your sum isn't 600,
you've either dropped customers (check you started from `dim_customer`,
not `fact_sales`) or double-counted them (check your `GROUP BY` and
join don't fan out).

</details>

## 2. Alternate novel view: signup-cohort 90-day activation rate

**Grain:** one row per signup year.

For each `signup_year` (extracted from `dim_customer.signup_date`),
compute: cohort size, how many of those customers placed their first
order (`MIN(order_date)` in `fact_sales`) within 90 days of their
signup date, and the resulting activation rate as a percentage.

<details>
<summary>Show solution</summary>

```sql
WITH cohort AS (
    SELECT customer_id, signup_date, CAST(strftime('%Y', signup_date) AS INTEGER) AS signup_year
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),
first_order AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY customer_id
)
SELECT
    c.signup_year,
    COUNT(*) AS cohort_size,
    SUM(CASE WHEN f.first_order_date IS NOT NULL
             AND julianday(f.first_order_date) - julianday(c.signup_date) BETWEEN 0 AND 90
             THEN 1 ELSE 0 END) AS activated_within_90d,
    ROUND(100.0 * SUM(CASE WHEN f.first_order_date IS NOT NULL
             AND julianday(f.first_order_date) - julianday(c.signup_date) BETWEEN 0 AND 90
             THEN 1 ELSE 0 END) / COUNT(*), 2) AS activation_rate_pct
FROM cohort c
LEFT JOIN first_order f ON f.customer_id = c.customer_id
GROUP BY c.signup_year
ORDER BY c.signup_year;
```

**Verified real output (9 rows, 2018–2026):**

| signup_year | cohort_size | activated_within_90d | activation_rate_pct |
|---|---|---|---|
| 2018 | 63 | 0 | 0.0 |
| 2019 | 74 | 0 | 0.0 |
| 2020 | 70 | 5 | 7.14 |
| 2021 | 66 | 11 | 16.67 |
| 2022 | 81 | 1 | 1.23 |
| 2023 | 62 | 0 | 0.0 |
| 2024 | 76 | 0 | 0.0 |
| 2025 | 70 | 0 | 0.0 |
| 2026 | 38 | 0 | 0.0 |

This is a genuinely interesting (if slightly sobering) result: 90-day
activation is essentially zero for almost every cohort. That's a real
finding worth investigating before shipping a dashboard built on this
metric — it likely means most Oakhaven customers' *first* order tends
to land well outside a 90-day post-signup window relative to when
`fact_sales`' order history actually starts (2021-01-01), which
truncates the observable activation window for the earliest cohorts in
particular. Notice the pattern this teaches: a novel gold view isn't
"done" just because it runs — reading its actual output and asking
whether the result makes sense is part of building it.

**Self-check:** 9 rows total (years 2018 through 2026 inclusive);
`SUM(cohort_size)` should equal the count of customers with a non-NULL
`signup_date` (600, since none are NULL in this dataset).

</details>

## 3. Alternate novel view: cross-category purchase breadth

**Grain:** one row per `(customer_segment, breadth_tier)` pair.

For each customer, count the distinct product `category` values
they've purchased from (via `fact_sales JOIN dim_product`, excluding
orphan-customer rows). Bucket into:

- `No Purchases` — 0 categories
- `Narrow (1-2 categories)`
- `Moderate (3-4 categories)`
- `Broad (5+ categories)`

Roll up by `customer_segment` (again treating NULL as `'Unknown'`),
returning customer count and average distinct-category count per
bucket.

<details>
<summary>Show solution</summary>

```sql
WITH customer_categories AS (
    SELECT f.customer_id, COUNT(DISTINCT p.category) AS distinct_categories_purchased
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    WHERE f.is_customer_orphan = 0
    GROUP BY f.customer_id
),
tiered AS (
    SELECT
        c.customer_id,
        COALESCE(c.customer_segment, 'Unknown') AS customer_segment,
        COALESCE(cc.distinct_categories_purchased, 0) AS distinct_categories_purchased,
        CASE
            WHEN COALESCE(cc.distinct_categories_purchased, 0) = 0 THEN 'No Purchases'
            WHEN cc.distinct_categories_purchased <= 2 THEN 'Narrow (1-2 categories)'
            WHEN cc.distinct_categories_purchased <= 4 THEN 'Moderate (3-4 categories)'
            ELSE 'Broad (5+ categories)'
        END AS breadth_tier
    FROM dim_customer c
    LEFT JOIN customer_categories cc ON cc.customer_id = c.customer_id
)
SELECT
    customer_segment,
    breadth_tier,
    COUNT(*) AS num_customers,
    ROUND(AVG(distinct_categories_purchased), 2) AS avg_categories
FROM tiered
GROUP BY customer_segment, breadth_tier
ORDER BY customer_segment,
    CASE breadth_tier
        WHEN 'No Purchases' THEN 0
        WHEN 'Narrow (1-2 categories)' THEN 1
        WHEN 'Moderate (3-4 categories)' THEN 2
        ELSE 3
    END;
```

**Verified real output (10 rows):**

| customer_segment | breadth_tier | num_customers | avg_categories |
|---|---|---|---|
| Retail | Moderate (3-4 categories) | 2 | 4.0 |
| Retail | Broad (5+ categories) | 171 | 7.13 |
| Unknown | Broad (5+ categories) | 14 | 7.0 |
| VIP | Moderate (3-4 categories) | 1 | 4.0 |
| VIP | Broad (5+ categories) | 206 | 7.18 |
| Wholesale | Narrow (1-2 categories) | 1 | 2.0 |
| Wholesale | Moderate (3-4 categories) | 5 | 3.8 |
| Wholesale | Broad (5+ categories) | 200 | 7.22 |

Nearly every customer, regardless of segment, buys broadly across 5+
of the 8 categories — with a high enough average order count per
customer (established in exercise 1), it makes sense that most
customers eventually touch most categories. Notice `SUM(num_customers)`
here: 2+171+14+1+206+1+5+200 = 600, the full customer base — the same
self-check discipline as the other two views in this file.

</details>
