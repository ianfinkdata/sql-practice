# Changing Data: INSERT, UPDATE, DELETE

> Add rows, change them, remove them — and handle the "insert it or update it" case cleanly.

## The idea

DDL drew the rooms. **DML** — Data Manipulation Language — moves the furniture in and out. There are really just three things you ever do to data: put it in, change it, or take it out.

**INSERT** puts new rows in. It's like filling out a fresh form and dropping it in the inbox. You can drop in one form, a whole stack at once, or — cleverly — copy rows from another table that already has the answers.

**UPDATE** changes rows that are already there. Think of an editor going through filed forms and correcting fields. The critical part is *which* forms get corrected. That's the `WHERE` clause, and it is the most important word in the whole statement. An `UPDATE` without a `WHERE` edits **every single row** in the table.

**DELETE** removes rows. Same warning: a `DELETE` without a `WHERE` empties the table. There's also a faster cousin, **TRUNCATE**, which wipes the entire table in one stroke. The difference is like the difference between erasing names from a list one by one (DELETE — selective, logged, reversible inside a transaction) versus shredding the whole list and grabbing a blank one (TRUNCATE — all-or-nothing, fast, usually can't be rolled back partway).

Finally there's a common real-world need: "if this customer already exists, update them; if not, insert them." Doing that by hand is two statements and a race condition. The clean answer is an **UPSERT** (update-or-insert), sometimes spelled `MERGE`. It's one statement that decides for each row whether to insert or update.

## Why it matters

Queries answer questions; DML is how the data actually lives and breathes. Every order placed, profile edited, or record archived is DML running underneath. And it's where the scariest mistakes happen — a forgotten `WHERE` on a production `UPDATE` is a story every engineer eventually tells. Learning the safe habits now saves you from being the one telling it.

## See it

Insert a single customer, then several at once:

```sql
INSERT INTO customers (customer_id, customer_name, region, email)
VALUES (101, 'Mara Lindqvist', 'North', 'mara@example.com');

INSERT INTO customers (customer_id, customer_name, region, email) VALUES
    (102, 'Theo Nakamura', 'West',  'theo@example.com'),
    (103, 'Priya Anand',   'South', 'priya@example.com');
```

Insert rows derived from a query (give every existing customer a starter record somewhere):

```sql
INSERT INTO sales (sale_id, sale_date, customer_id, rep_id, amount)
SELECT row_number() OVER () + 9000, CURRENT_DATE, customer_id, 1, 0
FROM customers
WHERE region = 'North';
```

Update — note the `WHERE`:

```sql
UPDATE sales
SET amount = amount * 1.05
WHERE sale_date >= DATE '2026-01-01';
```

Delete selectively, and contrast with truncate:

```sql
DELETE FROM sales WHERE amount = 0;

TRUNCATE TABLE sales;   -- removes ALL rows, fast, usually not rollback-safe
```

Upsert — insert the customer, or update their email if the id already exists:

```sql
INSERT INTO customers (customer_id, customer_name, email)
VALUES (101, 'Mara Lindqvist', 'mara.new@example.com')
ON CONFLICT (customer_id)
DO UPDATE SET email = EXCLUDED.email;
```

> **Dialect note:** Upsert syntax splits three ways — PostgreSQL and SQLite use `INSERT ... ON CONFLICT ... DO UPDATE`, MySQL uses `INSERT ... ON DUPLICATE KEY UPDATE`, and SQL Server / Oracle use the `MERGE` statement. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Always write the `WHERE` before the `SET`.** Build the filter first, even run it as a `SELECT` to confirm the row count, *then* turn it into an `UPDATE` or `DELETE`.
- **TRUNCATE is not DELETE.** It can't be filtered, usually skips triggers, and often can't be rolled back. Don't reach for it when you only meant to remove some rows.
- **Inserts must satisfy constraints.** A foreign key pointing at a non-existent customer, or a duplicate primary key, will be rejected — that's the constraint doing its job.
- **`EXCLUDED` (Postgres) means "the row you tried to insert."** It's how the update half of an upsert reaches the new values.
- **Multi-row inserts are atomic in one statement** — if one row violates a constraint, the whole statement typically fails.

## Practice

1. Insert two new sales reps in a single statement, supplying name, commission rate, and hire date.
2. Write an `UPDATE` that raises `commission_rate` by 0.02 only for reps hired before 2024 — and describe how you'd verify the target rows first.
3. Write the statement that copies every customer in the `'West'` region into an `archived_customers` table using `INSERT ... SELECT`.
4. In plain English, explain when you'd choose `DELETE FROM sales WHERE ...` over `TRUNCATE TABLE sales`, and why an upsert beats doing a separate `SELECT` then `INSERT`/`UPDATE`.

---
**Prev:** [Creating Tables: DDL and Constraints](01-ddl-tables.md) · **Next:** [Transactions and ACID](03-transactions.md)
