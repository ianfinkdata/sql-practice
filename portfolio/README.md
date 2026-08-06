# portfolio/ — the reusable SQL pattern library

> **BLUF (Bottom Line Up Front):** The Portfolio library is an engine-agnostic collection of production SQL design patterns (Bronze ingestion, Silver cleaning, Dimensional modeling, Analytical queries, and Cloud Portability) verified against `oakhaven.db` and ready for Snowflake, BigQuery, Databricks, and Postgres.

<!-- nav -->
[⏮️ Prev: Exercises Workbook](../exercises/README.md) | [📖 Table of Contents](../README.md) | [⏮️ Back to Home](../README.md)
<!-- /nav -->

This directory is the **takeaway artifact** of the sql-practice repo:
standalone, heavily annotated SQL files organized by *pattern*, not by
curriculum tier. Every file is written to be lifted whole into a
completely different project on a completely different SQL engine —
these are the recipes that make up most medallion-architecture lakehouses
(bronze → silver → gold), independent of any particular business domain.

## How this relates to the rest of the repo

- `project/` is the fictional Oakhaven outdoor-gear retailer's actual
  database and its bronze/silver/gold build scripts — the ground truth
  this library generalizes *from*.
- `curriculum/`/`exercises/` (owned by other parts of this repo) teach the
  Oakhaven schema tier-by-tier, as lessons.
- `portfolio/` (this directory) is neither of those. It doesn't teach
  Oakhaven — it extracts the *general, engine-agnostic pattern* behind
  each Oakhaven-specific technique, verifies that pattern really works
  against `project/oakhaven.db`, and documents how the same pattern would
  read on Snowflake, BigQuery, Databricks, or Postgres. Every file here
  should make sense to someone who has never heard of Oakhaven and never
  will — the Oakhaven example is evidence the pattern works, not the
  point of the file.

## How to use a file

Every `.sql` file opens with a structured header comment:

1. **Pattern name** and the one-sentence problem it solves.
2. **When to reach for it** — the situations that should make you think
   "this is that pattern."
3. **How it works** — the mechanics, in prose, before you read the SQL.
4. **A real, verified example** against `oakhaven.db`, including an actual
   sample of the output (not invented — every query in this library was
   run against the real database).
