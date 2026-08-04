# Exercises: 3. Grain: The Most Important Decision in Star Schema Design

Work against `project/oakhaven.db`. Read-only — every query below is a
`SELECT`.

---

### 1. Verify the grain yourself

Confirm that `(order_id, order_line_id)` uniquely identifies every row
in `fact_sales`, and confirm that `order_id` alone does not.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id || '-' || order_line_id) AS distinct_order_lines,
       COUNT(DISTINCT order_id) AS distinct_orders
FROM fact_sales;
```

| total_rows | distinct_order_lines | distinct_orders |
|---|---|---|
| 12000 | 12000 | 7199 |

`total_rows` equals `distinct_order_lines` (12,000 = 12,000) — the
composite key `(order_id, order_line_id)` is unique, confirming the
declared grain. `distinct_orders` (7,199) is smaller than
`total_rows`, confirming `order_id` alone is *not* a valid grain key —
it repeats across an order's multiple lines.

</details>

---

### 2. Test a plausible-but-wrong grain hypothesis

Someone claims `fact_sales`'s grain could just as well be described as
"one row per customer-product combination." Test that claim: is
`(customer_id, product_id)` unique across `fact_sales`?

<details>
<summary>Show solution</summary>

```sql
SELECT customer_id, product_id, COUNT(*) AS n
FROM fact_sales
GROUP BY customer_id, product_id
HAVING COUNT(*) > 1
ORDER BY n DESC
LIMIT 5;
```

| customer_id | product_id | n |
|---|---|---|
| 44 | 100 | 4 |
| 233 | 34 | 4 |
| 402 | 92 | 4 |
| 32 | 71 | 3 |
| 55 | 9 | 3 |

The claim is false: plenty of `(customer_id, product_id)` pairs appear
multiple times (a customer who bought the same product across several
separate orders over time). `(customer_id, product_id)` is a
reasonable thing to *group by* for analysis ("how many times has this
customer bought this product"), but it is not the fact table's grain —
grain is about what a single stored row represents, not about every
possible way you might later aggregate the data.

</details>

---

### 3. Another `COUNT(*)` grain trap

How many distinct customers have placed at least one order line in
`fact_sales`? Write the naive version first (a plain row count) and
then the correct version, and compare.

<details>
<summary>Show solution</summary>

```sql
-- naive: counts LINES, not customers
SELECT COUNT(*) AS naive_row_count
FROM fact_sales
WHERE customer_id IS NOT NULL;
```

| naive_row_count |
|---|
| 12000 |

```sql
-- correct: counts distinct customers
SELECT COUNT(DISTINCT customer_id) AS true_distinct_customers
FROM fact_sales
WHERE customer_id IS NOT NULL;
```

| true_distinct_customers |
|---|
| 661 |

12,000 vs. 661 — an enormous gap, for exactly the reason covered in
the lesson: `fact_sales`'s grain is order line, so counting rows never
directly answers "how many customers." (661 is also slightly higher
than `dim_customer`'s 600 rows — a reminder that `fact_sales.customer_id`
includes the ~1% of intentionally orphaned IDs that don't resolve to
any real row in `dim_customer` at all, per the data dictionary.)

</details>

---

### 4. Reconcile an order-grain rollup against the known total

Aggregate `fact_sales` up to order grain (`SUM(net_amount)` per
`order_id`), then sum those order totals into one grand total. Does it
match the known total net sales figure for Oakhaven
(`project/docs/facts_sheet.md` reports `8742289.04`)?

<details>
<summary>Show solution</summary>

```sql
SELECT ROUND(SUM(order_total), 2) AS grand_total
FROM (
    SELECT order_id, SUM(net_amount) AS order_total
    FROM fact_sales
    GROUP BY order_id
);
```

| grand_total |
|---|
| 8742289.04 |

It matches exactly. This confirms an important property of a
correctly declared grain: aggregating *up* from the true grain
(order line) to any coarser grain (order) via `SUM`/`GROUP BY` is
always safe and never double-counts or loses money, because every
dollar lives in exactly one row at the true grain. This is exactly
what would break (double-counting, or silently wrong totals) if the
fact table secretly mixed grains — e.g., if it also included pre-
aggregated "order summary" rows alongside the line-level rows.

</details>

---

### 5. Find a case where the grain still holds, but *feels* surprising

Within a single order, can the same `product_id` appear on two
*different* lines? (This wouldn't violate the `(order_id,
order_line_id)` grain — it would just mean a customer ordered the same
product twice within one order, as two separate line entries.) Find
how often this happens.

<details>
<summary>Show solution</summary>

```sql
SELECT order_id, product_id, COUNT(*) AS n
FROM fact_sales
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
LIMIT 5;
```

| order_id | product_id | n |
|---|---|---|
| 90 | 74 | 2 |
| 209 | 137 | 2 |
| 270 | 9 | 2 |
| 663 | 95 | 2 |
| 716 | 21 | 2 |

```sql
SELECT COUNT(*) FROM (
    SELECT order_id, product_id
    FROM fact_sales
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
);
```

| COUNT(*) |
|---|
| 43 |

43 `(order_id, product_id)` combinations appear on more than one
line within the same order. This is perfectly consistent with the
declared grain — each occurrence is still a distinct, individually
identified `order_line_id` — but it's a good reminder that "grain" and
"uniqueness of every column combination you can think of" are
different concepts. The grain key (`order_id`, `order_line_id`) is
what's guaranteed unique; other column combinations (like
`customer_id, product_id`, or `order_id, product_id`) are not, and
were never claimed to be.

</details>
