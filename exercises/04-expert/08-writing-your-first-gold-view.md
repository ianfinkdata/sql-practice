# Exercises: Writing Your First Gold View

Every exercise here is a plain, read-only `SELECT` — verify each one
against the real, shared `project/oakhaven.db`. None of these should
be persisted as an actual `CREATE VIEW`; you're practicing designing
and verifying gold-style aggregate logic, not modifying the database.

---

### 1. Confirm the grain of the existing monthly rollup

Confirm `agg_monthly_sales_by_category` really does have exactly one
row per (year, month, category) combination — no duplicates at that
grain — and that its total row count matches the facts sheet (528).

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM agg_monthly_sales_by_category;
```

```
528
```

```sql
SELECT year, month, category, COUNT(*)
FROM agg_monthly_sales_by_category
GROUP BY year, month, category
HAVING COUNT(*) > 1;
```

```
(no rows returned)
```

528 total rows, and zero groups with more than one row at the
(year, month, category) grain — confirms the view really is one row
per combination, as its `GROUP BY` promises.

</details>

---

### 2. Write a quarterly version of the category rollup

Write a `SELECT` that rolls sales up to (year, quarter, category)
instead of (year, month, category), using `dim_date.quarter`.

<details>
<summary>Show solution</summary>

```sql
SELECT d.year, d.quarter, p.category,
       COUNT(*) AS order_line_count,
       ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_date d ON d.datekey = f.datekey
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY d.year, d.quarter, p.category
ORDER BY d.year, d.quarter, p.category;
```

First 5 rows, real output:

```
year  quarter  category          order_line_count  total_net_amount
----  -------  ----------------  ----------------  ----------------
2021  1        Accessories       53                32432.45
2021  1        Apparel           92                76345.55
2021  1        Camping & Hiking  54                29662.28
2021  1        Climbing          89                80483.13
2021  1        Footwear          78                63562.21
```

Same inner-join structure as `agg_monthly_sales_by_category` — the
only change is `d.quarter` in place of `d.month`/`d.month_name`.

</details>

---

### 3. Sales by employee region — a question about who's included

Write a `SELECT` giving total net sales and order-line count by
`dim_employee.region`. Since `fact_sales.employee_id` is `NULL` for
~10.4% of rows (online/no-rep sales, per the data dictionary), decide
deliberately: should this rollup use an inner or a left join against
`dim_employee`? Justify your choice in a comment, then verify.

<details>
<summary>Show solution</summary>

An **inner** join against `dim_employee` is the right call here: the
whole point of this rollup is "sales attributed to a rep in a given
region" — a `NULL` `employee_id` has no region to attribute to, so it
should be excluded, not forced into some artificial "unknown region"
bucket via a `LEFT JOIN`. (A `LEFT JOIN` would make sense if the
question were instead "total sales, broken down by region where
known, with online sales as their own bucket" — a different, also
valid question, just not this one.)

```sql
SELECT e.region,
       COUNT(*) AS order_line_count,
       ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_employee e ON e.employee_id = f.employee_id
GROUP BY e.region
ORDER BY total_net_amount DESC;
```

```
region     order_line_count  total_net_amount
---------  ----------------  ----------------
West       3382              2568537.23
South      2119              1560580.80
East       1917              1357036.81
Central    1834              1294425.26
Northeast  1505              1085647.03
```

Row counts sum to 3382+2119+1917+1834+1505 = 10,757 — matching the
facts sheet's `fact_sales JOIN dim_employee` match count exactly
(12,000 − 1,243 NULL `employee_id` = 10,757).

</details>

---

### 4. Top 5 brands by lifetime net sales

`dim_product.brand` isn't used in any existing gold view. Write a
`SELECT` ranking brands by total net sales, limited to the top 5.

<details>
<summary>Show solution</summary>

```sql
SELECT p.brand, ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY p.brand
ORDER BY total_net_amount DESC
LIMIT 5;
```

```
brand           total_net_amount
--------------  ----------------
Foghorn Supply  633719.91
Tundraworks     514288.21
Ridgeway Co.    510918.96
Northfell       487175.42
Marrowpeak      434031.88
```

</details>

---

### 5. Measure exactly what an inner join silently excludes

`agg_monthly_sales_by_category` inner-joins `fact_sales` to both
`dim_date` and `dim_product`. Quantify exactly how many order lines
that inner-join design drops, two ways: (a) compare `fact_sales`'s
total row count against the sum of `order_line_count` across all of
`agg_monthly_sales_by_category`; (b) directly count rows in
`fact_sales` with a `NULL datekey` or an orphan product.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM fact_sales;
```

```
12000
```

```sql
SELECT SUM(order_line_count) FROM agg_monthly_sales_by_category;
```

```
11821
```

`12000 - 11821 = 179` order lines are missing from the rollup.
Confirm directly:

```sql
SELECT COUNT(*) FROM fact_sales
WHERE datekey IS NULL OR is_product_orphan = 1;
```

```
179
```

Exact match. This is the real, quantified cost of the documented
`INNER JOIN` decision in `agg_monthly_sales_by_category.sql` — 179
order lines (about 1.5% of all sales) simply don't appear anywhere in
that view, because they can't be placed on a calendar month or into a
category. A stakeholder reading only the rollup's totals would never
know these 179 lines exist unless someone ran exactly this kind of
reconciliation check.

</details>

---

### 6. Design your own gold aggregate with a documented business decision

Write a `SELECT` for "net sales by channel, excluding cancelled and
returned orders" — a realistic ask ("show me *real*, kept revenue, not
gross including refunds"). Decide explicitly how to handle
`order_status IS NULL` (per the data dictionary, ~10% of
`bronze_sales` rows have a `NULL` `order_status`) — include or exclude
them? — and state your reasoning before writing the query.

<details>
<summary>Show solution</summary>

Decision: treat `NULL` `order_status` as "unknown, not confirmed
cancelled/returned" and **include** it in the "real sales" total,
rather than dropping it. The alternative (excluding unknown-status
rows) would understate revenue for a reason that has nothing to do
with whether the sale was actually cancelled — the status is simply
missing, not negative. This mirrors the kind of explicit,
documented trade-off `agg_monthly_sales_by_category.sql`'s own comment
makes about excluding orphans.

```sql
SELECT f.channel,
       COUNT(*) AS order_line_count,
       ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
WHERE f.order_status NOT IN ('Cancelled', 'Returned') OR f.order_status IS NULL
GROUP BY f.channel
ORDER BY total_net_amount DESC;
```

```
channel   order_line_count  total_net_amount
--------  ----------------  ----------------
In-Store  4198              3030192.63
Online    4150              2972070.73
```

Compare this against the facts sheet's unfiltered channel totals
(In-Store: 5,960 lines / $4,380,739.06; Online: 6,040 lines /
$4,361,549.98) — filtering out cancelled/returned orders removes
roughly 30% of order lines and a proportional chunk of net amount
from each channel, which makes sense as a sanity check: cancellations
and returns shouldn't be wildly more common in one channel than the
other unless something in the business genuinely differs between
online and in-store fulfillment.

</details>
