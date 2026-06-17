# Databricks SQL Cheat Sheet

> Target: **Databricks SQL** — Spark SQL semantics, the Photon engine, Unity
> Catalog, and Delta Lake tables.

Databricks SQL is the query surface of the lakehouse. Under the hood it's
**Spark SQL** (accelerated by Photon), running analytical (OLAP) queries over
huge datasets stored as **Delta** tables in object storage, organized by **Unity
Catalog** (`catalog.schema.table`). It is built for scans and aggregations over
billions of rows, not for single-row OLTP point lookups. Function names lean
lowercase and Spark-flavored.

← Back to the [reference matrix](reference-matrix.md) ·
[Decoder home](README.md)

---

## Identity & quoting quirks

- **Three-level names:** `catalog.schema.table` under Unity Catalog.
- **Backtick identifiers:** `` `My Col` `` for names with spaces/keywords.
- **Identifiers are case-insensitive** for resolution; conventionally lowercase.
- **No `dual` table** — `SELECT 1` works with no `FROM`.
- **`split` arrays are 0-indexed** (a Spark thing that bites SQL folks).
- Optimized for batch analytics; updates/deletes work on Delta tables via
  `MERGE`/`UPDATE`/`DELETE` but it is not a high-concurrency OLTP store.

---

## Signature functions

| Function | What it does |
|----------|--------------|
| `doc:field` | Colon JSON-path operator — concise extract from a JSON string. |
| `get_json_object(doc, '$.f')` | Path-based JSON extraction. |
| `split(s, ',')` | Split string into a (0-indexed) array. |
| `explode(arr)` | Turn an array into rows (lateral expansion). |
| `collect_list(x)` / `collect_set(x)` | Aggregate values into an array. |
| `array_join(arr, sep)` / `concat_ws(sep, ...)` | Array/values → delimited string. |
| `date_format` / `to_date` / `date_add` / `date_trunc` | Date handling (Java patterns). |
| `if(cond, a, b)` | Inline ternary. |
| `nvl` / `nvl2` / `coalesce` | Null handling (Oracle-style names available). |
| `QUALIFY` | Filter directly on a window function. |

---

## Limiting rows

```sql
SELECT * FROM orders ORDER BY amount DESC LIMIT 10;
SELECT * FROM orders ORDER BY id LIMIT 10 OFFSET 20;   -- pagination
```

No `WITH TIES`; for top-N-per-group, prefer `QUALIFY`:

```sql
SELECT * FROM orders
QUALIFY ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) = 1;
```

---

## Strings

```sql
SELECT first_name || ' ' || last_name        AS full_name,  -- || works
       concat_ws(' ', first_name, last_name)  AS also_full,
       upper(email),
       substring(phone, 1, 3),
       length(name),
       instr(email, '@'),
       split(csv, ',')[1]                     AS second_field, -- 0-indexed!
       regexp_replace(code, '\\d', '#')       AS masked       -- escape backslash
FROM   customers;
```

> Backslashes in Spark string literals must be doubled (`'\\d'`) or use a raw
> string `r'\d'`.

---

## Dates

```sql
SELECT current_date()                         AS today,
       current_timestamp()                    AS now_ts,
       date_add(order_date, 7)                AS plus_week,
       add_months(order_date, 3)              AS plus_quarter,
       datediff(end_date, start_date)         AS days,
       date_trunc('month', order_date)        AS month_start,
       extract(YEAR FROM order_date)          AS yr,
       date_format(order_date, 'yyyy-MM-dd')  AS iso,        -- Java pattern
       to_date('2026-06-17', 'yyyy-MM-dd')    AS parsed
FROM   orders;
```

> Format patterns are **Java/Spider** style: `yyyy-MM-dd HH:mm:ss` (lowercase
> year, capital month). Do not copy Oracle's `YYYY-MM-DD` here.

---

## NULL & conditional

```sql
SELECT coalesce(nickname, first_name, 'unknown'),  -- portable
       nvl(commission, 0),                          -- Oracle-style alias
       nvl2(manager_id, 'has boss', 'top'),
       if(salary > 100000, 'high', 'normal'),       -- inline ternary
       CASE WHEN status = 'A' THEN 'Active' ELSE 'Other' END
FROM   employees;
```

---

## Upsert (MERGE INTO — Delta only)

```sql
MERGE INTO target t
USING source s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;
```

`UPDATE SET *` / `INSERT *` auto-map matching columns — a nice Databricks
convenience. Requires the target to be a **Delta** table.

---

## JSON

```sql
SELECT doc:customer.name              AS name,    -- colon path, returns string
       doc:items[0].sku               AS first_sku,
       get_json_object(doc, '$.total') AS total
FROM   orders;
```

JSON is usually stored as a `STRING` column and parsed on read. `from_json` with
a schema gives you typed structs when you need them.

---

## Data types

| Use | Type |
|-----|------|
| Integer | `INT` / `BIGINT` |
| Decimal | `DECIMAL(p, s)` |
| Float | `DOUBLE` / `FLOAT` |
| Variable string | `STRING` (no length limit) |
| Boolean | `BOOLEAN` (`true`/`false`) |
| Date | `DATE` |
| Timestamp | `TIMESTAMP` |
| Array / struct / map | `ARRAY<...>`, `STRUCT<...>`, `MAP<...>` (complex types) |

> There is no `VARCHAR(n)` length enforcement to worry about — everything is
> `STRING`. Native **complex types** (array/struct/map) are a major advantage
> for semi-structured data.

---

## Identity (Delta)

```sql
CREATE TABLE t (
  id  BIGINT GENERATED ALWAYS AS IDENTITY,
  val STRING
) USING DELTA;
```

> IDENTITY values are unique and increasing but **may have gaps** because of
> parallel/distributed writes. Never assume they're consecutive.

---

## Things that surprise people coming from other dialects

- **`split()` and array indexing are 0-based.** First element is `[0]`.
- **Date formats use Java patterns** (`yyyy-MM-dd`), not Oracle/Postgres
  (`YYYY-MM-DD`) or MySQL (`%Y-%m-%d`).
- **Backslashes need escaping** in string literals (`'\\d'`).
- **`MERGE`/`UPDATE`/`DELETE` require Delta tables** — plain Parquet/CSV are
  read-mostly.
- **`QUALIFY` exists** — you don't need the subquery dance for top-N-per-group.
- **It's OLAP, not OLTP.** No traditional indexes; performance comes from
  partitioning, Z-ordering/liquid clustering, file pruning, and Photon.
- **Casts via `::` work** (`x::int`) in addition to `CAST`.

See the full cross-dialect view in the [reference matrix](reference-matrix.md).
