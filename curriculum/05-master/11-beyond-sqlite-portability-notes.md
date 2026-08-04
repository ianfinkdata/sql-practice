# 11. Beyond SQLite: Portability Notes


<!-- nav -->
Previous: [10. Capstone: Design a Novel Gold View](10-capstone-build-a-novel-gold-view.md). Next: [Portfolio](../../portfolio/README.md).
<!-- /nav -->

## The idea

Everything in this tier — grain, star schemas, medallion layering,
building a novel gold view — is dimensional-modeling knowledge that
transfers directly to Snowflake, BigQuery, Databricks, and Postgres.
What *doesn't* transfer directly is SQLite-specific syntax. This module
is a practical translation reference: the handful of places where the
SQL you've been writing in this repo needs to change shape to run on a
production warehouse engine, and why those differences exist.

Treat this as a reference to come back to, not something to memorize.
The goal is knowing these differences exist and where to look them up
— not having every dialect's syntax memorized.

## Date truncation

SQLite has no `DATE_TRUNC`. This repo has been using `strftime()` and
`date()` with modifiers instead — patterns like `fact_sales`'s
`CAST(strftime('%Y%m%d', s.order_date) AS INTEGER) AS datekey` or
`dim_date`'s `CAST(strftime('%Y', date) AS INTEGER) AS year`.

| Task | SQLite | Snowflake / Postgres / Databricks | BigQuery |
|---|---|---|---|
| Truncate to month | `date(d, 'start of month')` | `DATE_TRUNC('month', d)` | `DATE_TRUNC(d, MONTH)` |
| Extract year | `CAST(strftime('%Y', d) AS INTEGER)` | `EXTRACT(YEAR FROM d)` | `EXTRACT(YEAR FROM d)` |
| Format as `YYYY-MM` | `strftime('%Y-%m', d)` | `TO_CHAR(d, 'YYYY-MM')` (Snowflake/Postgres) | `FORMAT_DATE('%Y-%m', d)` |
| Date-key integer (`YYYYMMDD`) | `CAST(strftime('%Y%m%d', d) AS INTEGER)` | `TO_NUMBER(TO_CHAR(d, 'YYYYMMDD'))` | `CAST(FORMAT_DATE('%Y%m%d', d) AS INT64)` |

`DATE_TRUNC` is the pattern to reach for once you leave SQLite — it's
supported (with minor argument-order differences) on Snowflake,
Postgres, Databricks, and BigQuery, and it's generally clearer than
chaining `strftime`/`date` modifiers.

## `QUALIFY`: window-function filtering

SQLite has no `QUALIFY` clause — confirmed by running one against
`project/oakhaven.db`:

```sql
SELECT customer_id FROM dim_customer QUALIFY ROW_NUMBER() OVER (ORDER BY customer_id) = 1;
```

```
Error: in prepare, near "ROW_NUMBER": syntax error
```

`QUALIFY` (available on Snowflake, BigQuery, and Databricks — not
standard Postgres) lets you filter on a window function's result
directly in the `WHERE`-clause position, instead of wrapping the whole
query in a subquery/CTE just to filter on a column computed by
`ROW_NUMBER()`/`RANK()`/etc. The `ROW_NUMBER()`-based deduplication
pattern from earlier in this tier (deduping the near-duplicate
customers 571–600 by `LOWER(TRIM(email))`) needs a CTE wrapper in
SQLite for exactly this reason:

```sql
-- SQLite: needs an outer query/CTE to filter on a window function
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) AS rn
    FROM dim_customer
)
SELECT * FROM ranked WHERE rn = 1;
```

```sql
-- Snowflake/BigQuery/Databricks: QUALIFY does it in one query, no CTE needed
SELECT *
FROM dim_customer
QUALIFY ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) = 1;
```

Both produce the same result. `QUALIFY` is strictly a convenience —
know the CTE-wrapper version works everywhere (including SQLite), and
reach for `QUALIFY` as a shortcut on engines that support it.

## `MERGE` / upsert syntax

SQLite has no `MERGE` statement. It has `INSERT ... ON CONFLICT ... DO
UPDATE` (SQLite 3.24+), which handles the same single-row-at-a-time
upsert case:

```sql
INSERT INTO some_table (id, v) VALUES (1, 'b')
ON CONFLICT(id) DO UPDATE SET v = excluded.v;
```

Production warehouses use a `MERGE` statement that can match/update/insert
across an entire *set* at once — the pattern you'd actually use to load
an incremental batch into a silver or gold table:

