# Exercises: Query Optimization Basics

`EXPLAIN QUERY PLAN` alone is read-only. Any exercise creating an
index must run against your own scratch copy:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Spot the sargable predicate

Without running anything yet, look at these four `WHERE` clauses and
predict which are sargable (could use a plain index on the named
column) and which aren't:

```sql
-- (a)
WHERE customer_id = 41
-- (b)
WHERE UPPER(state) = 'CA'
-- (c)
WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01'
-- (d)
WHERE quantity * 2 > 10
```

<details>
<summary>Show solution</summary>

- (a) **Sargable.** Direct equality on the raw column value.
- (b) **Not sargable.** `UPPER()` wraps the column — an index on
  `state` stores raw values, not uppercased ones.
- (c) **Sargable.** A range condition on the raw column, expressible
  directly against a sorted index.
- (d) **Not sargable.** `quantity * 2` wraps the column in arithmetic
  — an index on `quantity` can't be searched for `quantity * 2 > 10`
  directly. Rewritten as `WHERE quantity > 5`, it would be sargable.

Verify (b) and (d) empirically in Exercises 2 and 5 below.

</details>

---

### 2. Prove a function wrapper defeats an index

On your scratch copy, create an index on `bronze_customers(email)`.
Check `EXPLAIN QUERY PLAN` for `WHERE email = 'test@example.com'`
first, then for `WHERE LOWER(email) = 'test@example.com'`.

<details>
<summary>Show solution</summary>

```sql
CREATE INDEX idx_customers_email ON bronze_customers(email);

EXPLAIN QUERY PLAN SELECT * FROM bronze_customers WHERE email = 'test@example.com';
```

```
QUERY PLAN
`--SEARCH bronze_customers USING INDEX idx_customers_email (email=?)
```

```sql
EXPLAIN QUERY PLAN SELECT * FROM bronze_customers WHERE LOWER(email) = 'test@example.com';
```

```
QUERY PLAN
`--SCAN bronze_customers
```

Same index, same table, same intent — wrapping the column in
`LOWER()` alone flips `SEARCH` back to `SCAN`.

</details>

---

### 3. Make a prefix `LIKE` search sargable

On the same scratch copy (with `idx_customers_email` still in place),
check `EXPLAIN QUERY PLAN` for `WHERE email LIKE 'john%'` under
SQLite's default case-insensitive `LIKE`. Then set `PRAGMA
case_sensitive_like = ON;` and check the same query again.

<details>
<summary>Show solution</summary>

```sql
EXPLAIN QUERY PLAN SELECT * FROM bronze_customers WHERE email LIKE 'john%';
```

```
QUERY PLAN
`--SCAN bronze_customers
```

```sql
PRAGMA case_sensitive_like = ON;
EXPLAIN QUERY PLAN SELECT * FROM bronze_customers WHERE email LIKE 'john%';
```

```
QUERY PLAN
`--SEARCH bronze_customers USING INDEX idx_customers_email (email>? AND email<?)
```

With case-sensitive comparison, SQLite rewrites the prefix match into
an index-friendly range (`email > 'john' AND email < 'joho'`-ish
bound) and searches the index instead of scanning.  Be aware this
pragma changes `LIKE`'s matching behavior globally for the connection
— `'John'` would no longer match `'john%'` once it's on — so it's a
real behavior trade-off, not a free performance win.

</details>

---

### 4. Reason about `SELECT *` cost without running anything

`bronze_sales` has 14 columns. A report only needs `order_id`,
`order_date`, and the computed net amount (which, per Module 4, lives
in `silver_sales.net_amount`, not raw `bronze_sales`). Write the
`SELECT` you'd actually use for that report against `silver_sales`,
and explain in one sentence why it's preferable to `SELECT *`
even though both would return correct data.

<details>
<summary>Show solution</summary>

```sql
SELECT order_id, order_date, net_amount FROM silver_sales;
```

This reads only 3 of `silver_sales`'s columns instead of all of them
(`silver_sales` re-derives ~14 output columns from `bronze_sales`'s
14), reducing the I/O and computation `silver_sales`'s underlying
`CASE` expressions have to do for columns nobody's going to look at
(recall from Module 4 that a view recomputes its *entire* `SELECT` on
every query, including columns you then discard) — and it documents
exactly what the report depends on, so a future schema change to an
unrelated column can't silently break it.

</details>

---

### 5. Rewrite a non-sargable arithmetic filter

On your scratch copy, create an index on `bronze_sales(quantity)`.
Check the plan for `WHERE quantity + 1 > 5`, then rewrite it as an
equivalent sargable predicate and check the plan again.

<details>
<summary>Show solution</summary>

```sql
CREATE INDEX idx_sales_qty ON bronze_sales(quantity);

EXPLAIN QUERY PLAN SELECT * FROM bronze_sales WHERE quantity + 1 > 5;
```

```
QUERY PLAN
`--SCAN bronze_sales
```

```sql
EXPLAIN QUERY PLAN SELECT * FROM bronze_sales WHERE quantity > 4;
```

```
QUERY PLAN
`--SEARCH bronze_sales USING INDEX idx_sales_qty (quantity>?)
```

`quantity + 1 > 5` and `quantity > 4` are mathematically identical,
but only the second is sargable — the first wraps the indexed column
in arithmetic, the second isolates it on one side of the comparison.
Whenever possible, do the arithmetic to the *constant*, not the
column.

</details>

---

### 6. Rewrite a date-function filter as a sargable range

A common mistake: filtering "all 2023 orders" with
`strftime('%Y', order_date) = '2023'`. On your scratch copy, create an
index on `bronze_sales(order_date)`, check that plan, then rewrite the
filter as a sargable range on the raw `order_date` text and check
again. (Hint: ISO `YYYY-MM-DD` text sorts and compares correctly as
plain text, which is exactly why bronze — despite storing dates as
`TEXT` — can still support range queries once the format is
consistent.)

<details>
<summary>Show solution</summary>

```sql
CREATE INDEX idx_sales_order_date ON bronze_sales(order_date);

EXPLAIN QUERY PLAN
SELECT * FROM bronze_sales WHERE strftime('%Y', order_date) = '2023';
```

```
QUERY PLAN
`--SCAN bronze_sales
```

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_sales WHERE order_date >= '2023-01-01' AND order_date < '2024-01-01';
```

```
QUERY PLAN
`--SEARCH bronze_sales USING INDEX idx_sales_order_date (order_date>? AND order_date<?)
```

Wrapping `order_date` in `strftime()` forces a full scan — SQLite has
to compute `strftime('%Y', ...)` for every row to check the match. The
range rewrite avoids the function entirely and searches the index
directly. One caveat worth remembering for real Oakhaven queries:
`bronze_sales.order_date` is genuinely messy (three mixed formats per
the data dictionary) — this range rewrite is only valid against a
column you know is consistently ISO-formatted, such as
`silver_sales.order_date` after cleaning, not raw `bronze_sales.order_date`
directly.

</details>
