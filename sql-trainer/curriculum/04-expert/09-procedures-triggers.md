# Procedures, Functions, and Triggers

> Put logic inside the database itself — routines you call on demand, and triggers that fire automatically.

## The idea

So far, every change to your data was something *you* typed and ran. But databases can hold logic of their own — little programs that live next to the data. There are three flavors, and the difference is mostly about *who calls them and when*.

A **stored procedure** is a named routine you invoke deliberately, like pressing a button. "Run `monthly_close` " kicks off a sequence of steps — update these, archive those, recompute that. It can take parameters, loop, branch with `IF`, and bundle many statements into one safe transaction. Think of it as a labeled lever on a machine: you pull it when you want that job done.

A **user-defined function (UDF)** is a routine that *computes and returns a value*, meant to be used inside queries. Where a procedure is a button you press, a function is an ingredient you drop into a recipe: `SELECT customer_name, loyalty_score(customer_id) FROM customers`. It takes inputs and hands back an answer, and ideally it just calculates — it shouldn't go off changing data behind your back.

A **trigger** is the magic one: logic that fires *automatically* in response to an event, with no one calling it. "Whenever a row is inserted into `sales`, also do X." It's a tripwire. You set it once, and from then on the database itself enforces the rule — logging the change, updating a running total, stamping a timestamp, or rejecting bad data. Triggers can fire `BEFORE` or `AFTER` an `INSERT`, `UPDATE`, or `DELETE`.

All three can use **control flow** — variables, `IF`/`ELSE`, loops, error handling — because inside them you're writing a small program, not just a single query.

The hard part isn't the syntax; it's judgment. These tools are powerful and *invisible*. A trigger that quietly modifies data runs whether or not anyone remembers it exists, which is wonderful when it enforces a rule and miserable when it surprises a debugging engineer at 2 a.m.

## Why it matters

Putting logic in the database guarantees it runs *no matter who or what touches the data* — every app, every script, every manual fix obeys the same rule. That's the great strength of triggers and procedures: a constraint or an audit log you literally cannot bypass. Used well, they centralize critical logic. Used carelessly, they scatter behavior into hidden corners and make a system maddening to reason about. Knowing when *not* to reach for them is as valuable as knowing how.

## See it

A stored procedure with control flow — give a rep a raise, but cap it:

```sql
CREATE PROCEDURE give_raise(p_rep_id INT, p_bump DECIMAL)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_bump > 0.1 THEN
        RAISE EXCEPTION 'Raise too large';
    END IF;
    UPDATE sales_rep
    SET commission_rate = commission_rate + p_bump
    WHERE rep_id = p_rep_id;
END;
$$;

CALL give_raise(1, 0.02);
```

A function used inside a query — returns a value, changes nothing:

```sql
CREATE FUNCTION sale_tier(amt DECIMAL) RETURNS TEXT
LANGUAGE plpgsql AS $$
BEGIN
    RETURN CASE WHEN amt >= 1000 THEN 'large' ELSE 'standard' END;
END;
$$;

SELECT sale_id, amount, sale_tier(amount) FROM sales;
```

A trigger — automatically keep a customer's lifetime spend in sync:

```sql
CREATE TRIGGER trg_update_spend
AFTER INSERT ON sales
FOR EACH ROW
EXECUTE FUNCTION add_to_lifetime_spend();   -- a trigger function you defined
```

> **Dialect note:** This area is the *most* dialect-specific in all of SQL. Oracle uses **PL/SQL**; PostgreSQL uses **PL/pgSQL** (and others) with `$$` blocks; MySQL has its own stored-routine syntax with `DELIMITER` changes; SQL Server uses **T-SQL**; Databricks/Spark SQL supports SQL UDFs and Python but no traditional row-level triggers. Treat the example above as PL/pgSQL flavored. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Triggers are invisible.** A change you can't see in the SQL you ran can be the hardest bug to track down. Document every trigger loudly.
- **Don't let functions have side effects.** A function used in a `SELECT` should compute, not modify data. Hidden writes inside a query are a trap.
- **Trigger cascades can spiral.** A trigger that writes to a table with its own trigger can chain — or even loop. Keep them simple and shallow.
- **Per-row triggers on bulk operations are slow.** Inserting a million rows fires the trigger a million times. Consider set-based logic instead.
- **Business logic split between app and database can drift.** Decide where each rule lives and be consistent, or you'll enforce it twice or zero times.
- **They're hard to version and test.** Database routines often live outside your code repo's normal review. Put their definitions under source control deliberately.

## Practice

1. Describe a rule about the `sales` table that's better enforced by a trigger than by trusting every application to remember it.
2. Explain the difference between a stored procedure and a user-defined function in terms of how and where you'd call each.
3. Give an example of a trigger that would be a *bad* idea, and explain what makes it risky or surprising.
4. You need a "close the month" job that archives old sales and recomputes summaries in one safe unit. Would you use a procedure, a function, or a trigger, and why?

---
**Prev:** [Query Optimization](08-query-optimization.md) · **Next:** [JSON and Semi-Structured Data](10-json-semistructured.md)
