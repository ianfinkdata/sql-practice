# Tier 2 — Intermediate Exercises

> Now you summarize and combine. Aggregates, `GROUP BY`/`HAVING`, joins (inner,
> left, and trickier ones), set operations, subqueries, `CASE`, and handling
> `NULL` gracefully.

Uses the [shared dataset](README.md#the-shared-dataset). Write your query first,
then expand the solution.

← Back to [Exercises](README.md) · matching curriculum: [`02-intermediate`](../curriculum/02-intermediate/)

---

## 1. A single aggregate

What is the total revenue across all sales?

<details><summary>Show solution</summary>

```sql
SELECT SUM(amount) AS total_revenue
FROM sales;
```

`SUM` collapses every row's `amount` into one total; `AS` names the output
column.

</details>

---

## 2. Several aggregates at once

For all sales, report the count, the average amount, the smallest, and the
largest.

<details><summary>Show solution</summary>

```sql
SELECT COUNT(*)    AS num_sales,
       AVG(amount) AS avg_amount,
       MIN(amount) AS min_amount,
       MAX(amount) AS max_amount
FROM sales;
```

Multiple aggregate functions can share one `SELECT`; each one summarizes the
whole table.

</details>

---

## 3. GROUP BY

Show total revenue per customer (`customer_id`).

<details><summary>Show solution</summary>

```sql
SELECT customer_id,
       SUM(amount) AS total_revenue
FROM sales
GROUP BY customer_id;
```

`GROUP BY` splits rows into buckets by `customer_id`; the aggregate runs once per
bucket.

</details>

---

## 4. GROUP BY + ORDER BY

List each region and how many customers it has, busiest region first.

<details><summary>Show solution</summary>

```sql
SELECT region,
       COUNT(*) AS num_customers
FROM customers
GROUP BY region
ORDER BY num_customers DESC;
```

You can sort by an aggregated column; ordering happens *after* grouping.

</details>

---

## 5. HAVING

Show only the customers whose total revenue exceeds 5000.

<details><summary>Show solution</summary>

```sql
SELECT customer_id,
       SUM(amount) AS total_revenue
FROM sales
GROUP BY customer_id
HAVING SUM(amount) > 5000;
```

`WHERE` filters individual rows *before* grouping; `HAVING` filters *groups*
after the aggregate is computed.

</details>

---

## 6. INNER JOIN

List each sale's `sale_id`, `amount`, and the customer's `customer_name`.

<details><summary>Show solution</summary>

```sql
SELECT s.sale_id,
       s.amount,
       c.customer_name
FROM sales AS s
INNER JOIN customers AS c
  ON s.customer_id = c.customer_id;
```

`INNER JOIN` keeps only rows that match on both sides — sales with a valid
customer.

</details>

---

## 7. LEFT JOIN to find non-matches

List every customer and their total revenue, **including customers who have
never bought anything** (show them as 0).

<details><summary>Show solution</summary>

```sql
SELECT c.customer_name,
       COALESCE(SUM(s.amount), 0) AS total_revenue
FROM customers AS c
LEFT JOIN sales AS s
  ON c.customer_id = s.customer_id
GROUP BY c.customer_name;
```

`LEFT JOIN` keeps all customers even when no sale matches; `COALESCE` turns the
resulting `NULL` sum into 0.

</details>

---

## 8. A three-table join

Show `sale_id`, `customer_name`, and `rep_name` for every sale that has both a
customer and a rep.

<details><summary>Show solution</summary>

```sql
SELECT s.sale_id,
       c.customer_name,
       r.rep_name
FROM sales AS s
INNER JOIN customers AS c ON s.customer_id = c.customer_id
INNER JOIN sales_rep AS r ON s.rep_id     = r.rep_id;
```

Joins chain: each `JOIN ... ON` adds another table by matching a key.

</details>

---

## 9. Set operations (UNION)

Build one list of regions that appear in `customers` *combined with* a hard-coded
target list `'East'` and `'South'`, with no duplicates. (Use `UNION` against a
literal set.)

<details><summary>Show solution</summary>

```sql
SELECT region FROM customers
UNION
SELECT 'East'
UNION
SELECT 'South';
```

`UNION` stacks result sets and removes duplicates (use `UNION ALL` to keep
them). Each `SELECT` must have the same number/type of columns.

</details>

---

## 10. Subquery in WHERE

Find customers who have at least one sale over 2000. (Use a subquery, no join.)

<details><summary>Show solution</summary>

```sql
SELECT customer_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM sales
    WHERE amount > 2000
);
```

The inner query produces a list of qualifying `customer_id`s; the outer `IN`
keeps customers whose id is in that list.

</details>

---

## 11. CASE for bucketing

Label each sale as `'small'` (< 500), `'medium'` (500–1999), or `'large'`
(≥ 2000), alongside its amount.

<details><summary>Show solution</summary>

```sql
SELECT sale_id,
       amount,
       CASE
           WHEN amount < 500  THEN 'small'
           WHEN amount < 2000 THEN 'medium'
           ELSE 'large'
       END AS size_bucket
FROM sales;
```

`CASE` walks its `WHEN`s top to bottom and returns the first match; `ELSE`
catches everything else.

</details>

---

## 12. NULL handling + correlated subquery

For every customer, show their name and their **most recent sale date**. If they
have no sales, show the text `'never'` instead of `NULL`.

<details><summary>Show solution</summary>

```sql
SELECT c.customer_name,
       COALESCE(
           CAST((SELECT MAX(s.sale_date)
                 FROM sales AS s
                 WHERE s.customer_id = c.customer_id) AS VARCHAR),
           'never'
       ) AS last_sale
FROM customers AS c;
```

The correlated subquery runs per customer (`s.customer_id = c.customer_id`);
`COALESCE` swaps a `NULL` (no sales) for `'never'`. Casting lets the date and the
text share one column.

</details>

---

Next up: [Tier 3 — Advanced](tier-3-advanced.md) →
