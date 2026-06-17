# Tier 3 — Advanced Exercises

> Analytics-grade SQL: window functions, ranking, running totals, `LEAD`/`LAG`,
> custom frames, CTEs (including a recursive one), date intelligence, pivoting,
> and string/regex work.

Uses the [shared dataset](README.md#the-shared-dataset). These get genuinely
chewy toward the end — write your attempt first, then expand.

← Back to [Exercises](README.md) · matching curriculum: [`03-advanced`](../curriculum/03-advanced/)

---

## 1. Your first window function

Show each sale's `amount` next to the **overall average amount** (on every row),
without collapsing the rows.

<details><summary>Show solution</summary>

```sql
SELECT sale_id,
       amount,
       AVG(amount) OVER () AS overall_avg
FROM sales;
```

An empty `OVER ()` window aggregates across *all* rows while keeping each row —
unlike `GROUP BY`, which collapses them.

</details>

---

## 2. PARTITION BY

For each sale, show its amount and the **average amount for that customer**.

<details><summary>Show solution</summary>

```sql
SELECT sale_id,
       customer_id,
       amount,
       AVG(amount) OVER (PARTITION BY customer_id) AS cust_avg
FROM sales;
```

`PARTITION BY` restarts the window per customer — like `GROUP BY`, but the
detail rows survive.

</details>

---

## 3. Ranking with ROW_NUMBER

Number each customer's sales from largest to smallest amount (1 = biggest).

<details><summary>Show solution</summary>

```sql
SELECT sale_id,
       customer_id,
       amount,
       ROW_NUMBER() OVER (
           PARTITION BY customer_id
           ORDER BY amount DESC
       ) AS rn
FROM sales;
```

`ROW_NUMBER()` assigns a unique sequential number within each partition, ordered
by amount.

</details>

---

## 4. RANK vs DENSE_RANK

Rank reps by total revenue. Show both `RANK` and `DENSE_RANK` so you can see how
they treat ties.

<details><summary>Show solution</summary>

```sql
SELECT r.rep_name,
       SUM(s.amount) AS total_rev,
       RANK()       OVER (ORDER BY SUM(s.amount) DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY SUM(s.amount) DESC) AS dense_rnk
FROM sales_rep AS r
JOIN sales AS s ON s.rep_id = r.rep_id
GROUP BY r.rep_name;
```

Window functions run *after* `GROUP BY`, so they can wrap an aggregate. `RANK`
leaves gaps after ties (1,1,3); `DENSE_RANK` does not (1,1,2).

</details>

---

## 5. Top-N per group

Return only each customer's **top 2** sales by amount.

<details><summary>Show solution</summary>

```sql
SELECT *
FROM (
    SELECT sale_id,
           customer_id,
           amount,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY amount DESC
           ) AS rn
    FROM sales
) ranked
WHERE rn <= 2;
```

Window functions can't go in `WHERE`, so rank in a subquery, then filter on the
result. This "rank-then-filter" pattern is the canonical top-N-per-group.

</details>

---

## 6. Running total

For one customer's sales ordered by date, show a **running cumulative total** of
amount.

<details><summary>Show solution</summary>

```sql
SELECT sale_date,
       amount,
       SUM(amount) OVER (
           PARTITION BY customer_id
           ORDER BY sale_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total
FROM sales;
```

Adding `ORDER BY` inside `OVER` turns `SUM` into a running total; the explicit
frame says "all rows from the start up to this one."

</details>

---

## 7. LAG — compare to the previous row

For each customer's sales in date order, show the previous sale's amount and the
day-over-sale **change**.

<details><summary>Show solution</summary>

```sql
SELECT customer_id,
       sale_date,
       amount,
       LAG(amount) OVER (
           PARTITION BY customer_id ORDER BY sale_date
       ) AS prev_amount,
       amount - LAG(amount) OVER (
           PARTITION BY customer_id ORDER BY sale_date
       ) AS delta
FROM sales;
```

`LAG` reaches back one row in the ordered partition; the first row per customer
gets `NULL` (no prior sale).

</details>

---

## 8. LEAD — gap to the next event

For each customer, show how many days until their **next** purchase.

<details><summary>Show solution</summary>

```sql
SELECT customer_id,
       sale_date,
       LEAD(sale_date) OVER (
           PARTITION BY customer_id ORDER BY sale_date
       ) AS next_sale_date,
       LEAD(sale_date) OVER (
           PARTITION BY customer_id ORDER BY sale_date
       ) - sale_date AS days_to_next
FROM sales;
```

`LEAD` is the mirror of `LAG`, looking forward. Subtracting dates gives the gap
(some engines need `DATEDIFF` — see the Dialect Decoder).

</details>

---

## 9. A moving average with a custom frame

Show a 3-sale **moving average** of amount per customer (current row plus the two
before it).

<details><summary>Show solution</summary>

```sql
SELECT customer_id,
       sale_date,
       amount,
       AVG(amount) OVER (
           PARTITION BY customer_id
           ORDER BY sale_date
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3
FROM sales;
```

The frame `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` is a sliding 3-row window;
early rows simply average fewer values.

</details>

---

## 10. CTEs for readability

Using a CTE, compute each customer's total revenue, then return only those above
the **average** customer total.

<details><summary>Show solution</summary>

```sql
WITH customer_totals AS (
    SELECT customer_id,
           SUM(amount) AS total_rev
    FROM sales
    GROUP BY customer_id
)
SELECT customer_id, total_rev
FROM customer_totals
WHERE total_rev > (SELECT AVG(total_rev) FROM customer_totals);
```

A CTE (`WITH`) names an intermediate result you can reference twice — here, once
in the `SELECT` and once to compute the average.

</details>

---

## 11. Recursive CTE — a date spine

Generate one row per day for January 2024 (a calendar/date spine you could join
sales onto).

<details><summary>Show solution</summary>

```sql
WITH RECURSIVE calendar AS (
    SELECT DATE '2024-01-01' AS d
    UNION ALL
    SELECT d + INTERVAL '1 day'
    FROM calendar
    WHERE d < DATE '2024-01-31'
)
SELECT d
FROM calendar;
```

A recursive CTE has an **anchor** (the first day) and a **recursive member** that
adds a day until the stop condition fails. Date spines fill gaps so days with no
sales still show up.

</details>

---

## 12. Date intelligence — month-over-month growth

Report total revenue per month and the **percent change** versus the prior month.

<details><summary>Show solution</summary>

```sql
WITH monthly AS (
    SELECT DATE_TRUNC('month', sale_date) AS mth,
           SUM(amount)                    AS revenue
    FROM sales
    GROUP BY DATE_TRUNC('month', sale_date)
)
SELECT mth,
       revenue,
       LAG(revenue) OVER (ORDER BY mth) AS prev_revenue,
       ROUND(
           100.0 * (revenue - LAG(revenue) OVER (ORDER BY mth))
                 / LAG(revenue) OVER (ORDER BY mth), 1
       ) AS pct_change
FROM monthly
ORDER BY mth;
```

`DATE_TRUNC` rolls dates up to the month; `LAG` fetches last month's revenue so
you can compute growth. (Pivot bonus: pivot these months into columns with
`CASE`/`SUM`, and `LIKE`/`SUBSTRING` would extract pieces of `email` for the
string-processing variant of this drill.)

</details>

---

Next up: [Tier 4 — Expert](tier-4-expert.md) →
