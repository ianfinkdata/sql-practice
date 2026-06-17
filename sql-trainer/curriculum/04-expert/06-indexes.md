# Indexes

> An index is a sorted lookup structure that lets the database find rows fast — at a small cost on every write.

## The idea

Imagine a 600-page reference book with no index in the back. To find every mention of "phantom read," you'd read all 600 pages cover to cover. That's exactly what a database does without an index: a **full table scan**, looking at every row to find the few you want. Now picture the index at the back of the book — terms sorted alphabetically, each pointing to the right pages. You flip straight to "P," find your term, jump to the pages. Seconds, not hours.

A database **index** is that back-of-the-book index. You build one on a column (say `customer_id`), and the database keeps a sorted structure mapping each value to the rows that hold it. When you filter or join on that column, it jumps straight to the matching rows instead of scanning everything.

The usual structure is a **B-tree** — a balanced tree kept in sorted order. You don't need the internals; just the intuition: it lets the database zero in on a value, or a *range* of values, in a handful of steps rather than millions. That's why B-tree indexes shine for equality (`= 101`), ranges (`BETWEEN`, `<`, `>`), and sorting.

A few ideas make indexes genuinely powerful:

- **Composite indexes** cover more than one column, in a specific order — like a phone book sorted by last name, *then* first name. That order matters enormously. A `(last, first)` index helps you find "everyone named Nakamura" and "Nakamura, Theo," but it does *not* help you find "everyone named Theo," because the book isn't sorted by first name. The rule of thumb: put the column you filter on most exactly (equality) first, ranges last.
- **Covering indexes** include every column a query needs, so the database answers from the index alone without ever touching the table. The fastest kind of read.

But indexes aren't free. Every index is a second structure the database must keep in sync. So every `INSERT`, `UPDATE`, or `DELETE` now has to update the table *and* every index on it. Indexes make reads faster and writes slower. That's the central trade-off.

## Why it matters

Indexes are the single biggest lever you have over query speed. The difference between a query that scans ten million rows and one that jumps to a hundred is often the difference between a 30-second page load and an instant one. But more is not better — over-indexing a write-heavy table can quietly throttle it, and unused indexes just waste space and slow every insert. Knowing *which* index to build, and which not to, is core tuning skill.

## See it

A simple index to speed up lookups and joins on customer:

```sql
CREATE INDEX idx_sales_customer ON sales (customer_id);
```

A composite index — column order chosen for the queries you actually run. This helps filters on `customer_id` alone, and on `customer_id` + a `sale_date` range:

```sql
CREATE INDEX idx_sales_cust_date ON sales (customer_id, sale_date);
```

A unique index, which also enforces no duplicates:

```sql
CREATE UNIQUE INDEX idx_customers_email ON customers (email);
```

After indexing, this query can jump straight to the rows instead of scanning the table:

```sql
SELECT sale_id, amount
FROM sales
WHERE customer_id = 101 AND sale_date >= DATE '2026-01-01';
```

> **Dialect note:** PostgreSQL offers several index types beyond B-tree (GIN, GiST, BRIN, hash) for special cases; MySQL/InnoDB clusters the table on its primary key; SQL Server distinguishes clustered from nonclustered indexes. The `CREATE INDEX` basics are standard. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Don't index everything.** Each index slows writes and uses storage. Index the columns you actually filter, join, and sort on.
- **Column order in composite indexes is decisive.** Equality columns first, range columns last. The wrong order means the index goes unused.
- **A leading-column rule applies.** An index on `(a, b)` helps queries on `a` or `a, b`, but usually not on `b` alone.
- **Functions on the column defeat the index.** `WHERE upper(region) = 'WEST'` can't use a plain index on `region` (see the next two modules).
- **Indexes need maintenance.** They can bloat or grow fragmented over time; very write-heavy tables may need periodic rebuilds.
- **Low-cardinality columns rarely benefit.** Indexing a boolean or a 3-value `region` often isn't worth it — half the table still matches.

## Practice

1. A report constantly filters `sales` by `rep_id` and then sorts by `sale_date`. Propose a composite index and justify the column order.
2. Explain, using the phone-book analogy, why an index on `(region, signup_date)` won't help a query that filters only on `signup_date`.
3. A table gets thousands of inserts per minute but is rarely read. Discuss whether adding three new indexes is a good idea.
4. Describe what a "covering index" is and why a query it covers can be faster than one that uses an ordinary index.

---
**Prev:** [Views and Materialized Views](05-views.md) · **Next:** [Reading Query Plans](07-query-plans.md)
