# Isolation and Concurrency

> When many transactions run at once, isolation levels decide how much they're allowed to see of each other's unfinished work.

## The idea

A database is rarely used by one person at a time. Dozens or thousands of transactions run at once, all reading and writing the same tables. The "I" in ACID — **Isolation** — is about keeping them from stepping on each other. But perfect isolation is slow, so databases offer a dial: how careful do you want to be, and how much speed will you trade for it?

To understand the dial, picture two people working from the same shared spreadsheet. Three kinds of trouble can happen:

- **Dirty read** — you read a number your coworker is still typing and hasn't saved. Then they hit undo. You acted on a value that never really existed.
- **Non-repeatable read** — you read a customer's balance, look away, read it again, and it changed because someone committed an edit in between. The same query gave two different answers inside your one transaction.
- **Phantom read** — you count the rows matching "region = West" and get 10. A moment later you count again and get 11, because someone inserted a new matching row. Rows *appeared* like phantoms.

The **isolation level** is the dial that decides which of these you tolerate:

- **READ COMMITTED** — you only ever see committed data (no dirty reads), but rows can still change or appear between your reads. The common default.
- **REPEATABLE READ** — every row you've read stays frozen for your whole transaction (no non-repeatable reads). Phantoms may still slip in on some engines.
- **SERIALIZABLE** — the strictest. The result is as if every transaction ran one after another, alone. No anomalies at all — but the most contention and the most retries.

How does the database actually enforce this? Two strategies. **Locking** puts a "do not touch" sign on rows or tables until you're done — simple but it makes others wait. **MVCC** (Multi-Version Concurrency Control) instead keeps multiple versions of a row, so readers see a consistent snapshot without blocking writers. Most modern engines lean on MVCC.

One hazard is unavoidable when locks are involved: a **deadlock**. Transaction A holds a lock B wants, and B holds a lock A wants. Both wait forever. The database detects this, picks a victim, and kills one transaction so the other can proceed. You handle it by retrying.

## Why it matters

Choose too loose an isolation level and you get subtle, maddening bugs — a report that double-counts, an inventory that goes negative, money that briefly exists twice. Choose too strict and your system grinds under lock contention and constant retries. Knowing the levels lets you pick the lightest one that's still correct for the job, which is exactly the engineering trade-off that separates a fast, reliable system from a slow or buggy one.

## See it

Set the isolation level for a transaction, then run a read that should stay stable throughout:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
    SELECT count(*) FROM sales WHERE region = 'West';
    -- ... more work ...
    SELECT count(*) FROM sales WHERE region = 'West';  -- same answer, guaranteed
COMMIT;
```

Take an explicit lock on rows you intend to update, so no one else changes them first:

```sql
BEGIN;
    SELECT amount FROM sales WHERE sale_id = 5000 FOR UPDATE;  -- locks the row
    UPDATE sales SET amount = amount - 50 WHERE sale_id = 5000;
COMMIT;
```

> **Dialect note:** Defaults differ. PostgreSQL and Oracle default to READ COMMITTED; MySQL's InnoDB defaults to REPEATABLE READ; SQL Server defaults to READ COMMITTED (with options for snapshot isolation). The exact set syntax varies too. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Higher isolation isn't free.** SERIALIZABLE can force transactions to abort and retry under load. Use it where correctness demands, not everywhere.
- **Expect deadlocks; handle them.** They're normal under concurrency. Wrap risky transactions in retry logic rather than assuming they'll never happen.
- **Access tables in a consistent order.** If every transaction locks rows in the same order, you sharply reduce deadlock risk.
- **Don't assume your engine's default.** As the dialect note shows, "REPEATABLE READ" and "READ COMMITTED" mean the default is different across databases — verify it.
- **Long transactions widen the window** for conflicts and bloat MVCC version history. Keep them short.

## Practice

1. In plain English, give a concrete example of a dirty read causing a wrong business decision, using the sales data.
2. Explain the difference between a non-repeatable read and a phantom read in your own words.
3. Describe how MVCC lets a long-running report read the sales table without blocking people inserting new sales.
4. Two transactions each update `sales_rep` and `sales` but in opposite order, and they deadlock. Suggest a change to their design that would prevent it.

---
**Prev:** [Transactions and ACID](03-transactions.md) · **Next:** [Views and Materialized Views](05-views.md)
