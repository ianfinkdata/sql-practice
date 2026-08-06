# Tier 4 — Expert

> **BLUF (Bottom Line Up Front):** Tier 4 covers data engineering tooling: DDL schema design, transactions, views vs. physical tables, index tuning (`EXPLAIN QUERY PLAN`), data constraints, and building Gold-layer views.

<!-- nav -->
[⏮️ Prev: Tier 3 Advanced](../03-advanced/README.md) | [📖 Table of Contents](../../README.md) | [⏭️ Next: Tier 5 Master](../05-master/README.md)
<!-- /nav -->

DDL, transactions, views, indexes, and query optimization — the tooling behind the pipeline, not just the queries. Module 7 uses Oakhaven's real orphan foreign keys to motivate constraints; module 8 has you write your first gold-layer view.

| Module | Topic |
|---|---|
| [01](01-ddl-basics-and-type-affinity.md) | DDL basics, SQLite type affinity |
| [02](02-alter-table-and-schema-evolution.md) | ALTER TABLE and schema evolution |
| [03](03-transactions.md) | Transactions: BEGIN/COMMIT/ROLLBACK |
| [04](04-views.md) | Views — why silver/gold are views, not tables |
| [05](05-indexes-and-explain-query-plan.md) | Indexes and EXPLAIN QUERY PLAN |
| [06](06-query-optimization-basics.md) | Query optimization basics |
| [07](07-constraints-and-data-integrity.md) | Constraints and data integrity |
| [08](08-writing-your-first-gold-view.md) | Medallion thread: writing your first gold view |
| [09](09-portable-idempotent-ddl-patterns.md) | Portable, idempotent DDL patterns |

Matching exercises: [`exercises/04-expert/`](../../exercises/04-expert/).

---

<!-- nav -->
[⏮️ Prev: Tier 3 Advanced](../03-advanced/README.md) | [📖 Table of Contents](../../README.md) | [⏭️ Next: Tier 5 Master](../05-master/README.md)
<!-- /nav -->
