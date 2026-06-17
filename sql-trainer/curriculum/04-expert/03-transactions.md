# Transactions and ACID

> Group several changes into one all-or-nothing unit, so your data is never left half-finished.

## The idea

Imagine moving money from a checking account to a savings account. It takes two steps: subtract from checking, add to savings. Now imagine the power goes out *between* those two steps. The money has left checking but never arrived in savings. It has simply vanished. That is the nightmare a **transaction** exists to prevent.

A transaction is a way of telling the database: "treat these statements as a single unit. Either all of them happen, or none of them do. Never leave me stranded in the middle." You open a transaction with `BEGIN`, do your work, and then either `COMMIT` (make it permanent — both steps stick) or `ROLLBACK` (undo everything back to the start — as if you never began).

The guarantees a transaction gives you are summed up by four letters, **ACID**:

- **Atomicity** — all-or-nothing. The bank transfer either fully completes or fully reverses; no half-states.
- **Consistency** — the database moves from one valid state to another. Constraints hold before and after; the books always balance.
- **Isolation** — concurrent transactions don't trip over each other. Your half-finished work is invisible to others until you commit.
- **Durability** — once you commit, it's saved for good, even if the power dies one second later.

There's also a way to set a "checkpoint" partway through a long transaction: a **SAVEPOINT**. Think of it as a bookmark. If a later step fails, you can roll back just to the bookmark instead of throwing away the whole transaction. Useful when one part of a big operation is risky but the earlier parts are fine.

## Why it matters

Real operations are rarely a single statement. Placing an order means inserting the order, decrementing inventory, charging a card, and writing a receipt. If any one of those fails, you must undo the rest — or you'll sell stock you don't have or charge for orders that never shipped. Transactions are the mechanism that makes multi-step changes trustworthy. Without them, every crash, error, or two users acting at once is a chance to corrupt your data.

## See it

The bank transfer, done safely:

```sql
BEGIN;
    UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
    UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
COMMIT;
```

If anything looks wrong before you commit, throw it all away:

```sql
BEGIN;
    UPDATE sales SET amount = amount * 10 WHERE sale_id = 5000;  -- oops, wrong factor
ROLLBACK;   -- the amount is back to what it was
```

A savepoint as a partial undo point:

```sql
BEGIN;
    INSERT INTO sales (sale_id, sale_date, customer_id, rep_id, amount)
    VALUES (7001, CURRENT_DATE, 101, 1, 250);

    SAVEPOINT after_sale;

    UPDATE sales_rep SET commission_rate = 0.5 WHERE rep_id = 1;  -- risky
    ROLLBACK TO SAVEPOINT after_sale;   -- undo only the commission change

COMMIT;   -- the sale insert still stands
```

## Watch out

- **A transaction left open holds locks.** Forget to commit or roll back and you can block other users. Close every transaction you open.
- **`COMMIT` is the point of no return.** After it, `ROLLBACK` can't help you. Commit deliberately, not by reflex.
- **Autocommit is often on by default.** Many tools wrap each statement in its own transaction automatically, so single statements "just work" — but multi-step safety requires an explicit `BEGIN`.
- **Rollback undoes data, not side effects.** It won't un-send an email your application already fired off mid-transaction.
- **Keep transactions short.** Long-running ones hold locks longer and raise the odds of conflicts and deadlocks (next module).

## Practice

1. In plain English, walk through what `Atomicity` protects against in the bank-transfer example, and how it differs from `Durability`.
2. Write a transaction that inserts a new customer and their first sale together, so that if the sale insert fails, the customer insert is undone too.
3. Describe a real situation where you'd want a `SAVEPOINT` rather than rolling back the entire transaction.
4. Explain why a transaction that stays open for ten minutes might cause problems for everyone else using the database.

---
**Prev:** [Changing Data: DML](02-dml.md) · **Next:** [Isolation and Concurrency](04-isolation-concurrency.md)
