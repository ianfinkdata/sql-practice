# Joins: Inner & Left

> Stitch related tables together on a shared key — and decide who gets left out.

## The idea

Real databases split information across many tables on purpose. Customer details live in `customers`. Each sale lives in `sales`. The sale doesn't repeat the customer's name and email — that would be wasteful and error-prone. Instead it stores a tiny pointer: `customer_id`.

A **join** is how you follow that pointer to reunite the pieces. The shared column — `customer_id` here — is called a **key**. It's the matching field that lets SQL line up a row in one table with the right row in another.

Think of a coat check. You hand over your coat and get a numbered ticket. The coat (the customer's full details) sits in the back room. Your ticket (`customer_id`) is the small reference you carry. To get your coat back, you match the ticket number to the coat. A join does exactly this matching, across every row, automatically.

There are two joins you'll use most:

- **INNER JOIN** — keep only rows that have a match on *both* sides. If a sale has no matching customer, or a customer has no sales, they don't appear.
- **LEFT JOIN** — keep *every* row from the left (first) table, matched up where possible. Where there's no match on the right, the right-side columns come back empty (NULL).

INNER is "only show me complete pairs." LEFT is "show me everyone on the left, with their match if it exists."

## Why it matters

Almost no useful question lives in a single table. "Show each sale with the customer's name." "List every customer and their total spend, including those who've never bought." Answering these means combining tables — and choosing INNER vs LEFT decides whether the people *without* matches show up. That choice changes your answer, so it matters.

## See it

First, **table aliases** — short nicknames so you don't retype long table names and can clearly say which table a column belongs to. We use `s` for sales and `c` for customers:

```sql
SELECT
  s.sale_id,
  s.amount,
  c.customer_name
FROM sales AS s
INNER JOIN customers AS c
  ON s.customer_id = c.customer_id;
```

The `ON` clause states the matching rule: pair a sale with the customer who shares its `customer_id`. This returns one row per sale, now carrying the customer's name. Sales with no matching customer are dropped.

Now a **LEFT JOIN**, to keep customers who have *never* made a sale:

```sql
SELECT
  c.customer_name,
  s.amount
FROM customers AS c
LEFT JOIN sales AS s
  ON c.customer_id = s.customer_id;
```

Every customer appears. For a customer with no sales, `s.amount` comes back as NULL — a visible signal of "no match found." Swap to INNER JOIN here and those customers vanish entirely.

### ON vs WHERE

`ON` says **how the tables match up**. `WHERE` says **which rows to keep afterward**. They feel similar but do different jobs:

```sql
SELECT c.customer_name, s.amount
FROM customers AS c
INNER JOIN sales AS s
  ON c.customer_id = s.customer_id      -- the matching rule
WHERE c.region = 'West';                 -- filter the joined result
```

Keep the relationship logic in ON, and your row filters in WHERE. (This separation becomes critical with LEFT JOIN, which the next module explores.)

## Watch out

- **Forgetting the ON clause** can produce a giant accidental cross-join — every row paired with every other row. Always state how the tables relate.
- **INNER silently drops unmatched rows.** If a count comes back lower than you expected, an INNER JOIN may be hiding records that have no match.
- **LEFT vs INNER changes the answer.** Choose deliberately based on whether unmatched left rows should appear.
- **Ambiguous column names.** When both tables have a `customer_id`, you must qualify it (`s.customer_id`) or SQL won't know which you mean.
- **NULLs from a LEFT JOIN are normal**, not errors — they mark "no match." Plan for them in later calculations.

## Practice

1. Show each sale's `sale_id` and `amount` alongside the name of the customer who made it.
2. List every customer and any sale amounts they have, including customers who have made no sales at all.
3. Show each sale with its rep's name by joining `sales` to `sales_rep`, using table aliases.
4. List customers in the 'West' region together with their sales, keeping every West customer even if they have never bought anything.

---
**Prev:** [HAVING](./03-having.md) · **Next:** [Joins: Advanced](./05-joins-advanced.md)
