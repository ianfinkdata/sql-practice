# Tier 5 — Master: Design & Architecture

> You can write SQL, tune it, and bend it to your will. Now you learn to *design the systems* it runs in.

Every tier before this made you a better *user* of databases. This one makes you a *designer* of them. The shift is from "how do I get this answer?" to "how should this whole system be shaped so the answers come easily, correctly, and fast — for everyone, for years?"

That means thinking in systems. You'll model data three ways before touching a database. You'll build warehouses analysts love, track history without lying about the past, layer raw data into something trustworthy, and split billions of rows so they fly. You'll learn the mistakes that look reasonable, and you'll learn to read the engine beneath your SQL like a mechanic reads an engine. Code gets sparse here — much of mastery is judgment, drawn in diagrams, tables, and plain English. That's the point.

Take your time. This tier rewards reflection over speed.

## The modules

1. **[Data Modeling](./01-data-modeling.md)** — Conceptual, logical, and physical models; normalization (1NF/2NF/3NF) by intuition; when to normalize and when to denormalize.
2. **[Dimensional Modeling](./02-dimensional-modeling.md)** — Facts vs. dimensions, grain, surrogate keys, star vs. snowflake, and the Kimball approach in plain English.
3. **[Slowly Changing Dimensions](./03-slowly-changing-dimensions.md)** — Tracking the history of a dimension: SCD types 1/2/3 (with a note on 4/6), effective dates, current-row flags, and the MERGE pattern.
4. **[Medallion Architecture](./04-medallion-architecture.md)** — Bronze → silver → gold layering, raw to cleaned to business-ready, the lakehouse context, mapped onto views you've already built.
5. **[Partitioning & Distribution](./05-partitioning-distribution.md)** — How big systems split data for speed: partitioning, clustering, bucketing, distribution, partition pruning, and data skew.
6. **[Performance at Scale](./06-performance-at-scale.md)** — Statistics, pruning, predicate pushdown, broadcast vs. shuffle joins, small files, skew, and caching/materialization trade-offs.
7. **[Anti-Patterns](./07-anti-patterns.md)** — The mistakes that look reasonable — SELECT *, implicit conversions, N+1 subqueries, over-indexing, EAV, god-tables, NULL misuse, non-sargable filters — and how to refactor each.
8. **[Dialect Mastery](./08-dialect-mastery.md)** — Knowing your engine: row-store vs. column-store, OLTP vs. OLAP, how Oracle/MySQL/Postgres/Databricks differ, and what that means for how you write SQL.
9. **[Capstone Projects](./09-capstone-projects.md)** — Four substantial briefs that braid the whole curriculum into systems you design end to end.

---
**Prev:** [Tier 4: Expert](../04-expert/) · **Next:** [Back to the Curriculum](../README.md)

**You've reached the end of the path. Congratulations — you don't just use databases now; you design them.**