```sql
-- Snowflake / Databricks / Postgres 15+ (syntax varies slightly by engine)
MERGE INTO dim_customer AS target
USING staged_customers AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN UPDATE SET target.state = source.state, target.is_active = source.is_active
WHEN NOT MATCHED THEN INSERT (customer_id, state, is_active) VALUES (source.customer_id, source.state, source.is_active);
```

This repo never needed `MERGE` because every silver/gold object here is
a `DROP VIEW IF EXISTS ...; CREATE VIEW ...;` (rebuilt fresh from bronze
every run — see module 9). Real production pipelines are usually
*incremental*: only new/changed bronze rows arrive each run, and silver
or gold tables are updated in place with `MERGE` rather than fully
rebuilt. That's a real difference in mechanics between a learning repo
and a production pipeline worth knowing about even though it's outside
this repo's scope.

## `CREATE OR REPLACE VIEW`

SQLite doesn't support it — confirmed directly:

```sql
CREATE OR REPLACE VIEW test_v AS SELECT 1;
```

```
Error: in prepare, near "OR": syntax error
```

This is exactly why every file in `project/gold/` and `project/silver/`
follows the same two-statement pattern instead:

```sql
DROP VIEW IF EXISTS fact_sales;
CREATE VIEW fact_sales AS
SELECT ...
```

Snowflake, BigQuery, Databricks, and Postgres all support `CREATE OR
REPLACE VIEW` directly as one statement — you can drop the
`DROP...IF EXISTS` line entirely on those engines. If you ever port one
of this repo's `gold/*.sql` files to a real warehouse, this is the
first line in every file you'll simplify.

## Surrogate key generation

This repo's dimensions reuse their natural keys as surrogate keys
(`dim_customer.customer_id` is just `bronze_customers.customer_id`,
passed straight through) — reasonable for a single-source teaching
database, but production dimensional models usually mint their *own*
surrogate keys, independent of any source system's ID, especially once
a dimension has more than one source feeding it or needs SCD Type 2
history (covered earlier in this tier).

| Engine | Mechanism |
|---|---|
| SQLite | `INTEGER PRIMARY KEY` column is an alias for `rowid` and auto-increments; `AUTOINCREMENT` keyword available but rarely needed |
| Postgres | `GENERATED ALWAYS AS IDENTITY` (modern) or `SERIAL` (legacy) |
| Snowflake | `IDENTITY` column property, or a `SEQUENCE` object referenced explicitly |
| Databricks (Delta) | `GENERATED ALWAYS AS IDENTITY` on Delta tables |
| BigQuery | No native auto-increment — generate surrogate keys explicitly, typically `ROW_NUMBER() OVER (...)` in a batch load, or a hash of the natural key (`FARM_FINGERPRINT`) |

`ROW_NUMBER() OVER (ORDER BY ...)` — already used in this tier's dedup
lesson — is the one surrogate-key technique that works identically on
every engine in this table, including SQLite, which is why it's the
most portable option to reach for when a native `IDENTITY`/sequence
mechanism isn't available or convenient.

## Dynamic typing vs. strict typing

This is the deepest difference, and it's the one that quietly shapes
almost every silver-layer transformation in this repo. Tier 4 module 1
covered SQLite's dynamic typing directly; here's the callback with a
live example from `project/bronze/schema.sql`:

```sql
CREATE TABLE bronze_products (
    ...
    unit_cost  REAL,
    weight_kg  TEXT,
    ...
);
```

`weight_kg` is declared `TEXT`, and SQLite's *type affinity* system
lets it hold genuinely mixed content — proven by querying the real
data:

```sql
SELECT DISTINCT typeof(weight_kg) FROM bronze_products;
```

| typeof(weight_kg) |
|---|
| text |
| null |

Values like `"1.2"` and `"1.2 kg"` both live happily in that column
because SQLite only ever *suggests* a type per column — it doesn't
enforce one. This is exactly what makes bronze's manufactured messiness
(mixed date formats as TEXT, mixed-boolean text pools, `weight_kg`
strings with or without a unit suffix) possible to generate and store
in the first place.

