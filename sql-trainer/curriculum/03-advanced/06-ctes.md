# Common Table Expressions (CTEs)

> Name a query result with `WITH`, then build on it like a stepping stone.

## The idea

As your questions get harder, your queries get longer — and nested subqueries start to read like a Russian doll: a query inside a query inside a query. By the time you reach the middle, you've forgotten what the outer layers were doing.

A **Common Table Expression**, written with the `WITH` keyword, fixes this. It lets you take a query, give it a **name**, and then refer to that name later as if it were a real table. Instead of nesting, you build *named stepping stones*, one after another, top to bottom.

Think of it like prepping ingredients before you cook. Rather than chopping the onions in the middle of stirring the sauce, you chop everything first, lay it out in labeled bowls, then assemble calmly. A CTE is a labeled bowl: "here's `regional_totals`, here's `top_customers`," each computed once, each ready to use.

You can define several CTEs in one `WITH`, separated by commas, and — crucially — **each can build on the ones before it**. This is *chaining*: CTE #2 reads from CTE #1, CTE #3 reads from #2. A messy, deeply-nested query becomes a clean, readable pipeline that you read like a recipe, step by step.

The result is the same data a subquery would give you. The win is **readability and reuse** — and, with chaining, the ability to express multi-step logic as a sequence instead of a knot.

## Why it matters

Code is read far more often than it's written. A subquery nested three deep is correct but nearly unreadable, and unreadable SQL is where bugs hide. CTEs turn that into a top-to-bottom story anyone can follow.

There's a reuse angle too. If you need the same intermediate result *twice* in one query, a subquery forces you to write it twice. A CTE you write once and reference by name as many times as you like.

And CTEs are the gateway to **recursion** (next module) — the only way to express hierarchies and sequences in SQL, and it starts with `WITH`.

## See it

Find customers whose total spend is above the overall average — written as a readable two-step pipeline:

```sql
WITH customer_totals AS (
  SELECT customer_id, SUM(amount) AS total_spent
  FROM sales
  GROUP BY customer_id
)
SELECT customer_id, total_spent
FROM customer_totals
WHERE total_spent > (SELECT AVG(total_spent) FROM customer_totals);
```

Notice `customer_totals` is *defined once* and *used twice* — once in the main query, once in the subquery — with no repetition.

**Chaining** multiple CTEs, each feeding the next:

```sql
WITH monthly AS (
  SELECT DATE_TRUNC('month', sale_date) AS month, SUM(amount) AS total
  FROM sales
  GROUP BY DATE_TRUNC('month', sale_date)
),
ranked AS (
  SELECT month, total,
         RANK() OVER (ORDER BY total DESC) AS r
  FROM monthly
)
SELECT month, total
FROM ranked
WHERE r <= 3;
```

Read it like steps: first roll sales up by month, then rank the months, then keep the top three. Each CTE is a clear stage.

### CTE vs subquery vs view

- **Subquery** — defined *inline*, used right where it sits. Great for one-off, throwaway logic. Hard to reuse; gets unreadable when nested.
- **CTE** — named, lives at the top of *one* statement, can be referenced multiple times and chained. Vanishes when the query ends.
- **View** — a CTE-like definition saved permanently in the database, reusable across *many* queries by *many* people. Reach for a view when the logic is worth keeping around.

Rough rule: throwaway and tiny → subquery; multi-step or reused within one query → CTE; reused across queries over time → view.

## Watch out

- **A CTE only lives for its statement.** Once the query finishes, the name is gone. For something permanent, create a view.
- **Order of definition matters when chaining.** A CTE can only reference CTEs defined *above* it, not below.
- **CTEs aren't automatically faster.** They're about clarity. Some engines materialize them (compute once, store) and some inline them; performance varies — measure, don't assume.
- **Don't over-fragment.** Ten one-line CTEs can be *harder* to follow than two well-named ones. Group logically.

## Practice

1. In your own words, explain when you'd choose a CTE over a plain subquery, and when you'd promote it to a view.
2. Rewrite a nested subquery you find awkward as a `WITH` clause and judge whether it reads better.
3. Write two chained CTEs: one that totals sales per rep, and one that keeps only reps above the average rep total.
4. Define a single CTE and reference it twice in the same query without repeating its logic.

---
**Prev:** [Window Frames](./05-window-frames.md) · **Next:** [Recursive CTEs](./07-recursive-ctes.md)
