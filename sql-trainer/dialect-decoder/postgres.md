# PostgreSQL Cheat Sheet

> Target: **PostgreSQL 14+**.

Postgres is the standards-leaning open-source database — careful about
correctness, rich in data types, and endlessly extensible. It handles serious
OLTP and a surprising amount of analytics, and its type system (arrays, `jsonb`,
ranges, custom types) is the deepest of the four. If a feature is in the SQL
standard, Postgres probably implements it the standard way, which makes it a good
"default" mental model — with a couple of sharp edges noted below.

← Back to the [reference matrix](reference-matrix.md) ·
[Decoder home](README.md)

---

## Identity & quoting quirks

- **Unquoted identifiers fold to LOWERCASE.** `CREATE TABLE Foo (Bar int)` makes
  table `foo`, column `bar`. `"Bar"` (quoted) preserves case and must be quoted
  forever after.
- **Double quotes are *always* identifiers**, never strings. `WHERE name = "x"`
  looks for a **column** `x` — use single quotes for string literals.
- **No `dual` table** — `SELECT 1` works with no `FROM`.
- **`::` cast shorthand** is idiomatic (`'123'::int`, `now()::date`).
- **`split_part` and array indexes are 1-based.**

---

## Signature functions

| Function | What it does |
|----------|--------------|
| `COALESCE` / `NULLIF` | Standard null handling (no `NVL`/`IFNULL`). |
| `STRING_AGG(col, sep ORDER BY ...)` | Concatenate grouped rows. |
| `array_agg(x)` / arrays generally | Aggregate into / work with real arrays. |
| `split_part(s, ',', 2)` / `string_to_array(s, ',')` | Split strings. |
| `to_char` / `to_date` / `to_timestamp` | Format/parse with Oracle-style masks. |
| `date_trunc('month', d)` | Truncate a timestamp to a unit. |
| `x->>'key'` / `x#>>'{a,b}'` | `jsonb` text extraction. |
| `agg(...) FILTER (WHERE cond)` | Conditional aggregation (only Postgres of the four). |
| `~` / `~*` / `regexp_replace(..., 'g')` | Regex match / replace. |
| `generate_series(a, b)` | Produce a set of rows — great for calendars/gaps. |

---

## Limiting rows

```sql
SELECT * FROM orders ORDER BY amount DESC LIMIT 10;
SELECT * FROM orders ORDER BY id LIMIT 10 OFFSET 20;            -- pagination
SELECT * FROM orders ORDER BY amount DESC FETCH FIRST 10 ROWS WITH TIES;
```

No `QUALIFY`; for top-N-per-group use a windowed subquery:

```sql
SELECT * FROM (
  SELECT t.*, ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) rn
  FROM orders t
) x WHERE rn = 1;
```

---

## Strings

```sql
SELECT first_name || ' ' || last_name  AS full_name,   -- || is concat
       concat_ws(' ', first_name, last_name),
       upper(email),
       substring(phone, 1, 3),
       length(name),
       position('@' IN email)           AS at_pos,
       replace(code, '-', ''),
       split_part(csv, ',', 2)          AS second_field,  -- 1-based
       string_to_array(csv, ',')        AS pieces          -- real array
FROM   customers;
```

---

## Dates

```sql
SELECT CURRENT_DATE, now(),
       order_date + INTERVAL '7 days'        AS plus_week,
       order_date + INTERVAL '3 months'      AS plus_quarter,
       end_date - start_date                 AS days,        -- integer
       date_trunc('month', order_date)       AS month_start,
       extract(YEAR FROM order_date)         AS yr,
       to_char(order_date, 'YYYY-MM-DD')     AS iso,
       to_date('2026-06-17', 'YYYY-MM-DD')   AS parsed,
       '2026-06-17'::date                    AS parsed2
FROM   orders;
```

> Format masks are Oracle-style **capitalized** (`YYYY-MM-DD HH24:MI:SS`) — the
> same alphabet as Oracle, *not* MySQL's `%`-codes or Spark's `yyyy`.

