# Exercises: 1. Why We Model Data: OLTP vs. Analytical Schemas

Work against `project/oakhaven.db`. Read-only — every query below is a
`SELECT`.

---

### 1. Spot the flattened header attributes

Pick order `7197` from `bronze_sales` and list all of its lines,
ordered by `order_line_id`. Which columns stay identical across every
line of the order (the "order-header" attributes), and which vary
per line (the "order-line" attributes)?

<details>
<summary>Show solution</summary>

```sql
SELECT order_id, order_line_id, product_id, quantity, unit_price,
       order_date, customer_id, payment_method
FROM bronze_sales
WHERE order_id = 7197
ORDER BY order_line_id;
```

| order_id | order_line_id | product_id | quantity | unit_price | order_date | customer_id | payment_method |
|---|---|---|---|---|---|---|---|
| 7197 | 1 | 7 | 2 | 420.99 | 05/07/2023 | 113 | Credit Card |
| 7197 | 2 | 81 | -2 | 180.68 | 05/07/2023 | 113 | Credit Card |
| 7197 | 3 | 91 | 1 | 439.0 | 05/07/2023 | 113 | Credit Card |

`order_date`, `customer_id`, and `payment_method` are identical across
all three lines — these are order-header attributes, generated once
per order. `product_id`, `quantity`, and `unit_price` vary per line —
these are order-line attributes. This is exactly the header/detail
split a normalized `orders` + `order_items` OLTP schema would enforce
structurally; here it's just flattened into one repeating table.
(Bonus observation: line 2 has `quantity = -2` — a return, per the
data dictionary's note that ~3% of `bronze_sales.quantity` values are
negative.)

</details>

---

### 2. `COUNT(*)` vs. the real number of orders

Using `fact_sales`, for the `Online` channel only, find both the
number of order *lines* and the number of distinct *orders*. Are they
the same number? Should they be?

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS lines, COUNT(DISTINCT order_id) AS orders
FROM fact_sales
WHERE channel = 'Online';
```

| lines | orders |
|---|---|
| 6040 | 3620 |

They're different — 6,040 order lines across only 3,620 distinct
orders — because `fact_sales` is at order-*line* grain, so some online
orders have more than one line. `COUNT(*)` always counts rows at the
fact table's grain; it is not automatically "count of orders" just
because the question was about orders.

</details>

---

### 3. One join, a real business number

Using `fact_sales` alone (no join needed — `channel` sits directly on
the fact table as a degenerate dimension), compute total net sales by
channel. Then explain in one sentence why this query would need more
than one join if Oakhaven's data were stored as a normalized
`orders` + `order_items` pair instead.

<details>
<summary>Show solution</summary>

```sql
SELECT channel, COUNT(*) AS lines, ROUND(SUM(net_amount), 2) AS total_net_amount
FROM fact_sales
GROUP BY channel
ORDER BY total_net_amount DESC;
```

| channel | lines | total_net_amount |
|---|---|---|
| In-Store | 5960 | 4380739.06 |
| Online | 6040 | 4361549.98 |

No join at all is needed here, because `channel` is a degenerate
dimension living directly on `fact_sales`. In a normalized OLTP
schema, `channel` would most likely live on an `orders` header table,
so summing `order_items.line_total` grouped by `orders.channel` would
require joining `order_items` → `orders` first — one join for a
question this simple, and more joins the moment you also want to
group by product category or customer segment.

</details>

---

### 4. Confirm bronze has no structural guarantees

Look up the actual `CREATE TABLE` statement SQLite stored for
`bronze_sales`. Does it declare a primary key, a foreign key, or any
`NOT NULL` constraint on `customer_id` or `product_id`? What does that
imply about who is responsible for catching bad `customer_id` /
`product_id` values?

<details>
<summary>Show solution</summary>

```sql
SELECT sql FROM sqlite_master WHERE name = 'bronze_sales';
```

```
CREATE TABLE bronze_sales (
    order_id        INTEGER,
    order_line_id   INTEGER,
    customer_id     INTEGER,
    product_id      INTEGER,
    employee_id     INTEGER,
    order_date      TEXT,
    ship_date       TEXT,
    quantity        INTEGER,
    unit_price      REAL,
    discount_pct    REAL,
    order_total     TEXT,
    payment_method  TEXT,
    order_status    TEXT,
    channel         TEXT
)
```

No `PRIMARY KEY`, no `FOREIGN KEY`, no `NOT NULL` anywhere — every
column is a bare type. Nothing at the database level stops
`customer_id` or `product_id` from referencing a row that doesn't
exist (and, per the data dictionary, ~1% of rows in this dataset do
exactly that, intentionally). Catching that is entirely the job of the
transformation layers built on top (`silver_sales.is_customer_orphan`
/ `is_product_orphan`, surfaced onward into `fact_sales`), not the
bronze table itself. This is realistic: raw source extracts are rarely
constrained, and validation is a warehouse responsibility, not
something you can assume the source system already did for you.

</details>

---

### 5. Naive average vs. correct average (a grain trap)

Compute the "average order value" two ways: (a) naively, as
`AVG(net_amount)` directly over `fact_sales`, and (b) correctly, by
first summing `net_amount` per order, then averaging those order
totals. Are they the same number? Why not?

<details>
<summary>Show solution</summary>

```sql
-- (a) naive: averages at LINE grain
SELECT ROUND(AVG(net_amount), 2) AS naive_avg_line_value
FROM fact_sales;
```

| naive_avg_line_value |
|---|
| 728.52 |

```sql
-- (b) correct: sum to ORDER grain first, then average
SELECT ROUND(AVG(order_total), 2) AS correct_avg_order_value
FROM (
    SELECT order_id, SUM(net_amount) AS order_total
    FROM fact_sales
    GROUP BY order_id
);
```

| correct_avg_order_value |
|---|
| 1214.38 |

They're substantially different — $728.52 vs. $1,214.38. `AVG(net_amount)`
over `fact_sales` computes the average *order line* value, not the
average *order* value, because `fact_sales`'s grain is one row per
line and most orders have more than one line. This is the same grain
trap as `COUNT(*)` (module 3, Example 2): any aggregate function
applied directly to a fact table answers a question at the fact
table's grain, and you have to explicitly re-aggregate to a coarser
grain (here, via a subquery `GROUP BY order_id`) if that's the question
you actually meant to ask.

</details>
