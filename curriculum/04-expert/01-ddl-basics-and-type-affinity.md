# 1. DDL Basics and Type Affinity


<!-- nav -->
Previous: [Tier 3 — Advanced](../03-advanced/README.md). Next: [2. ALTER TABLE and Schema Evolution](02-alter-table-and-schema-evolution.md).
<!-- /nav -->

## The idea

Every query you've written so far in this course has been DQL
(`SELECT`) against tables that already existed. This tier steps back
one layer: **DDL — Data Definition Language** — the statements that
create and modify the structure a `SELECT` runs against. `CREATE
TABLE`, `ALTER TABLE`, and `DROP TABLE` are the core verbs.

Oakhaven's bronze tables are themselves defined by DDL you can read
right now: `project/bronze/schema.sql`. That file is worth opening —
it's five `CREATE TABLE` statements, each preceded by `DROP TABLE IF
EXISTS`, and nothing more. No primary keys, no foreign keys, no `NOT
NULL`, no `CHECK`. That's not an oversight; it's the whole point of
the bronze layer, and it's why bronze data is as messy as the facts
sheet describes. You'll see the constrained version of this table
design in Module 7.

This module covers two things: the `CREATE TABLE` syntax itself, and
something that trips up SQL learners coming from other engines —
**SQLite doesn't enforce column types the way Postgres, MySQl, or SQL
Server do.**

## CREATE TABLE syntax

```sql
CREATE TABLE table_name (
    column1 TYPE1,
    column2 TYPE2,
    ...
);
```

Bronze's actual definition for `bronze_customers`:

```sql
CREATE TABLE bronze_customers (
    customer_id     INTEGER,
    first_name      TEXT,
    last_name       TEXT,
    email           TEXT,
    phone           TEXT,
    state           TEXT,
    signup_date     TEXT,
    is_active       TEXT,
    customer_segment TEXT
);
```

Notice `signup_date` is `TEXT`, not a `DATE` type — SQLite has no
native date/datetime type. Dates are stored as text (or integers/reals
if you choose), and functions like `strftime()` and `date()` interpret
ISO-8601-formatted text as dates. That's *why* bronze can get away
with storing `signup_date` in three different formats (`YYYY-MM-DD`,
`MM/DD/YYYY`, `YYYY-MM-DD HH:MM:SS`) — SQLite never rejects any of them
at insert time, because as far as the storage engine is concerned
they're all just strings.

## Type affinity: SQLite's take on typing

Most database engines are **rigidly typed**: declare a column
`INTEGER`, and the engine refuses to store anything that isn't an
integer. SQLite is **dynamically typed with type affinity**: every
*value* carries its own storage class (`NULL`, `INTEGER`, `REAL`,
`TEXT`, `BLOB`), and a column's declared type is only a *preference* —
an "affinity" — that SQLite uses to *try* to coerce an incoming value,
not a hard rule that rejects it.

There are five affinities:

| Affinity | Triggered by declared type containing... | Behavior |
|---|---|---|
| `TEXT` | `CHAR`, `CLOB`, `TEXT` | Numeric values are converted to text before storing. |
| `NUMERIC` | anything not matching the other four (e.g. `NUMERIC`, `DECIMAL`, `BOOLEAN`, `DATE`) | Text that looks like an integer or real is converted; otherwise stored as-is. |
| `INTEGER` | `INT` | Same as NUMERIC, but integer values are preferred when a real has no fractional part. |
| `REAL` | `REAL`, `FLOA`, `DOUB` | Numeric values are stored as floating point. |
| `BLOB` | declared type is empty, or affinity keyword `BLOB` | No coercion at all — stored exactly as given. |

The practical consequence: **you can insert a string into an `INTEGER`
column and SQLite will not stop you** — it will store it as `TEXT` if
it can't be losslessly converted to a number. This is the portability
trap: SQL that "works" against SQLite because it silently accepts a
malformed value would be rejected outright by Postgres or MySQL with a
type error. Bronze's messy `weight_kg` (declared `TEXT`, but semantically
a number formatted as `"1.2"`, `"1.2 kg"`, or NULL) and `order_total`
(declared `TEXT`, holding numbers, `$`-prefixed numbers, and literal
strings like `"TBD"`) both lean on this looseness. Nothing in the DDL
stops it.

## Verified examples

All of these run against a **scratch copy** of the database — never
the shared `project/oakhaven.db` — because `CREATE TABLE`/`INSERT` are
writes:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

### Example 1 — a table with every affinity, and what actually gets stored

```sql
CREATE TABLE demo_type_affinity (
    id INTEGER PRIMARY KEY,
    label TEXT,
    price REAL,
    ratio NUMERIC,
    raw BLOB
);
INSERT INTO demo_type_affinity (id, label, price, ratio, raw) VALUES
    (1, 'hello', 19.99, 5, 'stored as text but column is INTEGER-ish'),
    (2, 12345, '3.14', '2/3', 42);
SELECT id, label, typeof(label), price, typeof(price),
       ratio, typeof(ratio), raw, typeof(raw)
