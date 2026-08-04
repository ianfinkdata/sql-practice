# Exercises: GROUP BY

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Order lines and rough revenue per raw `payment_method`**

Group `bronze_sales` by `payment_method` and return the count of rows
and the rough total (`quantity * unit_price`, rounded to 2 decimals)
for each, sorted by count descending.

<details>
<summary>Show solution</summary>

```sql
SELECT payment_method, COUNT(*) AS n,
       ROUND(SUM(quantity * unit_price), 2) AS rough_total
FROM bronze_sales
GROUP BY payment_method
ORDER BY n DESC;
```

| payment_method | n | rough_total |
|---|---|---|
| CC | 1265 | 1039585.67 |
| Debit Card | 1233 | 1028691.86 |
| cash  | 1232 | 1035060.17 |
| Gift Card | 1232 | 948907.59 |
| paypal | 1208 | 1015870.61 |
| debit card | 1193 | 981792.21 |
| PayPal | 1193 | 974114.56 |
| Credit Card | 1157 | 975831.67 |
| credit card | 1146 | 933744.88 |
| Cash | 1141 | 946557.96 |

10 raw groups for what's really 5 payment methods (`Credit Card`,
`Cash`, `Debit Card`, `Gift Card`, `PayPal`) — the same messy-column
pattern as `category`, just on a different column this time.

</details>

---

**2. Average quantity per `order_status`**

<details>
<summary>Show solution</summary>

```sql
SELECT order_status, COUNT(*) AS n, ROUND(AVG(quantity), 2) AS avg_qty
FROM bronze_sales
GROUP BY order_status
ORDER BY n DESC;
```

| order_status | n | avg_qty |
|---|---|---|
| Completed | 5304 | 2.77 |
| completed | 1804 | 2.78 |
| Returned | 1736 | 2.84 |
| *(NULL)* | 1240 | 2.77 |
| Cancelled | 1031 | 2.79 |
| CANCELLED | 885 | 2.87 |

Note the blank/NULL row: `GROUP BY` treats `NULL` as its own group
(it doesn't get dropped or error), which is worth knowing before you
assume a grouped report accounts for 100% of rows just because the
numbers "look complete."

</details>

---

**3. Customers per raw `customer_segment`**

<details>
<summary>Show solution</summary>

```sql
SELECT customer_segment, COUNT(*) AS n
FROM bronze_customers
GROUP BY customer_segment
ORDER BY n DESC;
```

| customer_segment | n |
|---|---|
| VIP | 110 |
| Wholesale | 95 |
| Retail | 95 |
| WHOLESALE | 67 |
| vip | 58 |
| wholesale | 44 |
| retail | 41 |
| Vip | 39 |
| RETAIL | 37 |
| *(blank)* | 14 |

10 groups for 3 real segments (VIP, Retail, Wholesale) plus a blank
group for the ~3% documented as NULL/empty in the data dictionary.

</details>

---

**4. Two-column GROUP BY: employee count per department + region combination**

Group `bronze_employees` by both `department` and `region` together,
and return the first 10 rows ordered by `department`, then `region`.

<details>
<summary>Show solution</summary>

```sql
SELECT department, region, COUNT(*) AS n
FROM bronze_employees
GROUP BY department, region
ORDER BY department, region
LIMIT 10;
```

| department | region | n |
|---|---|---|
| MANAGEMENT | Northeast | 1 |
| MANAGEMENT | West | 1 |
| MANAGEMENT | central | 1 |
| MANAGEMENT | west | 1 |
| Management | Central | 1 |
| Management | SOUTH | 1 |
| Management | South | 1 |
| Management | West | 2 |
| Management | east | 1 |
| Management | west | 1 |

Grouping by two columns produces one row per unique *combination* —
with only 35 employees split across ~11 raw department spellings and
~14 raw region spellings, most combinations end up with just 1 or 2
people. Small groups like this are exactly why Module 4's `HAVING`
exists — to filter down to only the combinations worth looking at.

</details>

---

**5. Top 5 brands by product count, with their price range**

Group `bronze_products` by `brand`, returning count of products,
minimum `unit_price`, and maximum `unit_price` — top 5 by product
count.

<details>
<summary>Show solution</summary>

```sql
SELECT brand, COUNT(*) AS n, MIN(unit_price) AS min_price, MAX(unit_price) AS max_price
FROM bronze_products
GROUP BY brand
ORDER BY n DESC
LIMIT 5;
```

| brand | n | min_price | max_price |
|---|---|---|---|
| Elkstone | 10 | 23.52 | 518.48 |
| Northfell | 9 | 47.09 | 645.99 |
| Marrowpeak | 9 | 123.99 | 426.17 |
| Ironwood Trail Co. | 9 | 67.0 | 505.09 |
| Highmark Supply Co. | 9 | 22.65 | 553.01 |

`brand` is a clean column (no casing/whitespace mess like `category`
or `payment_method`) — this is what a "well-behaved" `GROUP BY` looks
like, for contrast.

</details>

---

**6. Which raw category spellings does each channel favor?**

Group `bronze_sales` joined to `bronze_products` by both `channel` and
`category`, restricted to the three raw spellings of "Climbing"
(`'Climbing'`, `'CLIMBING'`, `'climbing'`), returning line counts.
Order by `channel`, then `category`.

<details>
<summary>Show solution</summary>

```sql
SELECT s.channel, p.category, COUNT(*) AS n
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.category IN ('Climbing', 'CLIMBING', 'climbing')
GROUP BY s.channel, p.category
ORDER BY s.channel, p.category;
```

| channel | category | n |
|---|---|---|
| In-Store | CLIMBING | 79 |
| In-Store | Climbing | 198 |
| In-Store | climbing | 123 |
| Online | CLIMBING | 73 |
| Online | Climbing | 180 |
| Online | climbing | 150 |
| in store | CLIMBING | 74 |
| in store | Climbing | 149 |
| in store | climbing | 137 |
| online | CLIMBING | 91 |
| online | Climbing | 190 |
| online | climbing | 147 |

4 raw `channel` spellings times 3 raw `Climbing` spellings gives
exactly the 12 rows predicted — a direct, hands-on look at how
uncleaned text on *both* sides of a join multiplies the number of
groups in your result, well past what the underlying real-world
question ("channel by category") actually has to offer.

</details>

---
