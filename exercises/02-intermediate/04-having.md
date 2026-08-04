# Exercises: HAVING

<!-- nav -->
Curriculum: [HAVING](../../curriculum/02-intermediate/04-having.md). Previous: [GROUP BY](03-group-by.md). Next: [CASE Expressions](05-case-expressions.md).
<!-- /nav -->

Use `project/oakhaven.db`. Every solution below was run against the
real database — your output should match exactly.

---

**1. Payment methods with more than 1,200 order lines**

<details>
<summary>Show solution</summary>

```sql
SELECT payment_method, COUNT(*) AS n
FROM bronze_sales
GROUP BY payment_method
HAVING COUNT(*) > 1200
ORDER BY n DESC;
```

| payment_method | n |
|---|---|
| CC | 1265 |
| Debit Card | 1233 |
| cash  | 1232 |
| Gift Card | 1232 |
| paypal | 1208 |

</details>

---

**2. The one product with more than 100 order lines**

Group `bronze_sales` by `product_id` and find any product with more
than 100 order lines.

<details>
<summary>Show solution</summary>

```sql
SELECT product_id, COUNT(*) AS n
FROM bronze_sales
GROUP BY product_id
HAVING COUNT(*) > 100
ORDER BY n DESC;
```

| product_id | n |
|---|---|
| 101 | 104 |

Only one product clears 100 lines — `HAVING` doesn't require multiple
matches to be useful; sometimes the answer to "who clears this bar"
is a single row, and that's a fine result too.

</details>

---

**3. Employees with more than 250 sales lines attributed to them**

Group `bronze_sales` by `employee_id` (excluding `NULL`, since that
represents no-rep online sales, not a real employee) and find everyone
above 250 lines.

<details>
<summary>Show solution</summary>

```sql
SELECT employee_id, COUNT(*) AS n
FROM bronze_sales
WHERE employee_id IS NOT NULL
GROUP BY employee_id
HAVING COUNT(*) > 250
ORDER BY n DESC;
```

| employee_id | n |
|---|---|
| 2 | 365 |
| 12 | 354 |
| 22 | 353 |
| 29 | 338 |
| 4 | 336 |
| 28 | 331 |
| 5 | 327 |
| 34 | 325 |
| 24 | 321 |
| 18 | 317 |

10 of the 35 employees clear 250 lines each — `WHERE employee_id IS
NOT NULL` filters rows before grouping (removing the ~1,243 no-rep
sales), `HAVING COUNT(*) > 250` filters groups after.

</details>

---

**4. Brands whose average product price exceeds $400**

<details>
<summary>Show solution</summary>

```sql
SELECT brand, ROUND(AVG(unit_price), 2) AS avg_price, COUNT(*) AS n
FROM bronze_products
GROUP BY brand
HAVING AVG(unit_price) > 400
ORDER BY avg_price DESC;
```

| brand | avg_price | n |
|---|---|---|
| Pinepack | 467.02 | 5 |
| Stonepine Gear | 429.75 | 5 |

Only two brands clear that bar, out of the ~25 in the pool — a
reminder that `HAVING` conditions can be as selective as you need.

</details>

---

**5. Raw state spellings with 6 or more customers**

Exclude `NULL` and empty-string states first (`WHERE`), then group and
filter for spellings with at least 6 customers.

<details>
<summary>Show solution</summary>

```sql
SELECT state, COUNT(*) AS n
FROM bronze_customers
WHERE state IS NOT NULL AND state != ''
GROUP BY state
HAVING COUNT(*) >= 6
ORDER BY n DESC
LIMIT 10;
```

| state | n |
|---|---|
| de | 9 |
| Rhode Island | 8 |
| oklahoma | 7 |
| VA | 7 |
| New York | 7 |
| virginia | 6 |
| tennessee | 6 |
| sc | 6 |
| ny | 6 |
| nc | 6 |

`state` has 190 distinct raw spellings across only 600 customers —
most groups have just 1 or 2 rows. Very few clear even a low bar like
6, which itself tells you something about how thin this column is
sliced by messiness alone.

</details>

---

**6. WHERE + GROUP BY + HAVING together: online-channel categories over 200 lines**

Restrict to online sales (`channel` in `('Online', 'online')`) first,
then find raw `category` spellings with more than 200 order lines
within that filtered set.

<details>
<summary>Show solution</summary>

```sql
SELECT p.category, COUNT(*) AS n
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE s.channel IN ('Online', 'online')
GROUP BY p.category
HAVING COUNT(*) > 200
ORDER BY n DESC;
```

| category | n |
|---|---|
| Winter Sports | 424 |
| Apparel | 373 |
| Climbing | 370 |
| Accessories | 330 |
| climbing | 297 |
| WINTER SPORTS | 278 |
| Water Sports | 265 |
| Nutrition & Hydration | 232 |
| FOOTWEAR | 214 |
| Camping & Hiking | 201 |

All three clauses working together: `WHERE` drops non-online rows
before anything is grouped, `GROUP BY` collapses to one row per raw
category spelling, `HAVING` keeps only the spellings with meaningful
volume. Notice `Climbing` and `climbing` both appear as separate rows
here — a live reminder that `HAVING` operates on whatever `GROUP BY`
handed it, messy spellings and all.

</details>

---

---

<!-- nav -->
Curriculum: [HAVING](../../curriculum/02-intermediate/04-having.md). Previous: [GROUP BY](03-group-by.md). Next: [CASE Expressions](05-case-expressions.md).
<!-- /nav -->
