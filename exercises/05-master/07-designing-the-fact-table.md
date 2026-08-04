# Exercises: Designing the Fact Table

All solutions verified against `project/oakhaven.db`. Try each query
yourself before expanding the solution.

## 1. Verify the grain, the hard way

`fact_sales`'s grain is "one row per order line," i.e. one row per
`(order_id, order_line_id)` pair. Write a query that returns any
`(order_id, order_line_id)` pairs that appear **more than once** — if
the grain genuinely holds, it should return zero rows.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM (
    SELECT order_id, order_line_id
    FROM fact_sales
    GROUP BY order_id, order_line_id
    HAVING COUNT(*) > 1
);
```

| COUNT(*) |
|---|
| 0 |

Zero duplicate grain keys — the stated grain holds.

</details>

## 2. Reproduce the orphan/NULL counts, with percentages

Write one query that returns, for all of `fact_sales`: the count and
percentage of rows with `is_customer_orphan = 1`, the count and
percentage with `is_product_orphan = 1`, and the count and percentage
with a NULL `employee_id`.

<details>
<summary>Show solution</summary>

```sql
SELECT
    SUM(is_customer_orphan) AS cust_orphans,
    ROUND(100.0 * SUM(is_customer_orphan) / COUNT(*), 2) AS cust_orphan_pct,
    SUM(is_product_orphan) AS prod_orphans,
    ROUND(100.0 * SUM(is_product_orphan) / COUNT(*), 2) AS prod_orphan_pct,
    SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END) AS null_emp,
    ROUND(100.0 * SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS null_emp_pct
FROM fact_sales;
```

| cust_orphans | cust_orphan_pct | prod_orphans | prod_orphan_pct | null_emp | null_emp_pct |
|---|---|---|---|---|---|
| 103 | 0.86 | 122 | 1.02 | 1243 | 10.36 |

These match the facts sheet's ground-truth counts exactly — if your
number differs, double-check you're querying `fact_sales` (which
passes these through) and not accidentally filtering somewhere.

</details>

## 3. Non-additive measures: weighted average discount by channel

`discount_pct` is non-additive — you can't just `AVG()` it and trust
the result, because that treats every order line as equally important
regardless of its dollar size. For each `channel`, compute both the
naive `AVG(discount_pct)` and the correct dollar-weighted average
discount (recomputed as `1 - SUM(net_amount) / SUM(quantity *
unit_price)`), restricted to rows where `quantity > 0` and `net_amount
IS NOT NULL`. Do the two numbers agree?

<details>
<summary>Show solution</summary>

```sql
SELECT
    channel,
    ROUND(AVG(discount_pct), 4) AS naive_avg,
    ROUND(1 - SUM(net_amount) * 1.0 / SUM(quantity * unit_price), 4) AS weighted_avg
FROM fact_sales
WHERE quantity > 0 AND net_amount IS NOT NULL
GROUP BY channel
ORDER BY channel;
```

| channel | naive_avg | weighted_avg |
|---|---|---|
| In-Store | 0.1152 | 0.1169 |
| Online | 0.1136 | 0.1134 |

Close, but not identical — In-Store's naive average (0.1152) actually
*understates* the true dollar-weighted discount rate (0.1169), meaning
higher-dollar In-Store lines tend to carry slightly bigger discounts
than lower-dollar ones. That's exactly the kind of distortion a naive
`AVG()` on a non-additive measure can hide.

</details>

## 4. Semi-additive pattern: a monthly running total

Build a monthly net-revenue running total across the whole date range:
for each `(year, month)`, show that month's net sales and a cumulative
running total up through that month. (Hint: aggregate to monthly
totals in a CTE first, then apply `SUM() OVER (ORDER BY year, month)`
to that.) Show the first 6 months.

<details>
<summary>Show solution</summary>

```sql
WITH monthly AS (
    SELECT d.year, d.month, ROUND(SUM(f.net_amount), 2) AS monthly_net
    FROM fact_sales f
    JOIN dim_date d ON d.datekey = f.datekey
    GROUP BY d.year, d.month
)
SELECT year, month, monthly_net,
       ROUND(SUM(monthly_net) OVER (ORDER BY year, month), 2) AS running_total
FROM monthly
ORDER BY year, month
LIMIT 6;
```

| year | month | monthly_net | running_total |
|---|---|---|---|
| 2021 | 1 | 140828.03 | 140828.03 |
| 2021 | 2 | 129779.17 | 270607.2 |
| 2021 | 3 | 166732.05 | 437339.25 |
| 2021 | 4 | 116531.74 | 553870.99 |
| 2021 | 5 | 125472.53 | 679343.52 |
| 2021 | 6 | 135276.19 | 814619.71 |

`running_total` is a semi-additive-style measure: correct to read at
any one row, wrong to `SUM()` across rows.

</details>

## 5. Quantify the business impact of orphan rows

The fact table doesn't drop orphan-customer rows — it flags them. Put
a number on what's at stake: for rows where `is_customer_orphan = 1`,
how many total units (`quantity`) and how much total `net_amount` do
they represent?

<details>
<summary>Show solution</summary>

```sql
SELECT SUM(quantity) AS qty_at_risk, ROUND(SUM(net_amount), 2) AS net_at_risk
FROM fact_sales
WHERE is_customer_orphan = 1;
```

| qty_at_risk | net_at_risk |
|---|---|
| 267 | 83303.47 |

Over $83,000 in recorded net sales is attached to a `customer_id` that
doesn't exist in `dim_customer` — a real, quantifiable data-quality
issue that would have been invisible if `fact_sales` had silently
inner-joined it away.

</details>

## 6. Hardest: a one-row data-quality scorecard

Combine what you've built above into a single query that returns one
row summarizing `fact_sales`'s overall health: `total_rows`, and the
percentage of rows affected by each of the four conditions module 7
covered (`is_customer_orphan`, `is_product_orphan`, NULL
`employee_id`, NULL `datekey`).

<details>
<summary>Show solution</summary>

```sql
SELECT
    COUNT(*) AS total_rows,
    ROUND(100.0 * SUM(is_customer_orphan) / COUNT(*), 2) AS pct_customer_orphan,
    ROUND(100.0 * SUM(is_product_orphan) / COUNT(*), 2) AS pct_product_orphan,
    ROUND(100.0 * SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_null_employee,
    ROUND(100.0 * SUM(CASE WHEN datekey IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_null_datekey
FROM fact_sales;
```

| total_rows | pct_customer_orphan | pct_product_orphan | pct_null_employee | pct_null_datekey |
|---|---|---|---|---|
| 12000 | 0.86 | 1.02 | 10.36 | 0.48 |

This is the kind of single-row summary a real data-quality dashboard
would surface on top of a fact table like this one — and it only
works because the fact table chose to carry these flags through
instead of hiding the rows that triggered them.

</details>
