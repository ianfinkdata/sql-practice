# Tier 4 — Expert Exercises

> You stop just *reading* the database and start *building and tuning* it: DDL
> with constraints, DML, upserts, transactions, views, indexing decisions,
> reading a plan, optimization rewrites, a trigger/procedure sketch, and JSON.

Uses the [shared dataset](README.md#the-shared-dataset). A few answers are
**design discussions** in prose (indexing, plans) — read those even when you
think you know the SQL.

← Back to [Exercises](README.md) · matching curriculum: [`04-expert`](../curriculum/04-expert/)

---

## 1. CREATE TABLE with constraints

Write the DDL for a `products` table with a primary key, a non-null name, a
category, and a `unit_price` that must be non-negative.

<details><summary>Show solution</summary>

```sql
CREATE TABLE products (
    product_id   INTEGER      PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category     VARCHAR(50),
    unit_price   NUMERIC(10,2) NOT NULL
                 CHECK (unit_price >= 0)
);
```

`PRIMARY KEY` enforces uniqueness + not-null; `CHECK` rejects bad prices at write
time so the data can't go wrong.

</details>

---

## 2. A foreign key

Add a `sales` table whose `customer_id` must reference an existing customer.

<details><summary>Show solution</summary>

```sql
CREATE TABLE sales (
    sale_id     INTEGER PRIMARY KEY,
    sale_date   DATE NOT NULL,
    customer_id INTEGER NOT NULL,
    rep_id      INTEGER,
    amount      NUMERIC(12,2) NOT NULL,
    CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);
```

A `FOREIGN KEY` guarantees referential integrity: you can't insert a sale for a
customer who doesn't exist, and (by default) can't delete a customer who still
has sales.

</details>

---

## 3. INSERT, UPDATE, DELETE

(a) Add a new customer. (b) Fix a typo'd region. (c) Remove a test customer.

<details><summary>Show solution</summary>

```sql
-- (a) insert
INSERT INTO customers (customer_id, customer_name, region, signup_date, email)
VALUES (101, 'Acme Corp', 'North', DATE '2024-03-01', 'ap@acme.example');

-- (b) update
UPDATE customers
SET region = 'North'
WHERE customer_id = 101 AND region = 'Norht';

-- (c) delete
DELETE FROM customers
WHERE customer_id = 999;
```

Always pair `UPDATE`/`DELETE` with a `WHERE` — without one they hit *every* row.

</details>

---

## 4. Upsert (MERGE)

"Insert this customer, or update their email if they already exist." Write it as
a `MERGE`.

<details><summary>Show solution</summary>

```sql
MERGE INTO customers AS tgt
USING (SELECT 101 AS customer_id,
              'ap@acme.example' AS email) AS src
   ON tgt.customer_id = src.customer_id
 WHEN MATCHED THEN
     UPDATE SET email = src.email
 WHEN NOT MATCHED THEN
     INSERT (customer_id, email)
     VALUES (src.customer_id, src.email);
```

`MERGE` branches on whether the key already matched. (Postgres/MySQL also offer
`INSERT ... ON CONFLICT` / `ON DUPLICATE KEY UPDATE` — see the Dialect Decoder.)

</details>

---

## 5. A transaction

Move a sale's credit from one rep to another so the change is **all-or-nothing**.

<details><summary>Show solution</summary>

```sql
BEGIN;

UPDATE sales SET rep_id = 7 WHERE sale_id = 5001;

-- imagine a second bookkeeping update here that must succeed too
UPDATE sales_rep SET commission_rate = commission_rate WHERE rep_id = 7;

COMMIT;   -- or ROLLBACK; if anything failed
```

A transaction wraps multiple statements so they commit together or not at all —
you never end up half-applied.

</details>

---

## 6. A view

Create a reusable view `v_customer_revenue` exposing each customer's name and
total revenue.

<details><summary>Show solution</summary>

```sql
CREATE VIEW v_customer_revenue AS
SELECT c.customer_id,
       c.customer_name,
       COALESCE(SUM(s.amount), 0) AS total_revenue
FROM customers AS c
LEFT JOIN sales AS s ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name;
```

A view is a saved query you select from like a table — it hides the join/aggregate
and keeps reporting consistent. It stores no data (unless it's *materialized*).

</details>

---

## 7. Indexing decision (design)

A report constantly runs `WHERE customer_id = ? AND sale_date >= ?` against a
large `sales` table. What index would you add, and why?

<details><summary>Show solution</summary>

**Model answer.** Add a **composite index** on `sales (customer_id, sale_date)`:

```sql
CREATE INDEX ix_sales_cust_date ON sales (customer_id, sale_date);
```

- **Column order matters.** Put the equality column (`customer_id`) first so the
  index narrows to one customer, then `sale_date` supports the range scan and any
  `ORDER BY sale_date`.
- It also helps queries that filter on `customer_id` alone (leading-column rule),
  but **not** ones filtering on `sale_date` alone.
- **Cost:** indexes speed reads but slow writes and use storage, so index for the
  queries you actually run, not speculatively. If the report only needs
  `amount`, adding it as an included/covering column avoids table lookups
  entirely.

</details>

---

## 8. Reading a query plan (design)

Your join report is slow. The plan shows a **Seq Scan / Full Table Scan** on
`sales` plus a **Hash Join**, with a high estimated row count. What is it telling
you, and what do you check?

<details><summary>Show solution</summary>

**Model answer.** Read a plan **bottom-up, inside-out** — leaf nodes run first.

- **Seq Scan on `sales`** = the engine is reading every row. Fine if you truly
  need most of the table; a red flag if you're filtering to a few rows, which
  suggests a **missing index** on the filter/join column.
- **Hash Join** builds a hash table from the smaller input and probes it — great
  for big unindexed joins, worrying if you expected an index-driven nested loop on
  a selective key.
- **Estimated vs actual rows** (use `EXPLAIN ANALYZE`): a big mismatch means
  **stale statistics** — run `ANALYZE`/`UPDATE STATISTICS` so the optimizer plans
  with reality.
- Watch the **widest-cost** node and any **Sort/Spill to disk** — that's usually
  where the time goes, not the row you'd guess.

Checklist: index the selective predicate, refresh stats, and confirm the filter
is *sargable* (next exercise).

</details>

---

## 9. Optimization rewrite

This query is slow and returns wrong-ish results around NULLs. Rewrite it to be
**sargable** (index-friendly) and correct:

```sql
SELECT * FROM sales
WHERE YEAR(sale_date) = 2024
  AND amount <> 0;
```

<details><summary>Show solution</summary>

```sql
SELECT *
FROM sales
WHERE sale_date >= DATE '2024-01-01'
  AND sale_date <  DATE '2025-01-01'
  AND amount <> 0;
```

Wrapping `sale_date` in `YEAR(...)` forces a full scan because the index is on
the raw column, not the function result — a **range predicate** on the bare
column lets the optimizer use an index. (If `amount` can be `NULL`, note `<> 0`
silently drops those rows; add `OR amount IS NULL` if you want to keep them.)

</details>

---

## 10. Trigger / procedure sketch

Sketch a trigger that auto-stamps a `last_modified` timestamp whenever a
`customers` row is updated.

<details><summary>Show solution</summary>

```sql
-- Postgres-flavored sketch
CREATE FUNCTION set_last_modified() RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_touch
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION set_last_modified();
```

A `BEFORE UPDATE ... FOR EACH ROW` trigger can mutate `NEW` before the write
lands, so the timestamp is maintained by the database, not every caller. (Syntax
varies a lot by engine — this is the shape, not the literal portable text.)

</details>

---

## 11. JSON query

`customers` gains a `prefs JSON` column like `{"channel":"email","vip":true}`.
List VIP customers and their preferred channel.

<details><summary>Show solution</summary>

```sql
SELECT customer_name,
       prefs ->> 'channel' AS channel
FROM customers
WHERE (prefs ->> 'vip') = 'true';
```

`->>` extracts a JSON field as text. Engines differ: MySQL uses
`JSON_EXTRACT(prefs,'$.vip')` / `->>'$.vip'`, SQL Server uses
`JSON_VALUE(prefs,'$.vip')`. Indexing a hot JSON path (generated column or
expression index) keeps these fast.

</details>

---

## 12. Putting it together — guarded upsert in a transaction

Upsert a batch of customers *and* log the run, atomically: either both the merge
and the audit row commit, or neither does.

<details><summary>Show solution</summary>

```sql
BEGIN;

MERGE INTO customers AS tgt
USING staging_customers AS src
   ON tgt.customer_id = src.customer_id
 WHEN MATCHED THEN UPDATE SET
        customer_name = src.customer_name,
        region        = src.region,
        email         = src.email
 WHEN NOT MATCHED THEN INSERT
        (customer_id, customer_name, region, signup_date, email)
 VALUES (src.customer_id, src.customer_name, src.region,
         src.signup_date, src.email);

INSERT INTO load_audit (table_name, loaded_at)
VALUES ('customers', CURRENT_TIMESTAMP);

COMMIT;
```

Wrapping the `MERGE` and the audit `INSERT` in one transaction guarantees the
load and its log stay consistent — a pattern you'll lean on constantly in
Tier 5.

</details>

---

Next up: [Tier 5 — Master](tier-5-master.md) →
