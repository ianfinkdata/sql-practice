# Tier 1 — Beginner Exercises

> Getting answers *out* of a database. By the end you can pick columns, filter
> rows, sort and limit results, remove duplicates, and combine simple
> conditions.

Uses the [shared dataset](README.md#the-shared-dataset): `customers`, `sales`,
`sales_rep`, `products`. Write your query first, then expand the solution to
check.

← Back to [Exercises](README.md) · matching curriculum: [`01-beginner`](../curriculum/01-beginner/)

---

## 1. Select everything

List every column for every customer.

<details><summary>Show solution</summary>

```sql
SELECT *
FROM customers;
```

`SELECT *` grabs all columns; with no `WHERE`, every row comes back.

</details>

---

## 2. Pick specific columns

Show just the name and region of each customer (skip the rest).

<details><summary>Show solution</summary>

```sql
SELECT customer_name, region
FROM customers;
```

Listing columns explicitly is clearer and faster than `SELECT *` when you only
need a few.

</details>

---

## 3. Filter with WHERE

Show all sales where the `amount` was greater than 1000.

<details><summary>Show solution</summary>

```sql
SELECT *
FROM sales
WHERE amount > 1000;
```

`WHERE` keeps only the rows whose condition is true.

</details>

---

## 4. Sort the results

List all products from most expensive to least expensive.

<details><summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM products
ORDER BY unit_price DESC;
```

`ORDER BY ... DESC` sorts high-to-low; the default is `ASC` (low-to-high).

</details>

---

## 5. Top N with LIMIT

Show the 5 largest sales by amount.

<details><summary>Show solution</summary>

```sql
SELECT sale_id, customer_id, amount
FROM sales
ORDER BY amount DESC
LIMIT 5;
```

Sort first, then `LIMIT` cuts the result to the top 5 rows. (Oracle/SQL Server
spell this `FETCH FIRST 5 ROWS ONLY` / `TOP 5` — see the Dialect Decoder.)

</details>

---

## 6. DISTINCT values

What distinct regions do our customers come from? (No duplicates.)

<details><summary>Show solution</summary>

```sql
SELECT DISTINCT region
FROM customers;
```

`DISTINCT` collapses repeated values so each region appears once.

</details>

---

## 7. BETWEEN a range

List sales with an `amount` between 500 and 1500 (inclusive).

<details><summary>Show solution</summary>

```sql
SELECT sale_id, amount
FROM sales
WHERE amount BETWEEN 500 AND 1500;
```

`BETWEEN a AND b` is inclusive of both ends — equivalent to `amount >= 500 AND
amount <= 1500`.

</details>

---

## 8. IN a list, AND combining conditions

Find customers in the `'North'` or `'West'` region who signed up on or after
2024-01-01.

<details><summary>Show solution</summary>

```sql
SELECT customer_name, region, signup_date
FROM customers
WHERE region IN ('North', 'West')
  AND signup_date >= DATE '2024-01-01';
```

`IN (...)` is a tidy shorthand for several `OR` checks on one column; `AND`
requires *both* sides to be true.

</details>

---

## 9. Pattern matching with LIKE

Find every customer whose email is on `gmail.com`.

<details><summary>Show solution</summary>

```sql
SELECT customer_name, email
FROM customers
WHERE email LIKE '%@gmail.com';
```

`%` matches any run of characters, so `%@gmail.com` matches anything ending in
`@gmail.com`.

</details>

---

## 10. Finding the missing data with IS NULL

Some sales were never credited to a rep. Find sales that have no `rep_id`, and
sort them by date (newest first).

<details><summary>Show solution</summary>

```sql
SELECT sale_id, sale_date, amount
FROM sales
WHERE rep_id IS NULL
ORDER BY sale_date DESC;
```

You must test for missing values with `IS NULL` — `rep_id = NULL` never returns
true, because `NULL` means "unknown."

</details>

---

Next up: [Tier 2 — Intermediate](tier-2-intermediate.md) →