Snowflake, BigQuery, Databricks, and Postgres are all **strictly
typed**: a column declared `NUMERIC`/`FLOAT64`/`DOUBLE` will reject
`"1.2 kg"` outright at insert/load time, not silently store it. This
has a real, practical consequence for porting this repo's approach: on
a strictly-typed engine, `bronze_*` tables holding "dirty" values like
`weight_kg` would need to be declared with *every* column as a string
type (`VARCHAR`/`STRING`) regardless of what the value conceptually is
— exactly mirroring what a raw, unvalidated file-based ingestion (CSV,
JSON) typically lands as anyway. The cleaning work silver performs (in
this repo, entirely via SQL string functions and `CASE` expressions)
is the same work, engine to engine; only *where* type errors would
surface — silently accepted in SQLite, loudly rejected at ingest time
on a strict engine unless bronze is deliberately typed as all-strings —
changes.

## Examples

### 1. `ROW_NUMBER()` itself is fully portable

```sql
SELECT customer_id, ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
FROM dim_customer
LIMIT 3;
```

| customer_id | rn |
|---|---|
| 1 | 1 |
| 2 | 2 |
| 3 | 3 |

Window functions (`ROW_NUMBER`, `RANK`, `SUM() OVER`, `LAG`/`LEAD`) are
one of the few areas where syntax barely differs across SQLite,
Postgres, Snowflake, BigQuery, and Databricks — they're all standard
SQL:2003 window function syntax. This is genuinely engine-agnostic
knowledge, unlike most of what's in the tables above.

### 2. SQLite's upsert syntax, confirmed working

```sql
CREATE TABLE t(id INTEGER PRIMARY KEY, v TEXT);
INSERT INTO t VALUES (1, 'a');
INSERT INTO t (id, v) VALUES (1, 'b') ON CONFLICT(id) DO UPDATE SET v = excluded.v;
SELECT * FROM t;
```

| id | v |
|---|---|
| 1 | b |

The second insert conflicts on `id = 1` and updates `v` to `'b'` instead
of erroring — SQLite's single-row upsert primitive, and the direct
ancestor of the `MERGE` statement's `WHEN MATCHED THEN UPDATE` clause on
production engines.

## Common mistakes

- **Assuming a warehouse will silently coerce bad data the way SQLite
  does.** A load or `INSERT` that would succeed (storing a mangled
  value) in SQLite can outright fail on a strictly-typed engine. Plan
  bronze-layer ingestion accordingly — usually by typing every raw
  column as a string and doing all real type conversion explicitly in
  silver, which is exactly the discipline this repo already models.
- **Porting `strftime()` calls verbatim.** They don't exist outside
  SQLite; every one needs to become the target engine's date-truncation
  or extraction function.
- **Reaching for `QUALIFY` and being surprised it's missing on
  Postgres.** It's a Snowflake/BigQuery/Databricks convenience, not
  ANSI SQL — the CTE-wrapper pattern is the portable fallback
  everywhere, including Postgres and SQLite.
- **Forgetting `CREATE OR REPLACE VIEW` needs `DROP...IF EXISTS`
  simulated on SQLite specifically.** Copying a two-statement
  SQLite-style view definition to Snowflake/BigQuery/Databricks/Postgres
  still works (an unnecessary `DROP` before a `CREATE` is harmless) —
  but going the other direction, from a warehouse's single-statement
  `CREATE OR REPLACE VIEW` back to SQLite, will fail until it's split
  into two statements.

## Key takeaways

- The dimensional-modeling *thinking* in this tier — grain, star vs.
  snowflake, medallion layering, measure classification — is fully
  portable. The *syntax* is what needs translation, and it's a short,
  learnable list: date truncation, `QUALIFY`, `MERGE`/upsert,
  `CREATE OR REPLACE VIEW`, and surrogate key generation.
- `ROW_NUMBER()` and window functions generally are the most portable
  piece of advanced SQL syntax across engines — lean on them when in
  doubt.
- SQLite's dynamic typing (declared types are hints, not enforced) is
  what makes this repo's bronze-layer messiness possible to store at
  all; strictly-typed production engines require raw/bronze columns to
  be typed as strings deliberately, with real typing happening
  explicitly in silver — the same cleaning work, just forced to happen
  in the right place instead of being optional.
- When in doubt about a specific engine's syntax for any of these,
  that engine's own SQL reference is the source of truth — this module
  is a map of *where* the differences are, not a substitute for each
  engine's docs.

---

<!-- nav -->
Previous: [10. Capstone: Design a Novel Gold View](10-capstone-build-a-novel-gold-view.md). Next: [Portfolio](../../portfolio/README.md).
<!-- /nav -->
