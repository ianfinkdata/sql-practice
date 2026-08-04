# Exercises: The Medallion Pipeline, Start to Finish

All solutions verified against `project/oakhaven.db`.

## 1. Follow the discount_pct bug through all three layers

Order 21, line 1 has the `discount_pct` whole-number data-entry bug
mentioned in the facts sheet (`25.0` stored instead of `0.25`). Write
one query joining `bronze_sales` → `silver_sales` → `fact_sales` on
`(order_id, order_line_id)` that shows `discount_pct` at each layer
plus the final `net_amount`, for `order_id = 21, order_line_id = 1`.

<details>
<summary>Show solution</summary>

```sql
SELECT
    b.discount_pct AS bronze_discount,
    s.discount_pct AS silver_discount,
    f.discount_pct AS gold_discount,
    f.net_amount AS gold_net_amount
FROM bronze_sales b
JOIN silver_sales s ON s.order_id = b.order_id AND s.order_line_id = b.order_line_id
JOIN fact_sales f ON f.order_id = b.order_id AND f.order_line_id = b.order_line_id
WHERE b.order_id = 21 AND b.order_line_id = 1;
```

| bronze_discount | silver_discount | gold_discount | gold_net_amount |
|---|---|---|---|
| 25.0 | 0.25 | 0.25 | 1786.01 |

Bronze's `25.0` (the bug — a whole-number percentage instead of a
fraction) is caught and fixed exactly once, in silver. Gold inherits
the already-correct `0.25` and does nothing further to it.

</details>

## 2. How many rows did silver's discount fix actually touch?

Count how many rows in `bronze_sales` have the whole-number
`discount_pct` bug (`discount_pct > 1`), by joining to `silver_sales`
on the grain key.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*)
FROM bronze_sales b
JOIN silver_sales s ON s.order_id = b.order_id AND s.order_line_id = b.order_line_id
WHERE b.discount_pct > 1;
```

| COUNT(*) |
|---|
| 110 |

110 order lines (about 0.9% of all 12,000) had this specific bug —
matching the facts sheet's documented rate. Every one of them gets
fixed the same way, in the same place, because the fix lives in
`silver_sales`'s single `CASE WHEN discount_pct > 1 THEN discount_pct /
100.0 ELSE discount_pct END` expression rather than being re-solved
per downstream query.

</details>

## 3. The employee thread: row-count parity and a messy value

Two parts. First, confirm `bronze_employees` → `silver_employees` →
`dim_employee` all have the same row count (no employees silently
dropped or duplicated across layers). Second, look up employee 16's
`department` and `region` in `bronze_employees` and in `dim_employee`
side by side to see what silver's cleaning actually changed.

<details>
<summary>Show solution</summary>

```sql
SELECT
    (SELECT COUNT(*) FROM bronze_employees) AS bronze,
    (SELECT COUNT(*) FROM silver_employees) AS silver,
    (SELECT COUNT(*) FROM dim_employee) AS gold;
```

| bronze | silver | gold |
|---|---|---|
| 35 | 35 | 35 |

```sql
SELECT employee_id, department, region FROM bronze_employees WHERE employee_id = 16
UNION ALL
SELECT employee_id, department, region FROM dim_employee WHERE employee_id = 16;
```

| employee_id | department | region |
|---|---|---|
| 16 | sales | south |
| 16 | Sales | South |

35 employees at every layer, and employee 16's lowercase `sales`/`south`
in bronze becomes properly-cased `Sales`/`South` by the time it reaches
`dim_employee` — cleaned once in `silver_employees`, unchanged
afterward, same pattern as every other thread in this pipeline.

</details>

## 4. Prove `fact_sales` is built on silver, not bronze

Without reading the `.sql` file directly, use `sqlite_master` to
inspect `fact_sales`'s definition and confirm which table it selects
`FROM`.

<details>
<summary>Show solution</summary>

```sql
SELECT sql FROM sqlite_master WHERE name = 'fact_sales';
```

The definition's `FROM` clause reads `FROM silver_sales s` — confirming
`fact_sales` is built entirely on the cleaned silver layer, never
directly on `bronze_sales`. This is exactly why gold doesn't need to
re-parse dates or re-fix the discount bug: silver already did it, once.

</details>

## 5. Harder: spot-check row-count parity across every bronze/silver/gold thread at once

Write a single query (using `UNION ALL`) that reports bronze, silver,
and gold-equivalent row counts for all four base entities: sales,
customers, products, and employees. (Gold-equivalent tables:
`fact_sales`, `dim_customer`, `dim_product`, `dim_employee`.)

<details>
<summary>Show solution</summary>

```sql
SELECT 'sales' AS thread, (SELECT COUNT(*) FROM bronze_sales) AS bronze,
       (SELECT COUNT(*) FROM silver_sales) AS silver, (SELECT COUNT(*) FROM fact_sales) AS gold
UNION ALL
SELECT 'customers', (SELECT COUNT(*) FROM bronze_customers),
       (SELECT COUNT(*) FROM silver_customers), (SELECT COUNT(*) FROM dim_customer)
UNION ALL
SELECT 'products', (SELECT COUNT(*) FROM bronze_products),
       (SELECT COUNT(*) FROM silver_products), (SELECT COUNT(*) FROM dim_product)
UNION ALL
SELECT 'employees', (SELECT COUNT(*) FROM bronze_employees),
       (SELECT COUNT(*) FROM silver_employees), (SELECT COUNT(*) FROM dim_employee);
```

| thread | bronze | silver | gold |
|---|---|---|---|
| sales | 12000 | 12000 | 12000 |
| customers | 600 | 600 | 600 |
| products | 150 | 150 | 150 |
| employees | 35 | 35 | 35 |

Perfect parity across all four threads, all three layers. This is the
single most useful sanity check to run on *any* medallion pipeline
you're handed for the first time — before trusting a single number out
of gold, confirm nothing got silently dropped or duplicated on the way
there.

</details>
