# SQLite vs. Snowflake vs. BigQuery vs. Databricks vs. Postgres

A reference table for porting the patterns in this library to a different
SQL engine. Every pattern file in `portfolio/` includes its own
"Portability" note scoped to that specific pattern; this file is the
consolidated cross-reference for the handful of concerns that come up
repeatedly across many patterns.

This repo (`project/oakhaven.db`) is built and tested against **SQLite
3.46**. Every claim below about SQLite behavior was verified against that
database; claims about the other four engines reflect their documented
syntax and are flagged as such where not independently tested here.

---

## Date/time functions

| Need | SQLite | Postgres | Snowflake | BigQuery | Databricks (Spark SQL) |
|---|---|---|---|---|---|
| Extract year/month/day | `strftime('%Y', d)` etc, cast to INT | `EXTRACT(YEAR FROM d)` | `YEAR(d)`, `MONTH(d)`, `DAY(d)` | `EXTRACT(YEAR FROM d)` | `YEAR(d)`, `MONTH(d)`, `DAY(d)` |
| Day of week (0=Sun..6=Sat) | `strftime('%w', d)` | `EXTRACT(DOW FROM d)` (0=Sun) | `DAYOFWEEK(d)` (0=Sun by default) | `EXTRACT(DAYOFWEEK FROM d)` **1=Sun..7=Sat** | `DAYOFWEEK(d)` **1=Sun..7=Sat** |
| Weekday name | manual `CASE` (no built-in) | `TO_CHAR(d,'Day')` | `DAYNAME(d)` | `FORMAT_DATE('%A', d)` | `date_format(d, 'EEEE')` |
| Add/subtract interval | `date(d, '+1 day')` | `d + INTERVAL '1 day'` | `DATEADD(day, 1, d)` | `DATE_ADD(d, INTERVAL 1 DAY)` | `date_add(d, 1)` |
| Truncate to month | `substr(d, 1, 7)` (string) or `date(d,'start of month')` | `DATE_TRUNC('month', d)` | `DATE_TRUNC('MONTH', d)` | `DATE_TRUNC(d, MONTH)` | `DATE_TRUNC('MONTH', d)` / `TRUNC(d,'MM')` |
| Difference in months | manual `(y2-y1)*12+(m2-m1)` (no built-in) | `AGE(d2, d1)` (interval) | `DATEDIFF('month', d1, d2)` | `DATE_DIFF(d2, d1, MONTH)` | `MONTHS_BETWEEN(d2, d1)` (fractional) |
| Parse a known-format string to date | `substr()` reassembly / `LIKE` shape-matching | `TO_DATE(s, 'MM/DD/YYYY')` | `TRY_TO_DATE(s, 'MM/DD/YYYY')` | `PARSE_DATE('%m/%d/%Y', s)` / `SAFE.PARSE_DATE(...)` | `TO_DATE(s, 'MM/dd/yyyy')` / `TRY_TO_TIMESTAMP` |
| Generate a date spine | `WITH RECURSIVE` (see `03-date-dimension-patterns/`) | `generate_series(d1, d2, '1 day')` | `WITH RECURSIVE` (supported) | `GENERATE_DATE_ARRAY(d1, d2)` + `UNNEST` | `WITH RECURSIVE` (Spark 3.x+) or `sequence()` + `explode()` |

**Biggest gotcha:** BigQuery and Databricks number `DAYOFWEEK` starting at
1 (Sunday), while SQLite, Postgres, and Snowflake start at 0 (Sunday).
Any `is_weekend` or "start of week" logic ported between these two groups
needs its day-of-week comparison values shifted by one, or it will
silently misclassify Sunday.

---

## Filtering window-function results: `QUALIFY`

Most of the analytical patterns in `05-analytical-query-patterns/` rank
rows with a window function and then need to filter to a subset of ranks
(e.g. top N per group). Window functions can't be referenced in the same
`SELECT`'s `WHERE` clause (WHERE evaluates before window functions do), so
you normally wrap in a CTE/subquery and filter in the outer query — that's
what every file in this repo does, since it targets SQLite.

| Engine | Supports `QUALIFY`? |
|---|---|
| SQLite | No — wrap in a CTE/subquery |
| Postgres | No — wrap in a CTE/subquery |
| Snowflake | **Yes** — `... QUALIFY ROW_NUMBER() OVER (...) = 1` |
| BigQuery | **Yes** |
| Databricks (Spark SQL) | **Yes** |

On the three engines that support it, `QUALIFY` collapses the wrapping
CTE into a single statement — shorter and often clearer of intent. See
`top-n-per-group.sql` for a worked before/after.

---

## Upsert / MERGE (Type 1 SCD updates)

