# Tier 4 — Expert: Building and Tuning

Welcome back. It's Sage again.

Until now you've been a *reader* of databases — asking well-crafted questions and getting answers. This tier flips the table. You'll stop just querying and start **building and tuning**: designing the tables themselves, changing data safely, protecting it with transactions, and making queries fast. This is where you go from someone who *uses* a database to someone who can *shape* one.

The same patient, plain-English approach holds throughout. Every idea is explained in words and analogies first, with a minimal example only when code genuinely clarifies. The leap here is real, but you're ready for it — take the modules in order, and try the practice prompts, because building skills stick when you actually build.

We keep using the same four sample tables, so nothing new to memorize:

- `customers(customer_id, customer_name, region, signup_date, email)`
- `sales(sale_id, sale_date, customer_id, rep_id, amount)`
- `sales_rep(rep_id, rep_name, commission_rate, hire_date)`
- `products(product_id, product_name, category, unit_price)`

## The modules

1. **[Creating Tables: DDL and Constraints](01-ddl-tables.md)** — Define tables with `CREATE TABLE`, choose the right data types, and enforce data quality with `NOT NULL`, `DEFAULT`, primary and foreign keys, `UNIQUE`, and `CHECK`; reshape with `ALTER TABLE`.
2. **[Changing Data: DML](02-dml.md)** — Add, modify, and remove rows with `INSERT`, `UPDATE`, and `DELETE`; the difference between `DELETE` and `TRUNCATE`; and clean upserts (`MERGE` / `ON CONFLICT`).
3. **[Transactions and ACID](03-transactions.md)** — Group changes into all-or-nothing units with `BEGIN`/`COMMIT`/`ROLLBACK` and `SAVEPOINT`, explained through the classic bank-transfer story.
4. **[Isolation and Concurrency](04-isolation-concurrency.md)** — Isolation levels, dirty/non-repeatable/phantom reads, locking versus MVCC, and how deadlocks happen and get resolved.
5. **[Views and Materialized Views](05-views.md)** — Save queries as reusable virtual tables, or store their results for speed; when to use each, updatable views, and refresh strategies.
6. **[Indexes](06-indexes.md)** — The back-of-the-book analogy: B-trees, when an index helps, composite-index column order, covering indexes, and the cost indexes impose on writes.
7. **[Reading Query Plans](07-query-plans.md)** — Read `EXPLAIN` and `EXPLAIN ANALYZE`: scan types, join strategies, and the all-important gap between estimated and actual rows.
8. **[Query Optimization](08-query-optimization.md)** — Practical habits: sargable predicates, avoiding `SELECT *`, filtering early, keeping functions off indexed columns, and when denormalizing pays off.
9. **[Procedures, Functions, and Triggers](09-procedures-triggers.md)** — Put logic inside the database with stored procedures, user-defined functions, and triggers — and the judgment to know when *not* to.
10. **[JSON and Semi-Structured Data](10-json-semistructured.md)** — Store and query flexible nested data: extraction operators, arrays and structs, and choosing JSON versus real columns.

Work through them in order — design comes before changing data, which comes before protecting it, which comes before making it fast. When you finish module 10, you'll be ready for the master tier.

---
**Prev:** [Tier 3: Advanced](../03-advanced/) · **Next:** [Tier 5: Master](../05-master/)
