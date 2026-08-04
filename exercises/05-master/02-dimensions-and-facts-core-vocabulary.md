# Exercises: 2. Dimensions and Facts: Core Vocabulary

Work against `project/oakhaven.db`. Read-only — every query below is a
`SELECT`.

---

### 1. Classify `dim_employee`'s columns

List `dim_employee`'s columns and classify each one as: the natural
key, or an attribute.

<details>
<summary>Show solution</summary>

```sql
PRAGMA table_info(dim_employee);
```

| column | role |
|---|---|
| `employee_id` | natural key (join target for `fact_sales.employee_id`) |
| `first_name`, `last_name`, `full_name` | attributes |
| `department`, `region` | attributes |
| `hire_date`, `termination_date` | attributes (and — as module 5 covers — a naturally SCD-Type-2-shaped pair) |
| `is_manager` | attribute (boolean-style flag) |
| `email` | attribute |

There are no measures here at all — `dim_employee` is a pure
dimension. Nothing on it is meant to be summed; every column exists to
describe, filter, or group by an employee.

</details>

---

### 2. A measure built by combining a fact measure with a dimension attribute

`fact_sales.net_amount` is revenue. `dim_product.unit_cost` is the
product's cost, which lives on the dimension (it describes the
product, not a specific sale). Compute **gross margin** (revenue minus
cost) by category, for the top 5 categories by margin. This requires
combining a fact measure (`net_amount`, plus `quantity` to scale the
per-unit cost) with a dimension attribute (`unit_cost`) via a join.

<details>
<summary>Show solution</summary>

```sql
SELECT p.category,
       ROUND(SUM(f.net_amount), 2) AS total_revenue,
       ROUND(SUM(f.quantity * p.unit_cost), 2) AS total_cost,
       ROUND(SUM(f.net_amount) - SUM(f.quantity * p.unit_cost), 2) AS gross_margin
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
WHERE p.unit_cost IS NOT NULL
GROUP BY p.category
ORDER BY gross_margin DESC
LIMIT 5;
```

| category | total_revenue | total_cost | gross_margin |
|---|---|---|---|
| Climbing | 1389650.95 | 783500.86 | 606150.09 |
| Winter Sports | 1227987.61 | 698400.13 | 529587.48 |
| Nutrition & Hydration | 1164289.69 | 719385.17 | 444904.52 |
| Apparel | 1146455.86 | 717276.4 | 429179.46 |
| Footwear | 1052643.36 | 645169.6 | 407473.76 |

The `WHERE p.unit_cost IS NOT NULL` matters: `dim_product.unit_cost`
is ~3% `NULL` and ~1% negative per the data dictionary — a real
dimension attribute with its own messiness, which is exactly why you
join to it rather than trusting every fact row has a clean cost
automatically.

</details>

---

### 3. Prove `unit_price` isn't a safe measure to sum directly

`fact_sales.unit_price` is numeric and lives on the fact table — does
that make it a safe measure? Compare `SUM(unit_price)` across all rows
to the real total revenue (`SUM(net_amount)`), and explain the gap.

<details>
<summary>Show solution</summary>

```sql
SELECT ROUND(SUM(unit_price), 2) AS nonsense_sum_unit_price,
       ROUND(SUM(net_amount), 2) AS real_total_revenue
FROM fact_sales;
```

| nonsense_sum_unit_price | real_total_revenue |
|---|---|
| 3584232.51 | 8742289.04 |

Wildly different, and `SUM(unit_price)` isn't meaningful at all: it
adds together per-unit prices without accounting for `quantity` (an
order of 5 units and an order of 1 unit contribute the same amount to
this sum) or `discount_pct`. `unit_price` is an *input* to the real
measure, not a measure itself — `net_amount` (already computed as
`quantity * unit_price * (1 - discount_pct)` in `silver_sales`) is the
column actually safe to `SUM`. This is the same lesson as
`discount_pct` in the lesson text, applied to a different column:
"numeric and on the fact table" is not sufficient to make something a
measure.

</details>

---

### 4. Is `sku` a usable natural key for `dim_product`?

Check whether `sku` uniquely identifies a product in `dim_product`.
(Hint: `sku_is_duplicate` already flags this.)

<details>
<summary>Show solution</summary>

```sql
SELECT sku_is_duplicate, COUNT(*) FROM dim_product GROUP BY sku_is_duplicate;
```

| sku_is_duplicate | COUNT(*) |
|---|---|
| 0 | 146 |
| 1 | 4 |

```sql
SELECT product_id, sku, sku_is_duplicate
FROM dim_product
WHERE sku_is_duplicate = 1
ORDER BY sku;
```

| product_id | sku | sku_is_duplicate |
|---|---|---|
| 85 | WAT-0095 | 1 |
| 95 | WAT-0095 | 1 |
| 129 | WIN-0129 | 1 |
| 144 | WIN-0129 | 1 |

`sku` is **not** a reliable natural key: 4 of 150 products (2 pairs)
share a duplicated SKU value with a completely different product.
`product_id` is the trustworthy natural key here; `sku` is just
another attribute (a real-world catalog code, prone to the exact kind
of data-entry collisions catalog codes have in practice).

</details>

---

### 5. Find the degenerate dimensions and reason about when they'd need to become real ones

List the distinct values of `fact_sales.channel` and
`fact_sales.payment_method` — two attributes with no dedicated
dimension table of their own. What would have to be true about these
columns before it made sense to break them out into `dim_channel` /
`dim_payment_method` tables?

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT channel FROM fact_sales;
```

| channel |
|---|
| Online |
| In-Store |

```sql
SELECT DISTINCT payment_method FROM fact_sales ORDER BY payment_method;
```

| payment_method |
|---|
| Cash |
| Credit Card |
| Debit Card |
| Gift Card |
| PayPal |

Both are small, closed sets of plain text values with nothing further
to describe about each value — there's no "channel manager," "channel
launch date," or "payment processor fee rate" attribute waiting to be
attached. That's exactly when a degenerate dimension (an attribute
living directly on the fact row) is the right call: it avoids an
unnecessary tiny lookup table for a 2- or 5-value set.

It would be worth promoting one of these to a real dimension the
moment you needed to attach *more attributes* to the value itself —
for example, if `payment_method` needed a `processing_fee_pct` or
`is_digital` attribute, or if `channel` needed a `channel_owner` or
`launch_date`. At that point, "channel"/"payment_method" stop being
just labels and become entities worth describing in their own right,
which is the signal to give them a dimension table.

</details>