| Engine | Syntax |
|---|---|
| SQLite | `INSERT ... ON CONFLICT(key) DO UPDATE SET col = excluded.col` |
| Postgres | `INSERT ... ON CONFLICT (key) DO UPDATE SET col = EXCLUDED.col` (same syntax family as SQLite — SQLite's UPSERT is modeled on Postgres's) |
| Snowflake | `MERGE INTO target USING source ON (...) WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ...` |
| BigQuery | `MERGE` (same ANSI shape as Snowflake) |
| Databricks (Delta Lake) | `MERGE INTO ... USING ... WHEN MATCHED ... WHEN NOT MATCHED ...` (this is also the standard recipe for a two-step SCD Type 2 close-out-then-insert) |

SQLite and Postgres share `INSERT ... ON CONFLICT`; Snowflake, BigQuery,
and Databricks share full `MERGE`. Neither family is available on the
"other side" — porting an upsert between these two groups means rewriting
the statement shape entirely, not just changing keywords.

---

## `CREATE OR REPLACE VIEW`

This repo's entire silver/gold layer is views (`DROP VIEW IF EXISTS x;
CREATE VIEW x AS ...`), because SQLite has no `CREATE OR REPLACE VIEW`.

| Engine | Syntax |
|---|---|
| SQLite | `DROP VIEW IF EXISTS v; CREATE VIEW v AS SELECT ...;` (two statements — no single-statement replace) |
| Postgres | `CREATE OR REPLACE VIEW v AS SELECT ...;` (single statement) |
| Snowflake | `CREATE OR REPLACE VIEW v AS SELECT ...;` |
| BigQuery | `CREATE OR REPLACE VIEW v AS SELECT ...;` |
| Databricks | `CREATE OR REPLACE VIEW v AS SELECT ...;` |

Every other engine in this table supports the single-statement form.
SQLite's two-statement `DROP`+`CREATE` pattern is strictly more portable
(it also works, redundantly, on the other four) but the reverse isn't
true — a lone `CREATE OR REPLACE VIEW` will error on SQLite.

---

## Identity / autoincrement / sequences (surrogate keys)

See `04-dimensional-modeling-patterns/surrogate-key-generation.sql` for
the full pattern and worked example. Summary:

| Engine | Native auto-incrementing key |
|---|---|
| SQLite | `INTEGER PRIMARY KEY` (aliases the internal rowid; add `AUTOINCREMENT` for strict non-reuse after deletes) |
| Postgres | `GENERATED ALWAYS AS IDENTITY` (SQL-standard; preferred over legacy `SERIAL`) |
| Snowflake | `NUMBER AUTOINCREMENT` / `IDENTITY`, or an explicit `SEQUENCE` object with `NEXTVAL` |
| BigQuery | **No native auto-increment.** Idiomatic alternatives: `ROW_NUMBER()` over a batch, or `GENERATE_UUID()` for a non-sequential key |
| Databricks (Delta Lake) | `GENERATED ALWAYS AS IDENTITY` on Delta tables, or `monotonically_increasing_id()` in Spark code (fast, but not contiguous) |

`ROW_NUMBER() OVER (ORDER BY natural_key)` is the one technique that
works identically as a *derived* surrogate key on all five engines — the
divergence above is only about each engine's *native column-level*
identity mechanism for a physically stored table.

---

## Type system notes

- **SQLite is dynamically typed** ("type affinity," not strict typing):
  any column can hold any value regardless of its declared type, and
  `CAST('TBD' AS REAL)` silently returns `0.0` instead of erroring. Every
  other engine in this table is strictly typed and will raise a cast
  error on non-numeric text — meaning code that relies on SQLite's
  cast-never-fails behavior needs an explicit `TRY_CAST` (Snowflake/
  Databricks), `SAFE_CAST` (BigQuery), or `CASE` guard (Postgres, which
  has no built-in try-cast) when ported. See
  `02-silver-cleaning-patterns/recompute-dont-trust-the-total.sql` for
  where this actually bites in this dataset (`order_total = 'TBD'`).
- **Boolean type**: SQLite has no native `BOOLEAN` — this repo's
  convention (`0`/`1` INTEGER) is idiomatic SQLite and also works
  unmodified on every other engine, though Postgres/Snowflake/Databricks/
  BigQuery all additionally support a native `BOOLEAN`/`BOOL` type with
  `TRUE`/`FALSE` literals if you prefer a more expressive column type on
  those engines.
- **`WITH RECURSIVE`**: supported on SQLite, Postgres, Snowflake, and
  Databricks. **Not supported on BigQuery at all** — use
  `GENERATE_DATE_ARRAY`/`GENERATE_ARRAY` + `UNNEST` instead for anything
  this repo builds with a recursive CTE.
