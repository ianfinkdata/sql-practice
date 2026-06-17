# Subqueries

> A query inside a query — answer one question to help answer another.

## The idea

Sometimes a question has a hidden first step. "Show me customers who spent more than the average." Before you can find them, you have to *know the average*. That inner question — "what is the average?" — is a query of its own.

A **subquery** is exactly that: a query nested inside another query. The inner one runs to produce an answer, and the outer one uses that answer. It's like solving the part in parentheses of a math expression first, then plugging the result into the rest.

Subqueries come in a few shapes:

- **Scalar subquery** — returns a single value (one row, one column). It stands in wherever a single value would go, like a number you compute on the fly.
- **Nested subquery with IN or EXISTS** — returns a *list* of values (with IN) or just a yes/no (with EXISTS). Used to ask "is this row's value in that list?" or "does any matching row exist?"
- **Correlated subquery** — the inner query *references the outer row*, so it re-runs for each outer row. It's a query that peeks back out at its caller.

And subqueries can live in different spots: in `SELECT` (as a computed column), in `FROM` (as a temporary table to query from), or in `WHERE` (as a filter condition).

## Why it matters

Subqueries let you express "compare each row to a summary of the whole" — a pattern that's awkward otherwise. Customers above the average. Sales bigger than their region's typical sale. Reps who have at least one big deal. They also let you build a result, then query *that* result, composing logic in readable layers.

## See it

**Scalar subquery in WHERE** — customers... wait, this one fits sales better. Sales larger than the overall average sale:

```sql
SELECT sale_id, amount
FROM sales
WHERE amount > (SELECT AVG(amount) FROM sales);
```

The inner query computes one number — the average — and the outer query compares each sale to it.

**Nested subquery with IN** — customers who *have* made at least one sale, by checking membership in a list of customer IDs:

```sql
SELECT customer_name
FROM customers
WHERE customer_id IN (SELECT customer_id FROM sales);
```

**Subquery in FROM** — treat a summary as a temporary table, then query it. Here we first total each customer's spend, then keep the big spenders:

```sql
SELECT customer_id, total_spent
FROM (
  SELECT customer_id, SUM(amount) AS total_spent
  FROM sales
  GROUP BY customer_id
) AS spend_by_customer
WHERE total_spent > 10000;
```

The inner block builds a little table called `spend_by_customer`; the outer query filters it. (A subquery in FROM always needs an alias.)

**Subquery in SELECT** — compute a value per row. Show each customer with the company-wide average sale beside them for reference:

```sql
SELECT
  customer_name,
  (SELECT AVG(amount) FROM sales) AS company_avg
FROM customers;
```

**Correlated subquery with EXISTS** — customers who have made at least one sale over 1000. The inner query refers to `c.customer_id` from the outer row, so it checks each customer individually:

```sql
SELECT c.customer_name
FROM customers AS c
WHERE EXISTS (
  SELECT 1
  FROM sales AS s
  WHERE s.customer_id = c.customer_id     -- references the outer row
    AND s.amount > 1000
);
```

EXISTS stops as soon as it finds one match — it only cares *whether* a matching row exists, not how many.

### Nested vs correlated: a performance intuition

A plain **nested** subquery (no reference to the outer query) runs **once**. SQL computes it, holds the result, and reuses it for every outer row. Cheap.

A **correlated** subquery, because it depends on the current outer row, conceptually runs **once per outer row**. With many rows, that adds up. Modern databases often optimize these into joins behind the scenes, but the intuition holds: correlated subqueries can be costly, and a JOIN is frequently a faster way to express the same idea.

## Watch out

- **Scalar subqueries must return exactly one value.** If `(SELECT ...)` returns multiple rows where one is expected, you get an error. Add aggregation or tighten the filter.
- **IN with NULLs can surprise you.** If the subquery's list contains a NULL, `NOT IN` can return no rows unexpectedly. Prefer `NOT EXISTS` for "not in a list" checks. (More on NULL quirks in module 09.)
- **FROM-subqueries need an alias**, every time.
- **Correlated subqueries can be slow.** If one feels sluggish, try rewriting it as a JOIN.
- **EXISTS vs IN:** EXISTS is often clearer and faster for "does a related row exist?", especially with large inner result sets.

## Practice

1. Find every sale whose amount is greater than the average sale amount across all sales.
2. List the names of customers who have made at least one sale, using a subquery with IN or EXISTS.
3. Using a subquery in the FROM clause, find customers whose total spend exceeds 5,000.
4. List customers who have made at least one sale over 2,000, using a correlated subquery with EXISTS.

---
**Prev:** [Set Operations](./06-set-operations.md) · **Next:** [CASE & Conditional Logic](./08-case-conditional.md)
