# 3. Transactions


<!-- nav -->
Previous: [2. ALTER TABLE and Schema Evolution](02-alter-table-and-schema-evolution.md). Next: [4. Views](04-views.md).
<!-- /nav -->

## The idea

A transaction groups one or more statements into a single unit: either
**all** of them take effect, or **none** of them do. That guarantee is
called **atomicity** — it's the "A" in the classic ACID acronym
(Atomicity, Consistency, Isolation, Durability), and it's what lets
you write multi-statement operations without worrying about the
database ending up in a half-finished state if something goes wrong
partway through.

The classic motivating example is a bank transfer: moving money from
Alice's account to Bob's is *two* updates (debit Alice, credit Bob).
If the process crashes after the debit but before the credit, and
those two statements weren't in a transaction, money has simply
vanished. Wrap them in a transaction and that can't happen — either
both updates land, or neither does.

## Syntax

```sql
BEGIN;
  -- one or more statements
COMMIT;    -- make all of them permanent
```

or, to abandon everything since `BEGIN`:

```sql
BEGIN;
  -- one or more statements
ROLLBACK;  -- undo all of them, as if they never ran
```

Outside an explicit `BEGIN`, SQLite runs every statement in its own
implicit transaction (this is "autocommit mode") — which is why every
`SELECT` you've run all course has "just worked" without you ever
typing `BEGIN`/`COMMIT`. Explicit transactions matter once you have
**more than one write that needs to succeed or fail together.**

## Verified examples

All against a **scratch copy** — transactions modify data, so this
must never run against the shared `project/oakhaven.db`:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

### Example 1 — ROLLBACK actually undoes the change

```sql
SELECT COUNT(*) FROM bronze_customers;
```

```
600
```

```sql
BEGIN;
DELETE FROM bronze_customers WHERE customer_id <= 10;
SELECT COUNT(*) AS after_delete FROM bronze_customers;
ROLLBACK;
SELECT COUNT(*) AS after_rollback FROM bronze_customers;
```

```
after_delete
------------
590

after_rollback
--------------
600
```

The `DELETE` really did remove 10 rows — `after_delete` proves that,
mid-transaction, the change is visible within this same connection.
But `ROLLBACK` threw the entire transaction away: `after_rollback`
shows the count is back to 600, as if the `DELETE` never happened.

### Example 2 — COMMIT makes it permanent

```sql
BEGIN;
DELETE FROM bronze_customers WHERE customer_id <= 5;
COMMIT;
SELECT COUNT(*) AS after_commit FROM bronze_customers;
```

```
after_commit
------------
595
```

This time `COMMIT` was called instead of `ROLLBACK` — the delete of 5
rows is now permanent. A fresh connection to this scratch file would
also see 595 rows; a `ROLLBACK` after `COMMIT` would do nothing (the
transaction is already closed).

### Example 3 — atomicity across multiple statements (the transfer pattern)

```sql
CREATE TABLE demo_accounts (id INTEGER PRIMARY KEY, name TEXT, balance REAL);
INSERT INTO demo_accounts (name, balance) VALUES ('Alice', 100.0), ('Bob', 50.0);

BEGIN;
UPDATE demo_accounts SET balance = balance - 30 WHERE name = 'Alice';
UPDATE demo_accounts SET balance = balance + 30 WHERE name = 'Bob';
SELECT * FROM demo_accounts;
COMMIT;
```

```
id  name   balance
--  -----  -------
1   Alice  70.0
2   Bob    80.0
```

Both updates are visible together, inside the transaction, before the
`COMMIT` even runs — and once committed they're permanent. If the
second `UPDATE` had failed for any reason, the whole block could be
rolled back and Alice's balance would never have been debited in the
first place.

### Example 4 — catching a mistake before it's permanent

```sql
BEGIN;
UPDATE demo_accounts SET balance = balance - 1000 WHERE name = 'Alice';
SELECT * FROM demo_accounts;
```

```
id  name   balance
--  -----  -------
1   Alice  -930.0
2   Bob    80.0
```

That's an obviously wrong balance — this is exactly the moment a
transaction earns its keep. Instead of committing a mistake:

```sql
ROLLBACK;
SELECT * FROM demo_accounts;
```

```
id  name   balance
--  -----  -------
1   Alice  70.0
2   Bob    80.0
```

Alice's balance is back to 70.0, as though the erroneous `UPDATE` never
ran. This is the core value proposition of a transaction: it gives
you a checkpoint you can return to as long as you haven't typed
`COMMIT` yet.

## How this connects to Oakhaven

`project/build.py` uses exactly this pattern for real: it opens one
connection, runs bronze schema creation, all the Python-driven bronze
data generation, the calendar recursive CTE, then all silver and gold
view creation — and only calls `conn.commit()` near the very end.
Everything from `sqlite3.connect()` to that `commit()` is effectively
one long transaction. If generation crashed partway through (a Python
exception mid-way through `generate_sales.generate()`, say), nothing
would be persisted to `project/oakhaven.db` — you'd never end up with
a half-populated database on disk.

## Common mistakes

- **Forgetting to `COMMIT`.** Uncommitted changes are only visible to
  the connection that made them; if the process exits or the
  connection closes without a `COMMIT`, most SQLite configurations
  will roll the transaction back automatically. Don't assume a change
  "took" just because a `SELECT` in the same session sees it.
- **Assuming `ROLLBACK` works after `COMMIT`.** Once committed, a
  transaction is closed — there's nothing left to roll back. If you
  need to undo committed data, that's a new set of statements (and a
  new transaction), not a `ROLLBACK`.
- **Running long transactions against a shared, concurrently-used
  database.** An open transaction can hold locks that block other
  connections. This is one more reason the shared `project/oakhaven.db`
  is read-only for you in this course — concurrent writers are exactly
  the scenario transactions are designed to arbitrate, and you don't
  want to be the one blocking a classmate's `SELECT`.
- **Treating a transaction as a performance tool without needing the
  atomicity.** Wrapping many independent statements in a single
  transaction can speed up bulk writes (fewer disk syncs), but if
  those statements have no logical "all or nothing" relationship,
  reach for it deliberately, not as a reflex.

## Key takeaways

- `BEGIN` / `COMMIT` / `ROLLBACK` group statements into one atomic
  unit — all changes apply, or none do.
- `ROLLBACK` genuinely undoes everything since the matching `BEGIN`,
  even changes already visible in the same session — verified above
  by watching a row count drop and then bounce back.
- Outside an explicit `BEGIN`, SQLite auto-commits every statement
  individually — explicit transactions matter once multiple writes
  need to succeed or fail as one.
- Always demo transactions against a scratch copy of the database.

---

<!-- nav -->
Previous: [2. ALTER TABLE and Schema Evolution](02-alter-table-and-schema-evolution.md). Next: [4. Views](04-views.md).
<!-- /nav -->
