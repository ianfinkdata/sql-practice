# Exercises: LEAD, LAG, and Period-over-Period Comparisons

<!-- nav -->
Curriculum: [4. LEAD, LAG, and Period-over-Period Comparisons](../../curriculum/03-advanced/04-lead-lag-period-over-period.md). Previous: [3. Window Functions II — Running Totals & Moving Aggregates](03-window-functions-ii-running-totals.md). Next: [5. Recursive CTEs](05-recursive-ctes.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Month-over-month change for one category

Using `agg_monthly_sales_by_category`, compute the month-over-month
dollar change in `total_net_amount` for the `Climbing` category across
2021, using `LAG()`.

<details>
<summary>Show solution</summary>

```sql
SELECT year, month, total_net_amount,
       ROUND(total_net_amount - LAG(total_net_amount) OVER (ORDER BY month), 2) AS mom_change
FROM agg_monthly_sales_by_category
WHERE category = 'Climbing' AND year = 2021
ORDER BY month;
```

Verified output (first row's `mom_change` is `NULL` — no prior month
exists):

| year | month | total_net_amount | mom_change |
|---|---|---|---|
| 2021 | 1 | 17972.83 | *(null)* |
| 2021 | 2 | 33663.09 | 15690.26 |
| 2021 | 3 | 28847.21 | -4815.88 |
| 2021 | 4 | 14295.57 | -14551.64 |
| 2021 | 5 | 22400.84 | 8105.27 |
| 2021 | 6 | 22866.67 | 465.83 |

</details>

---

### 2. Quarter-over-quarter revenue change

Roll `fact_sales` up to one row per `(year, quarter)` (join to `dim_date`
for the quarter), then use `LAG()` to compute the quarter-over-quarter
dollar change. Show the first 8 quarters.

<details>
<summary>Show solution</summary>

```sql
WITH quarterly AS (
    SELECT d.year, d.quarter, ROUND(SUM(f.net_amount), 2) AS quarter_total
    FROM fact_sales f
    JOIN dim_date d ON d.datekey = f.datekey
    GROUP BY d.year, d.quarter
)
SELECT year, quarter, quarter_total,
       LAG(quarter_total) OVER (ORDER BY year, quarter) AS prev_quarter_total,
       ROUND(quarter_total - LAG(quarter_total) OVER (ORDER BY year, quarter), 2) AS qoq_change
FROM quarterly
ORDER BY year, quarter
LIMIT 8;
```

Verified output:

| year | quarter | quarter_total | prev_quarter_total | qoq_change |
|---|---|---|---|---|
| 2021 | 1 | 437339.25 | *(null)* | *(null)* |
| 2021 | 2 | 377280.46 | 437339.25 | -60058.79 |
| 2021 | 3 | 412462.23 | 377280.46 | 35181.77 |
| 2021 | 4 | 391927.88 | 412462.23 | -20534.35 |
| 2022 | 1 | 425162.75 | 391927.88 | 33234.87 |
| 2022 | 2 | 369693.90 | 425162.75 | -55468.85 |
| 2022 | 3 | 500489.31 | 369693.90 | 130795.41 |
| 2022 | 4 | 408633.39 | 500489.31 | -91855.92 |

</details>

---

### 3. The three worst month-over-month drops, ever

Across every category combined (`agg_monthly_sales_by_category` grouped
to one row per `year, month`), find the 3 months with the largest
month-over-month *decrease* in `total_net_amount`. Return `year`,
`month`, `month_total`, `mom_change`, worst first.

<details>
<summary>Show solution</summary>

```sql
WITH monthly AS (
    SELECT year, month, ROUND(SUM(total_net_amount), 2) AS month_total
    FROM agg_monthly_sales_by_category
    GROUP BY year, month
),
changes AS (
    SELECT year, month, month_total,
           ROUND(month_total - LAG(month_total) OVER (ORDER BY year, month), 2) AS mom_change
    FROM monthly
)
SELECT year, month, month_total, mom_change
FROM changes
WHERE mom_change IS NOT NULL
ORDER BY mom_change ASC
LIMIT 3;
```

Verified output:

| year | month | month_total | mom_change |
|---|---|---|---|
| 2021 | 4 | 115860.15 | -50221.39 |
| 2023 | 11 | 110961.86 | -38573.67 |
| 2026 | 2 | 103649.28 | -38265.99 |

</details>

---

### 4. Customer 41's order timeline, forward-looking

Using `LEAD()` partitioned appropriately, show customer 41's order
history with each order's *next* order date alongside it (their most
recent order will show `NULL`, since there's no next order yet). Show the
first 6 orders.

<details>
<summary>Show solution</summary>

```sql
SELECT customer_id, order_date,
       LEAD(order_date) OVER (ORDER BY order_date) AS next_order_date
FROM (SELECT DISTINCT customer_id, order_date FROM fact_sales WHERE customer_id = 41 AND order_date IS NOT NULL)
ORDER BY order_date
LIMIT 6;
```

Verified output:

| customer_id | order_date | next_order_date |
|---|---|---|
| 41 | 2021-08-14 | 2022-02-11 |
| 41 | 2022-02-11 | 2022-05-22 |
| 41 | 2022-05-22 | 2022-07-12 |
| 41 | 2022-07-12 | 2022-09-12 |
| 41 | 2022-09-12 | 2022-09-23 |
| 41 | 2022-09-23 | 2022-11-26 |

Note this is the *same underlying relationship* as Module 4's Example 2,
which computed `days_since_prev` with `LAG()` for customer 343 — this
exercise asks for the mirror-image view with `LEAD()` instead.

</details>

---

### 5. Percent change, with the NULL-safe guard

Extend Exercise 1: add a `mom_pct_change` column (percent change vs. the
prior month), and make sure the very first row (where `LAG()` is `NULL`)
doesn't cause a division error — confirm SQLite returns `NULL` rather than
erroring when dividing by a `NULL` `LAG()` result.

<details>
<summary>Show solution</summary>

```sql
SELECT year, month, total_net_amount,
       ROUND(total_net_amount - LAG(total_net_amount) OVER (ORDER BY month), 2) AS mom_change,
       ROUND(100.0 * (total_net_amount - LAG(total_net_amount) OVER (ORDER BY month))
             / LAG(total_net_amount) OVER (ORDER BY month), 1) AS mom_pct_change
FROM agg_monthly_sales_by_category
WHERE category = 'Climbing' AND year = 2021
ORDER BY month
LIMIT 4;
```

Verified output:

| year | month | total_net_amount | mom_change | mom_pct_change |
|---|---|---|---|---|
| 2021 | 1 | 17972.83 | *(null)* | *(null)* |
| 2021 | 2 | 33663.09 | 15690.26 | 87.3 |
| 2021 | 3 | 28847.21 | -4815.88 | -14.3 |
| 2021 | 4 | 14295.57 | -14551.64 | -50.4 |

No error — SQL arithmetic involving a `NULL` operand (from `LAG()` on the
first row) simply produces `NULL`, not a divide-by-zero or type error.
This is worth confirming deliberately rather than assuming, since it's
exactly the kind of edge case that's easy to overlook until it shows up in
production.

</details>

---

<!-- nav -->
Curriculum: [4. LEAD, LAG, and Period-over-Period Comparisons](../../curriculum/03-advanced/04-lead-lag-period-over-period.md). Previous: [3. Window Functions II — Running Totals & Moving Aggregates](03-window-functions-ii-running-totals.md). Next: [5. Recursive CTEs](05-recursive-ctes.md).
<!-- /nav -->
