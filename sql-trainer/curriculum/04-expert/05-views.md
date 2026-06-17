# Views and Materialized Views

> Save a query under a name you can reuse — either as a live window onto the data, or as a stored snapshot.

## The idea

Suppose you keep writing the same long query: every active customer in the West with their total sales, joined three ways, filtered just so. Retyping it is tedious and error-prone. A **view** lets you save that query under a friendly name and then treat it like a table. From then on you can `SELECT * FROM west_top_customers` and the database quietly runs the underlying query for you.

A plain view is a **virtual table**. It stores no data of its own — it's a saved question, not a saved answer. Think of it like a recipe card: every time you "make" it, you re-cook from fresh ingredients. So a view is always perfectly up to date, but it costs the full query every time you read it.

A **materialized view** is the opposite trade. It runs the query *once* and stores the actual result rows on disk, like cooking the dish ahead and putting it in the fridge. Reading it is now instant — you're just grabbing the leftovers. The catch: the leftovers go stale. When the underlying data changes, the materialized view doesn't update itself; you have to **refresh** it, which re-runs the query and replaces the stored rows.

So the choice is simple to state:

- Reach for a **plain view** when you want a tidy, always-current shortcut and the underlying query is cheap enough to run on demand.
- Reach for a **materialized view** when the query is expensive (big joins, heavy aggregation), you read it often, and you can tolerate the data being a little behind.

A nice bonus: some plain views are **updatable**. If a view is a simple window onto one table, you can `INSERT`, `UPDATE`, or `DELETE` through it, and the changes land on the real table. Once a view gets complicated — joins, aggregates, `DISTINCT` — it becomes read-only, because the database can't tell which underlying rows your change should touch.

## Why it matters

Views are how you give people clean, safe, consistent access to data. You can expose a view that hides sensitive columns, encodes the "correct" join logic once so every report agrees, or presents a simplified shape to a reporting tool. Materialized views are a workhorse of analytics: precomputing a nightly summary so a dashboard loads in milliseconds instead of grinding through millions of rows on every page view.

## See it

A plain view — a reusable, always-current shortcut:

```sql
CREATE VIEW west_customer_totals AS
SELECT c.customer_id, c.customer_name, SUM(s.amount) AS total_spent
FROM customers c
JOIN sales s ON s.customer_id = c.customer_id
WHERE c.region = 'West'
GROUP BY c.customer_id, c.customer_name;

SELECT * FROM west_customer_totals WHERE total_spent > 5000;
```

A materialized view — the same query, but stored, for a heavy dashboard:

```sql
CREATE MATERIALIZED VIEW monthly_sales AS
SELECT date_trunc('month', sale_date) AS month, SUM(amount) AS revenue
FROM sales
GROUP BY date_trunc('month', sale_date);

-- later, after new sales arrive, bring it up to date:
REFRESH MATERIALIZED VIEW monthly_sales;
```

> **Dialect note:** Materialized views vary widely. PostgreSQL has `CREATE MATERIALIZED VIEW` with manual `REFRESH` (or `REFRESH ... CONCURRENTLY`); Oracle supports automatic refresh schedules and even incremental "fast refresh"; MySQL has no built-in materialized views (people emulate them with tables and scheduled jobs); SQL Server uses indexed views. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **A plain view does no caching.** Querying it re-runs the full underlying query every time. If that's slow, a view won't make it faster — you may want a materialized one.
- **Materialized views go stale.** Their data is only as fresh as your last `REFRESH`. Don't use one where users expect up-to-the-second numbers.
- **Refreshing can be expensive and can lock readers** unless your engine supports a concurrent/online refresh. Schedule heavy refreshes for quiet hours.
- **Complex views aren't updatable.** Anything with a join, aggregate, or `DISTINCT` is read-only; write to the base tables instead.
- **Views can hide cost.** A view built on three other views built on big joins is one innocent-looking `SELECT` that fans out into a monster query. Know what's underneath.

## Practice

1. Create a plain view that shows each sales rep's name alongside their total sales amount, and explain why it's always current.
2. Decide whether a dashboard tile showing "total revenue this year, updated nightly" should be a view or a materialized view, and justify it.
3. Describe what happens to a materialized view's results when 500 new sales are inserted but no refresh is run.
4. Explain in plain English why a view that joins `customers` and `sales` can't be used to `INSERT` a new sale.

---
**Prev:** [Isolation and Concurrency](04-isolation-concurrency.md) · **Next:** [Indexes](06-indexes.md)
