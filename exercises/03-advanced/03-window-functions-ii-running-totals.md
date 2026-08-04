# Exercises: Window Functions II — Running Totals & Moving Aggregates

<!-- nav -->
Curriculum: [3. Window Functions II — Running Totals & Moving Aggregates](../../curriculum/03-advanced/03-window-functions-ii-running-totals.md). Previous: [2. Window Functions I — ROW_NUMBER, RANK, DENSE_RANK](02-window-functions-i-row-number-rank.md). Next: [4. LEAD, LAG, and Period-over-Period Comparisons](04-lead-lag-period-over-period.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Running total for one category, one year

Using `agg_monthly_sales_by_category`, compute the running total of
`total_net_amount` for the `Footwear` category across all 12 months of
2021, ordered by month.

<details>
<summary>Show solution</summary>

```sql
SELECT year, month, total_net_amount,
       ROUND(SUM(total_net_amount) OVER (ORDER BY month), 2) AS running_total
FROM agg_monthly_sales_by_category
WHERE category = 'Footwear' AND year = 2021
ORDER BY month;
```

Verified output:

| year | month | total_net_amount | running_total |
|---|---|---|---|
| 2021 | 1 | 12737.88 | 12737.88 |
| 2021 | 2 | 21705.37 | 34443.25 |
| 2021 | 3 | 29118.96 | 63562.21 |
| 2021 | 4 | 17083.32 | 80645.53 |
| 2021 | 5 | 19004.43 | 99649.96 |
| 2021 | 6 | 12691.06 | 112341.02 |
| 2021 | 7 | 17003.66 | 129344.68 |
| 2021 | 8 | 18667.92 | 148012.60 |
| 2021 | 9 | 12876.26 | 160888.86 |
| 2021 | 10 | 10817.23 | 171706.09 |
| 2021 | 11 | 20537.81 | 192243.90 |
| 2021 | 12 | 24480.65 | 216724.55 |

</details>

---

### 2. 3-day moving average, end of window

Using `agg_daily_sales`, compute a 3-day trailing moving average of
`total_net_amount` (current day plus the 2 before it) for 2026-06-20
through 2026-06-30.

<details>
<summary>Show solution</summary>

```sql
SELECT order_date, total_net_amount,
       ROUND(AVG(total_net_amount) OVER (
           ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_3d
FROM agg_daily_sales
WHERE order_date BETWEEN '2026-06-20' AND '2026-06-30'
ORDER BY order_date;
```

Verified output:

| order_date | total_net_amount | moving_avg_3d |
|---|---|---|
| 2026-06-20 | 102.53 | 102.53 |
| 2026-06-21 | 2238.61 | 1170.57 |
| 2026-06-22 | 3234.82 | 1858.65 |
| 2026-06-23 | 2258.85 | 2577.43 |
| 2026-06-24 | 5856.69 | 3783.45 |
| 2026-06-25 | 2657.89 | 3591.14 |
| 2026-06-26 | 1022.67 | 3179.08 |
| 2026-06-27 | 2749.61 | 2143.39 |
| 2026-06-28 | 5564.41 | 3112.23 |
| 2026-06-29 | 2635.42 | 3649.81 |
| 2026-06-30 | 7203.72 | 5134.52 |

</details>

---

### 3. Running maximum

Using `agg_daily_sales`, find the running maximum `total_net_amount`
observed so far, day by day, for 2021-01-01 through 2021-01-15. (i.e. "the
best single day so far, as of each day.")

<details>
<summary>Show solution</summary>

```sql
SELECT order_date, total_net_amount,
       ROUND(MAX(total_net_amount) OVER (ORDER BY order_date), 2) AS running_max
FROM agg_daily_sales
WHERE order_date BETWEEN '2021-01-01' AND '2021-01-15'
ORDER BY order_date;
```

Verified output:

| order_date | total_net_amount | running_max |
|---|---|---|
| 2021-01-01 | 2318.71 | 2318.71 |
| 2021-01-02 | 3381.01 | 3381.01 |
| 2021-01-03 | 1914.65 | 3381.01 |
| 2021-01-04 | 3594.94 | 3594.94 |
| 2021-01-05 | 3059.74 | 3594.94 |
| 2021-01-06 | 7591.42 | 7591.42 |
| 2021-01-07 | 8585.33 | 8585.33 |
| 2021-01-08 | 0.0 | 8585.33 |
| 2021-01-09 | 4533.02 | 8585.33 |
| 2021-01-10 | 6908.29 | 8585.33 |
| 2021-01-11 | 4136.28 | 8585.33 |
| 2021-01-12 | 1388.51 | 8585.33 |
| 2021-01-13 | 3262.90 | 8585.33 |
| 2021-01-14 | 6909.98 | 8585.33 |
| 2021-01-15 | 1104.92 | 8585.33 |

Note 2021-01-08 has `total_net_amount = 0.0` — a zero-order day (the
date-spine pattern, covered fully in Module 7) — and the running max
correctly holds steady rather than dropping.

</details>

---

### 4. Running total, partitioned by category

Using `agg_monthly_sales_by_category`, compute the running total of
`total_net_amount` for the `Climbing` category across the first half of
2021 (months 1–6), partitioned so the running total is scoped to that
category alone (even though this particular query only touches one
category, write it as if it might see more than one — i.e. include
`PARTITION BY category`).

<details>
<summary>Show solution</summary>

```sql
SELECT category, year, month, total_net_amount,
       ROUND(SUM(total_net_amount) OVER (PARTITION BY category ORDER BY year, month), 2)
           AS category_running_total
FROM agg_monthly_sales_by_category
WHERE category = 'Climbing' AND year = 2021 AND month <= 6
ORDER BY month;
```

Verified output:

| category | year | month | total_net_amount | category_running_total |
|---|---|---|---|---|
| Climbing | 2021 | 1 | 17972.83 | 17972.83 |
| Climbing | 2021 | 2 | 33663.09 | 51635.92 |
| Climbing | 2021 | 3 | 28847.21 | 80483.13 |
| Climbing | 2021 | 4 | 14295.57 | 94778.70 |
| Climbing | 2021 | 5 | 22400.84 | 117179.54 |
| Climbing | 2021 | 6 | 22866.67 | 140046.21 |

</details>

---

### 5. Which day pushed the running total over $30,000?

Using the running-total query from Exercise 1's pattern but applied to
`agg_daily_sales` for January 2021, find the first `order_date` where the
running total (from 2021-01-01 onward) exceeds $30,000. (Hint: compute the
running total in a CTE, then filter and take the earliest date where it
crosses the threshold.)

<details>
<summary>Show solution</summary>

```sql
WITH running AS (
    SELECT order_date, total_net_amount,
           SUM(total_net_amount) OVER (ORDER BY order_date) AS running_total
    FROM agg_daily_sales
    WHERE order_date BETWEEN '2021-01-01' AND '2021-01-31'
)
SELECT order_date, ROUND(running_total, 2) AS running_total
FROM running
WHERE running_total > 30000
ORDER BY order_date
LIMIT 1;
```

Verified output:

| order_date | running_total |
|---|---|
| 2021-01-07 | 30445.80 |

</details>

---

<!-- nav -->
Curriculum: [3. Window Functions II — Running Totals & Moving Aggregates](../../curriculum/03-advanced/03-window-functions-ii-running-totals.md). Previous: [2. Window Functions I — ROW_NUMBER, RANK, DENSE_RANK](02-window-functions-i-row-number-rank.md). Next: [4. LEAD, LAG, and Period-over-Period Comparisons](04-lead-lag-period-over-period.md).
<!-- /nav -->