5. **Portability** — what changes (or doesn't) on Snowflake, BigQuery,
   Databricks, and Postgres.

Then the file itself is runnable `SELECT`-only SQL you can paste into any
SQLite session with `oakhaven.db` attached and get the shown output back.
A few files also include illustrative `CREATE VIEW`/`INSERT`/`MERGE`
statements in comments, for the "here's how you'd wire this into a real
pipeline" step — those are reference text, not statements meant to be run
against the shared database.

## Table of contents

### 01 — Bronze ingestion patterns
Finding and flagging problems in raw, as-landed data.

- [`deduplication-with-row-number.sql`](01-bronze-ingestion-patterns/deduplication-with-row-number.sql) — `ROW_NUMBER()` to find and rank near-duplicate entities by a normalized key (the real 30 near-duplicate Oakhaven customers).
- [`detecting-orphan-foreign-keys.sql`](01-bronze-ingestion-patterns/detecting-orphan-foreign-keys.sql) — `LEFT JOIN ... WHERE ... IS NULL` (and the `NOT EXISTS` equivalent) to find child rows whose foreign key doesn't resolve to any parent row.

### 02 — Silver cleaning patterns
Turning messy, inconsistent TEXT columns into trustworthy typed data.

- [`standardizing-mixed-booleans.sql`](02-silver-cleaning-patterns/standardizing-mixed-booleans.sql) — collapsing a Y/N/yes/no/true/false/1/0 text pool into a real 0/1 column.
- [`standardizing-inconsistent-categoricals.sql`](02-silver-cleaning-patterns/standardizing-inconsistent-categoricals.sql) — collapsing 40 raw casing/spacing variants of a category column down to its true 8 canonical values.
- [`recompute-dont-trust-the-total.sql`](02-silver-cleaning-patterns/recompute-dont-trust-the-total.sql) — recomputing a derived measure (`net_amount`) from source columns instead of trusting a stored, drifted total; includes the discount-percent whole-number scale bug.
- [`type-casting-and-validation.sql`](02-silver-cleaning-patterns/type-casting-and-validation.sql) — parsing a finite set of mixed date formats to ISO 8601, and parsing dirty numeric-as-text values with inconsistent unit suffixes.

### 03 — Date dimension patterns
Building and using a date spine.

- [`recursive-cte-calendar-generation.sql`](03-date-dimension-patterns/recursive-cte-calendar-generation.sql) — generating a gap-free date spine entirely in SQL via `WITH RECURSIVE`, no external loop needed.
- [`date-spine-left-join-zero-activity-days.sql`](03-date-dimension-patterns/date-spine-left-join-zero-activity-days.sql) — driving a rollup FROM the date dimension so zero-activity days appear as real rows instead of silently disappearing.
- [`fiscal-calendar-derivations.sql`](03-date-dimension-patterns/fiscal-calendar-derivations.sql) — deriving year/month/quarter/day-of-week/is_weekend from a date column, plus how to layer a fiscal-year offset on top.

### 04 — Dimensional modeling patterns
Building the dimension and fact layer of a star schema.

- [`conformed-dimension-scd-type-1.sql`](04-dimensional-modeling-patterns/conformed-dimension-scd-type-1.sql) — the default "overwrite in place, one shared dimension" pattern most tables should use.
- [`scd-type-2-history-tracking.sql`](04-dimensional-modeling-patterns/scd-type-2-history-tracking.sql) — versioned dimension rows with a validity window, for attributes where "what was true at the time" matters.
- [`star-schema-fact-table-template.sql`](04-dimensional-modeling-patterns/star-schema-fact-table-template.sql) — a fact table checklist: grain declaration, unvalidated FK pass-through, trustworthy measures, explicit orphan/NULL handling.
- [`surrogate-key-generation.sql`](04-dimensional-modeling-patterns/surrogate-key-generation.sql) — `ROW_NUMBER()`-based synthetic keys, and how each engine's native identity/autoincrement/sequence mechanism compares.

### 05 — Analytical query patterns
Common reporting/BI query shapes on top of a built star schema.

- [`running-totals-and-moving-averages.sql`](05-analytical-query-patterns/running-totals-and-moving-averages.sql) — cumulative sums and N-period moving averages via window function frame clauses.
- [`period-over-period-with-lag.sql`](05-analytical-query-patterns/period-over-period-with-lag.sql) — `LAG()` for month-over-month (or any period-over-period) absolute and percent change.
- [`cohort-analysis.sql`](05-analytical-query-patterns/cohort-analysis.sql) — signup-month cohorts and months-since-acquisition alignment.
- [`customer-lifetime-value.sql`](05-analytical-query-patterns/customer-lifetime-value.sql) — a dimension-driven LTV rollup that keeps zero-activity entities visible.
- [`top-n-per-group.sql`](05-analytical-query-patterns/top-n-per-group.sql) — `ROW_NUMBER() OVER (PARTITION BY ...)` for "top N per group" instead of a global top N.

### 06 — Portability notes

- [`sqlite-vs-snowflake-bigquery-databricks-postgres.md`](06-portability-notes/sqlite-vs-snowflake-bigquery-databricks-postgres.md) — the consolidated cross-engine reference: date functions, `QUALIFY`, `MERGE`/upsert, `CREATE OR REPLACE VIEW`, identity/autoincrement/sequences, and type-system gotchas.

## Verification

Every query in this library was run against `project/oakhaven.db`
(SQLite 3.46.1) via `sqlite3 project/oakhaven.db "..." -header -column`,
and every numeric claim in a header comment (row counts, percentages,
sample rows) is copied from that real output — nothing here is invented
or approximated. Where a file's header cites a count from
`project/docs/facts_sheet.md`, that figure was independently
re-verified against the live database as part of writing this library,
not merely copied from the doc.

---

<!-- nav -->
[⏮️ Prev: Exercises Workbook](../exercises/README.md) | [📖 Table of Contents](../README.md) | [⏮️ Back to Home](../README.md)
<!-- /nav -->