FROM demo_type_affinity;
```

Real output:

```
id  label  typeof(label)  price  typeof(price)  ratio  typeof(ratio)  raw                                        typeof(raw)
--  -----  -------------  -----  -------------  -----  -------------  -----------------------------------------  -----------
1   hello  text           19.99  real           5      integer        stored as text but column is INTEGER-ish  text
2   12345  text           3.14   real           2/3    text           42                                         integer
```

Read that carefully — it's the whole lesson in one table:

- Row 2's `label` column is `TEXT` affinity: we inserted the *integer*
  `12345`, and SQLite converted it to the string `'12345'` before
  storing — `typeof()` reports `text`.
- `price` is `REAL` affinity: row 2 inserted the *string* `'3.14'`,
  and SQLite converted it to the floating-point value `3.14`.
- `ratio` is `NUMERIC` affinity: row 1's integer `5` stayed an
  integer; row 2's string `'2/3'` could **not** be losslessly
  converted to a number (it's not numeric text), so it was stored
  as-is — `typeof()` reports `text`. NUMERIC affinity converts *when
  it can*, and gives up silently when it can't.
- `raw` is `BLOB` affinity (an untyped/`BLOB`-declared column gets no
  affinity at all): both a text value and an integer value were
  stored completely unchanged.

### Example 2 — `typeof()` on literals, for reference

```sql
SELECT typeof(1), typeof(1.5), typeof('abc'), typeof(NULL), typeof(x'0011');
```

```
typeof(1)  typeof(1.5)  typeof('abc')  typeof(NULL)  typeof(x'0011')
---------  -----------  -------------  ------------  ---------------
integer    real         text           null          blob
```

### Example 3 — `bronze_sales` proves the point in production data

Read-only against the real database — no writes needed, since bronze
already demonstrates this:

```sql
.schema bronze_sales
```

```sql
CREATE TABLE bronze_sales (
    order_id        INTEGER,
    order_line_id   INTEGER,
    customer_id     INTEGER,
    product_id      INTEGER,
    employee_id     INTEGER,
    order_date      TEXT,
    ship_date       TEXT,
    quantity        INTEGER,
    unit_price      REAL,
    discount_pct    REAL,
    order_total     TEXT,
    payment_method  TEXT,
    order_status    TEXT,
    channel         TEXT
);
```

`order_total` is declared `TEXT` and, per the data dictionary, holds
correctly-computed numbers, `$`-prefixed numbers, stale pre-discount
numbers, `NULL`, and the literal strings `"TBD"` / `"N/A"` — all in
the same column, none of it rejected at insert time, because `TEXT`
affinity accepts anything. This is precisely why `silver_sales.sql`
never trusts `order_total` and recomputes `net_amount` from
`quantity * unit_price * (1 - discount_pct)` instead (see Tier 3 /
`project/silver/silver_sales.sql`).

### Example 4 — no PK means no uniqueness is enforced

```sql
CREATE TABLE demo_pk (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO demo_pk (name) VALUES ('auto1'), ('auto2');
SELECT * FROM demo_pk;
```

```
id  name
--  -----
1   auto1
2   auto2
```

`INTEGER PRIMARY KEY` in SQLite is special-cased as an alias for the
table's internal `rowid` and auto-increments when omitted — that part
behaves like other engines' auto-increment PK. But bronze's tables
declare *no* primary key at all (just `customer_id INTEGER`, a plain
typed column), so nothing prevents duplicate `customer_id` values,
duplicate `(order_id, order_line_id)` pairs, or gaps. Module 7
contrasts this directly against a properly constrained schema.

## Common mistakes

- **Assuming a declared type is enforced.** `price REAL` does not mean
  "only numbers allowed" — it means "numbers get converted to
  floating point; text that doesn't look numeric is stored as text
  unchanged." Always verify with `typeof()` if you're unsure what's
  really in a column.
- **Porting SQLite schemas to a rigidly-typed engine (or vice versa)
  and assuming behavior transfers.** SQL that loads cleanly into
  SQLite because of loose type affinity can fail outright against
  Postgres/MySQL, which validate types at insert time. This project's
  bronze layer intentionally exploits SQLite's looseness to model
  real-world messy ingestion — don't assume production systems on
  other engines behave the same way.
- **Confusing "no type enforcement" with "no types."** Every value
  still has a concrete storage class (`typeof()` never lies) — it's
  the *column* that doesn't enforce a match between its declared type
  and what's stored in it.
- **Forgetting `IF EXISTS`/`IF NOT EXISTS` guards.** Bronze's
  `schema.sql` prefixes every `CREATE TABLE` with `DROP TABLE IF
  EXISTS` so the script is safely rerunnable. Module 9 covers this
  idempotent-DDL pattern in depth.

## Key takeaways

- DDL (`CREATE`, `ALTER`, `DROP`) defines structure; DML/DQL operate
  on data within that structure.
- SQLite has **no rigid type enforcement** — every column has a *type
  affinity* (`TEXT`, `NUMERIC`, `INTEGER`, `REAL`, `BLOB`) that
  *tries* to coerce inserted values, but never rejects a value it
  can't coerce.
- `typeof(value)` tells you the actual storage class SQLite used —
  use it whenever you're unsure what's really in a column.
- Bronze's tables have no PK/FK/CHECK constraints by design — that's
  what makes bronze bronze, and Module 7 shows what changes once you
  add them back.
- Always demo `CREATE`/`INSERT`/`ALTER` against a scratch copy of the
  database, never the shared `project/oakhaven.db`.

---

<!-- nav -->
Previous: [Tier 3 — Advanced](../03-advanced/README.md). Next: [2. ALTER TABLE and Schema Evolution](02-alter-table-and-schema-evolution.md).
<!-- /nav -->
