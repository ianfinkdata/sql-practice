# Exercises: Correlated Subqueries, EXISTS, and NOT EXISTS

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Products priced below their category average

Using a correlated subquery, find products whose `unit_price` is *below*
their own category's average price (the mirror image of the curriculum's
worked example, which found products *above* average). Show 6 rows.

<details>
<summary>Show solution</summary>

```sql
SELECT p.product_id, p.product_name, p.category, p.unit_price
FROM dim_product p
WHERE p.unit_price < (
    SELECT AVG(p2.unit_price) FROM dim_product p2 WHERE p2.category = p.category
)
ORDER BY p.category, p.unit_price
LIMIT 6;
```

Verified output:

| product_id | product_name | category | unit_price |
|---|---|---|---|
| 122 | Canyon Hats | Accessories | 21.03 |
| 31 | Cascade Water Bottle | Accessories | 47.99 |
| 124 | Trailhead Hats | Accessories | 67.00 |
| 128 | Granite Headlamps | Accessories | 122.88 |
| 22 | Northbound Headlamps | Accessories | 123.99 |
| 76 | Wayfinder Multi-Tools | Accessories | 145.45 |

</details>

---

### 2. Customers who never bought In-Store

Using `EXISTS`/`NOT EXISTS`, find customers who have placed at least one
order, but never through the `In-Store` channel.

<details>
<summary>Show solution</summary>

```sql
SELECT c.customer_id, c.full_name
FROM dim_customer c
WHERE EXISTS (SELECT 1 FROM fact_sales f WHERE f.customer_id = c.customer_id)
  AND NOT EXISTS (
      SELECT 1 FROM fact_sales f WHERE f.customer_id = c.customer_id AND f.channel = 'In-Store'
  )
ORDER BY c.customer_id;
```

Verified output — exactly **1** customer out of 600:

| customer_id | full_name |
|---|---|
| 235 | Veronica Singleton |

</details>

---

### 3. Every employee has processed a Cancelled order — confirm it

Using `EXISTS`, count how many of Oakhaven's 35 employees have processed
at least one order line with `order_status = 'Cancelled'`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM dim_employee e
WHERE EXISTS (
    SELECT 1 FROM fact_sales f WHERE f.employee_id = e.employee_id AND f.order_status = 'Cancelled'
);
```

Verified output: **35** — every single employee has at least one
`Cancelled` order line on record. With 35 employees, 12,000 order lines,
and cancellations spread fairly evenly (`order_status` has no
employee-specific skew built into the data generator), this isn't
surprising — but it's worth confirming with a query rather than assuming.

</details>

---

### 4. Reproduce the NOT IN / NULL trap yourself

Using the minimal `VALUES`-based reproduction from the curriculum lesson
(`ids` = `{1, 2, 3}`, `excluded` = `{2, NULL}`), write both the broken
`NOT IN` version and the correct `NOT EXISTS` version, and confirm their
outputs differ.

<details>
<summary>Show solution</summary>

```sql
-- broken: NOT IN, subquery result list contains a NULL
WITH ids(id) AS (VALUES (1), (2), (3)),
     excluded(id) AS (VALUES (2), (NULL))
SELECT id FROM ids WHERE id NOT IN (SELECT id FROM excluded);
```

Verified output: **zero rows** (incorrect — should be `{1, 3}`).

```sql
-- correct: NOT EXISTS, immune to the NULL trap
WITH ids(id) AS (VALUES (1), (2), (3)),
     excluded(id) AS (VALUES (2), (NULL))
SELECT id FROM ids i WHERE NOT EXISTS (SELECT 1 FROM excluded e WHERE e.id = i.id);
```

Verified output: `{1, 3}` (correct).

</details>

---

### 5. Find the real latent risk in Oakhaven

`fact_sales.employee_id` is `NULL` for 1,243 rows (online/no-rep sales).
Write a query that demonstrates the risk this creates: use `NOT IN`
(against the raw, un-filtered `employee_id` column from `fact_sales`) to
try to find employees with zero sales, then rewrite it as `NOT EXISTS`.
Confirm both currently return the same (empty) result — then explain, in
a sentence, why the `NOT IN` version is still a latent bug even though its
current output happens to be correct.

<details>
<summary>Show solution</summary>

```sql
-- NOT IN version (dangerous — employee_id has 1,243 NULLs in fact_sales)
SELECT e.employee_id, e.full_name
FROM dim_employee e
WHERE e.employee_id NOT IN (SELECT employee_id FROM fact_sales);

-- NOT EXISTS version (safe)
SELECT e.employee_id, e.full_name
FROM dim_employee e
WHERE NOT EXISTS (SELECT 1 FROM fact_sales f WHERE f.employee_id = e.employee_id);
```

Verified output: both return **zero rows** currently, because every one
of Oakhaven's 35 employees has at least one sale.

That agreement is coincidental, not a guarantee: the `NOT IN` version's
subquery (`SELECT employee_id FROM fact_sales`) includes 1,243 `NULL`
values in its result list, which poisons every `NOT IN` comparison to
`UNKNOWN` regardless of whether a real, non-`NULL` match exists. If a new
employee were added who genuinely had zero sales, the `NOT IN` query would
*still* silently report zero rows — hiding that employee — while the
`NOT EXISTS` version would correctly surface them. The bug is dormant
today only because the current data happens not to trigger it.

</details>
