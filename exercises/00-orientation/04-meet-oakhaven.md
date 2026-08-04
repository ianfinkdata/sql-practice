# Exercises: Meet Oakhaven

Your first real queries — nothing fancy yet, just `SELECT *` and
`LIMIT` to get comfortable looking around. Run these against
`project/oakhaven.db`.

### 1. Look at employees

Write a query that shows the first 5 rows of `bronze_employees`.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM bronze_employees LIMIT 5;
```

| employee_id | first_name | last_name | department | region | hire_date | termination_date | is_manager | email |
|---|---|---|---|---|---|---|---|---|
| 1 | Alexa | garcia | Management | West | 04/09/2024 |  | N | alexa.garcia@oakhaven.com |
| 2 | sandra | Thompson | WAREHOUSE | NORTHEAST | 05/25/2018 |  | false | sandra.thompson@oakhaven.com |
| 3 | Alexandria | CUNNINGHAM | management | East | 2018-12-07 | 2021-05-01 06:37:09 | false | alexandria.cunningham@oakhaven.com |
| 4 | Laura | williams | Support | EAST | 2020-05-28 |  | 1 | laura.williams@oakhaven.com |
| 5 | stephanie | REID | Warehouse | CENTRAL | 2023-08-10 03:22:34 |  | y | (blank) |

Already you can spot the same messiness pattern as customers:
`department` and `region` cased inconsistently (`WAREHOUSE`,
`management`, `EAST`), `is_manager` spelled multiple ways (`N`,
`false`, `1`, `y`), and employee 5's `email` is blank.

</details>

### 2. Look at products, fewer columns worth of rows

Write a query that shows the first 3 rows of `bronze_products`.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM bronze_products LIMIT 3;
```

| product_id | product_name | category | subcategory | brand | unit_cost | unit_price | is_discontinued | sku | weight_kg | created_at |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Canyon Hiking Boots | footwear | Hiking Boots | Stonepine Gear | 269.63 | 649.26 | true | FOO-0001 | 24.7 kg | 2019-12-09 |
| 2 | Ridge Jackets | APPAREL | Jackets | Northfell | 231.98 | 348.55 | false | APP-0002 | 5.3 | 2024-01-30 06:07:49 |
| 3 | Trailhead Trekking Pole | CAMPING & HIKING | Trekking Poles | Kestrel Outdoor | 136.25 | 286.86 | n | CAM-0003 | 3.43 kg | 2022-01-18 09:54:16 |

Notice `category` casing varies even within these 3 rows (`footwear`
lowercase, `APPAREL` all-caps), and `weight_kg` mixes `"24.7 kg"` (with
units as text) and `"5.3"` (no units) — that's the "dirty TEXT, not a
clean number" behavior mentioned in the data dictionary.

</details>

### 3. Count something

Write a query that counts how many rows are in `bronze_employees`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS employee_count FROM bronze_employees;
```

| employee_count |
|---|
| 35 |

</details>

### 4. The non-messy table

`bronze_calendar` is the one bronze table that *isn't* messy — it's a
manufactured date spine. Confirm that for yourself: look at its first
3 rows.

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM bronze_calendar LIMIT 3;
```

| datekey | date |
|---|---|
| 20180101 | 2018-01-01 |
| 20180102 | 2018-01-02 |
| 20180103 | 2018-01-03 |

Clean, sequential, one row per day — no casing quirks, no missing
values. You'll come back to this table much later when doing
date-based reporting.

</details>

### 5. Put it together

Without running it first, guess what this query returns, then run it
to check:

```sql
SELECT * FROM bronze_sales LIMIT 2;
```

What's the relationship between `order_id` and `order_line_id` for
these two rows — are they the same order or different orders?

<details>
<summary>Show solution</summary>

```sql
SELECT * FROM bronze_sales LIMIT 2;
```

| order_id | order_line_id | customer_id | product_id | employee_id | order_date | ship_date | quantity | unit_price | discount_pct | order_total | payment_method | order_status | channel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 23 | 3 | 32 | 2024-03-05 21:30:50 | 2024-03-15 18:14:26 | 4 | 306.83 | 0.3 | 859.12 | Credit Card | Completed | online |
| 1 | 2 | 23 | 38 | 32 | 2024-03-05 21:30:50 | 2024-03-15 18:14:26 | 5 | 241.65 | 0.2 | 966.60 | Credit Card | Completed | online |

Both rows share `order_id = 1` but have different `order_line_id`
values (1 and 2) — this is the same order (same customer, same
order_date), with two different products (`product_id` 3 and 38) as
separate line items. This is the "one row per order line" grain
mentioned in the curriculum module.

</details>
