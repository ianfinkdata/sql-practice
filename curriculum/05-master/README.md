# Tier 5 — Master

The capstone: dimensional modeling and star schema design. This is the tier meant to outlive this repo — a portable, professional data-modeling skillset (dimensions, facts, grain, SCD, star vs. snowflake) capped by a full medallion-pipeline recap, a graded capstone, and a portability reference for taking these patterns to Snowflake, BigQuery, Databricks, or Postgres.

| Module | Topic |
|---|---|
| [01](01-why-model-data-oltp-vs-analytical.md) | Why model data: OLTP vs. analytical modeling |
| [02](02-dimensions-and-facts-core-vocabulary.md) | Dimensions and facts: core vocabulary |
| [03](03-grain-the-most-important-decision.md) | Grain: the most important decision in a star schema |
| [04](04-designing-a-dimension.md) | Designing a dimension |
| [05](05-slowly-changing-dimensions-scd-1-and-2.md) | Slowly Changing Dimensions (Types 1 & 2) |
| [06](06-designing-the-date-dimension.md) | Designing the date dimension |
| [07](07-designing-the-fact-table.md) | Designing the fact table |
| [08](08-star-vs-snowflake-schema.md) | Star vs. snowflake schema |
| [09](09-medallion-pipeline-recap.md) | Medallion thread: the full pipeline, recapped end to end |
| [10](10-capstone-build-a-novel-gold-view.md) | Capstone: build a novel gold view from scratch |
| [11](11-beyond-sqlite-portability-notes.md) | Beyond SQLite: a syntax-translation reference |

Matching exercises: [`exercises/05-master/`](../../exercises/05-master/). See also the standalone [`portfolio/`](../../portfolio/) pattern library this tier feeds into.

Previous: [Tier 4 — Expert](../04-expert/README.md).
