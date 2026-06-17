# Query Optimization

> Practical habits that let the database use its indexes, touch fewer rows, and do less work — for the same answer.

## The idea

Optimization isn't about clever tricks; it's about not getting in the database's way. The planner is smart, but you can accidentally tie its hands. The goal is to write queries that let it do the fast thing. A handful of habits cover most of the wins.

**Keep your filters "sargable."** That ugly word just means "able to use an index." A predicate is sargable when the column sits alone on one side of the comparison, untouched. `WHERE sale_date >= DATE '2026-01-01'` is sargable — the index on `sale_date` can be used. `WHERE YEAR(sale_date) = 2026` is *not* — by wrapping the column in a function, you've forced the database to compute `YEAR(...)` for every single row, scanning them all. Rewrite it as a range and the index comes back to life.

**Don't ask for columns you won't use.** `SELECT *` drags back every column, which means more data read, more memory, and often a missed chance at an index-only scan. Name the columns you actually need.

**Filter early, and filter hard.** The fewer rows that survive into a join or a sort, the less work everything downstream has to do. Push your `WHERE` conditions as close to the raw tables as you can, so the database eliminates rows before the expensive steps, not after.

**Help the join order.** Join on indexed key columns, and prefer joining small results to large ones rather than building a giant intermediate result first. Modern planners reorder joins themselves, but giving them good indexes and tight filters makes their job possible.

**Keep functions off indexed columns** in your `WHERE` and `JOIN` conditions — the same point as sargability, worth repeating because it's the most common cause of a "why isn't my index used?" surprise. If you truly need the function, many engines let you build an index *on the expression* instead.

And sometimes the right answer isn't a faster query but a different shape of data. **Denormalization** — deliberately storing redundant or precomputed data — can eliminate an expensive join entirely. It's a trade: faster reads in exchange for more storage and the burden of keeping the duplicate in sync. Reach for it when a hot query is provably bottlenecked on a join you can't otherwise speed up.

## Why it matters

The same answer can take 30 milliseconds or 30 seconds depending on how the query is written. These habits are cheap to learn and pay off on nearly every query you'll ever write. They're also the difference between throwing more hardware at a problem and simply letting the indexes you already have do their job.

## See it

Make a filter sargable — let the index on `sale_date` work:

```sql
-- Slow: function on the column scans every row
SELECT sale_id, amount FROM sales WHERE YEAR(sale_date) = 2026;

-- Fast: a range the index can satisfy
SELECT sale_id, amount
FROM sales
WHERE sale_date >= DATE '2026-01-01'
  AND sale_date <  DATE '2027-01-01';
```

Name your columns and filter before joining:

```sql
SELECT s.sale_id, c.customer_name, s.amount
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.amount > 1000          -- cuts sales down before the join
  AND c.region = 'West';
```

Denormalize a hot aggregate by storing a running total on the customer, so a dashboard skips the join-and-sum entirely:

```sql
ALTER TABLE customers ADD COLUMN lifetime_spend DECIMAL(12,2) DEFAULT 0;
-- kept in sync by your application or a trigger whenever a sale is inserted
```

> **Dialect note:** Expression indexes (to rescue a needed function) and the exact function names differ — PostgreSQL `CREATE INDEX ON sales (date_trunc('year', sale_date))`, SQL Server computed columns, Oracle function-based indexes. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Functions on the filtered column kill index use.** This is the number-one cause of slow queries. Rewrite to a range, or build an expression index.
- **`SELECT *` is a habit to break in real queries.** Ask only for the columns you need; it's faster and survives schema changes better.
- **Optimize with evidence, not vibes.** Use `EXPLAIN ANALYZE` to confirm a change actually helped — intuition about what's slow is often wrong.
- **Denormalization adds a duty.** Every redundant copy must be kept in sync, or your data quietly drifts out of agreement. Don't do it casually.
- **`OR` across different columns can block index use;** sometimes a `UNION` of two indexed queries is faster. Check the plan.
- **Beware implicit type mismatches.** Comparing a number column to a string (`WHERE customer_id = '101'`) can force a conversion that disables the index.

## Practice

1. Rewrite `WHERE upper(region) = 'WEST'` so it can use an ordinary index on `region`, and explain why your version is sargable.
2. Take a query that does `SELECT *` from a wide table and list two concrete reasons naming the columns could make it faster.
3. A dashboard joins `sales` to `customers` and sums amounts on every page load, and it's slow. Describe a denormalization that would speed it up and the maintenance cost it introduces.
4. Explain, in plain English, why filtering rows *before* a join generally beats filtering after it.

---
**Prev:** [Reading Query Plans](07-query-plans.md) · **Next:** [Procedures, Functions, and Triggers](09-procedures-triggers.md)