---

## NULL & conditional

```sql
SELECT COALESCE(nickname, first_name, 'unknown'),   -- no NVL/IFNULL here
       NULLIF(divisor, 0),
       CASE WHEN salary > 100000 THEN 'high' ELSE 'normal' END,  -- no IF()
       a IS NOT DISTINCT FROM b   AS null_safe_equal
FROM   employees;
```

> Postgres has **no `IF()` function** in SQL (only in PL/pgSQL) and no
> `NVL`/`IFNULL` — use `COALESCE` and `CASE`.

---

## Upsert (ON CONFLICT)

```sql
INSERT INTO t (id, val) VALUES (1, 'x')
ON CONFLICT (id) DO UPDATE
  SET val = EXCLUDED.val;            -- EXCLUDED = the row you tried to insert

-- Insert-or-ignore
INSERT INTO t (id, val) VALUES (1, 'x')
ON CONFLICT (id) DO NOTHING;
```

> You must name the conflict **target** (column(s) or a unique constraint), and
> reference the proposed row via `EXCLUDED`.

---

## JSON

Prefer **`jsonb`** (binary, indexable) over `json`.

```sql
SELECT doc->'items'          AS items_json,    -- -> returns jsonb
       doc->>'name'          AS name,          -- ->> returns text
       doc#>>'{a,b,0}'       AS deep,          -- deep text path
       jsonb_build_object('k', v) AS built
FROM   orders;
```

> `->` returns JSON, `->>` returns text — same rule as MySQL. `jsonb` supports
> GIN indexes and the `@>` containment operator.

---

## Data types

| Use | Type |
|-----|------|
| Integer | `INTEGER` / `BIGINT` |
| Decimal | `NUMERIC(p, s)` (`DECIMAL` is an alias) |
| Float | `DOUBLE PRECISION` / `REAL` |
| Variable string | `VARCHAR(n)` or `TEXT` (often just `TEXT`) |
| Boolean | `BOOLEAN` (`TRUE`/`FALSE`) — a real type |
| Date | `DATE` |
| Date + time | `TIMESTAMP` / `TIMESTAMPTZ` (store UTC, prefer this) |
| Array | `int[]`, `text[]`, … (first-class arrays) |
| JSON | `jsonb` (preferred) / `json` |

> `TEXT` and `VARCHAR(n)` are stored identically; the only difference is the
> length check. Many Postgres shops just use `TEXT`.

---

## Identity

```sql
-- Standard, preferred
CREATE TABLE t (
  id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  val TEXT
);

-- Legacy shorthand (still common): SERIAL creates a sequence behind the scenes
CREATE TABLE t2 (id SERIAL PRIMARY KEY, val TEXT);

INSERT INTO t (val) VALUES ('x') RETURNING id;   -- get the new id back
```

> Prefer `GENERATED ALWAYS AS IDENTITY` over `SERIAL` in new code — it's the
> standard form and avoids the ownership/permission quirks of `SERIAL`.

---

## Things that surprise people coming from other dialects

- **Unquoted identifiers lowercase** (opposite of Oracle's uppercasing).
- **Double quotes are identifiers, never strings** — `"x"` is a column name.
- **No `NVL`/`IFNULL`/`IF()`** — use `COALESCE` and `CASE`.
- **`regexp_replace` is first-match-only** without the `'g'` flag.
- **`FILTER (WHERE ...)` works** — the only one of the four that supports this
  ANSI clause for conditional aggregation.
- **`::` casting** and real **arrays**, **ranges**, and **`jsonb`** give you
  power the others lack — but they're Postgres-only, so isolate them if you need
  portability.
- **`TIMESTAMPTZ` stores UTC** and converts on display; use it over plain
  `TIMESTAMP` for anything time-zone-aware.
- **No `QUALIFY`** — use the windowed-subquery pattern.

See the full cross-dialect view in the [reference matrix](reference-matrix.md).
