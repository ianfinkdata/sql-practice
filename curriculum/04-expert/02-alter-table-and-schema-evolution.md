# 2. ALTER TABLE and Schema Evolution

<!-- nav -->
Previous: [1. DDL Basics and Type Affinity](01-ddl-basics-and-type-affinity.md). Next: [3. Transactions](03-transactions.md). Exercises: [2. ALTER TABLE and Schema Evolution](../../exercises/04-expert/02-alter-table-and-schema-evolution.md).
<!-- /nav -->

## The idea

Real schemas change after they're deployed: a new column is needed, a
table gets renamed as the domain model matures, a column that seemed
fine at launch turns out to need a different type. `ALTER TABLE` is
how you evolve an existing table's structure without dropping and
recreating it (and losing its data in the process).

SQLite supports a genuinely useful subset of `ALTER TABLE` — but a
much smaller subset than Postgres, MySQL, or SQL Server. Knowing
exactly where that boundary is (and the workaround pattern for
everything outside it) is the point of this module.

## What SQLite's ALTER TABLE can do

SQLite supports five `ALTER TABLE` forms:

```sql
ALTER TABLE table_name RENAME TO new_table_name;
ALTER TABLE table_name RENAME COLUMN old_name TO new_name;
ALTER TABLE table_name ADD COLUMN column_name TYPE [DEFAULT value];
ALTER TABLE table_name DROP COLUMN column_name;
ALTER TABLE table_name ADD COLUMN ... (constraints below)
```

That's the entire list. There is **no** `ALTER COLUMN`, no `MODIFY
COLUMN`, no direct way to change a column's type, no way to add a
constraint to an existing column, and `ADD COLUMN` itself has sharp
restrictions (below). Compare this to Postgres, where `ALTER TABLE ...
ALTER COLUMN ... TYPE ...` and `ALTER TABLE ... ADD CONSTRAINT ...`
are both routine. Porting a migration script written for Postgres to
SQLite verbatim will fail.

## ADD COLUMN's restrictions

`ADD COLUMN` works, but only under specific conditions, because
SQLite adds the column by rewriting the table's schema definition
rather than rewriting every existing row:

- The new column **cannot** have a `UNIQUE` constraint.
- The new column **cannot** be `PRIMARY KEY`.
- If the new column is `NOT NULL`, it **must** have a non-`NULL`
  `DEFAULT` — existing rows need *some* value to backfill, and SQLite
  won't guess one.
- The default, if given, must be a constant (or a small set of
  constant-like expressions) — not something computed from other
  columns.

## Verified examples

All against a **scratch copy**:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

### Example 1 — ADD COLUMN with a default, backfilled onto existing rows

```sql
CREATE TABLE demo_alter (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO demo_alter (name) VALUES ('widget'), ('gadget');
ALTER TABLE demo_alter ADD COLUMN price REAL DEFAULT 0;
SELECT * FROM demo_alter;
```

```
id  name    price
--  ------  -----
1   widget  0.0
2   gadget  0.0
```

Both pre-existing rows picked up `price = 0.0` — SQLite backfilled the
default without you touching the existing data.

### Example 2 — RENAME COLUMN and RENAME TO

```sql
ALTER TABLE demo_alter RENAME COLUMN name TO product_name;
.schema demo_alter
-- CREATE TABLE demo_alter (id INTEGER PRIMARY KEY, product_name TEXT, price REAL DEFAULT 0);

ALTER TABLE demo_alter RENAME TO demo_alter_renamed;
SELECT * FROM demo_alter_renamed;
```

```
id  product_name  price
--  ------------  -----
1   widget        0.0
2   gadget        0.0
```

### Example 3 — DROP COLUMN (SQLite ≥ 3.35.0)

```sql
ALTER TABLE demo_alter_renamed DROP COLUMN price;
.schema demo_alter_renamed
```

```sql
CREATE TABLE IF NOT EXISTS "demo_alter_renamed" (id INTEGER PRIMARY KEY, product_name TEXT);
```

`DROP COLUMN` is a relatively recent addition to SQLite (3.35.0,
2021) — worth knowing if you ever work against an older SQLite build,
where it isn't available at all.

### Example 4 — the restrictions, hit head-on

```sql
ALTER TABLE demo_alter_renamed ADD COLUMN required_field TEXT NOT NULL;
```

```
Error: stepping, Cannot add a NOT NULL column with default value NULL
```

```sql
ALTER TABLE demo_alter_renamed ADD COLUMN sku TEXT UNIQUE;
```

```
Error: in prepare, Cannot add a UNIQUE column
```

```sql
ALTER TABLE demo_alter_renamed ALTER COLUMN product_name TYPE VARCHAR(50);
```

```
Error: in prepare, near "ALTER": syntax error
```

All three errors are real SQLite behavior, run against the scratch
copy — this isn't a hypothetical list of limitations, it's what
actually happens.

### Example 5 — the workaround: rename, recreate, copy, drop

When you need something `ALTER TABLE` can't do directly — add a
`UNIQUE`/`CHECK` constraint, change a type, add a `NOT NULL` column
without a usable default — the standard SQLite pattern (documented in
SQLite's own docs as the "12-step" procedure, simplified here) is:
rename the old table out of the way, create the new table with the
desired shape, copy the data across, drop the old table. Wrapped in a
transaction so it's all-or-nothing (Module 3 covers transactions in
depth):

```sql
BEGIN;
ALTER TABLE demo_alter_renamed RENAME TO demo_alter_old;
CREATE TABLE demo_alter_renamed (
    id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL DEFAULT 'unknown'
);
INSERT INTO demo_alter_renamed (id, product_name)
    SELECT id, product_name FROM demo_alter_old;
DROP TABLE demo_alter_old;
COMMIT;

SELECT * FROM demo_alter_renamed;
.schema demo_alter_renamed
```

```
id  product_name
--  ------------
1   widget
2   gadget

CREATE TABLE demo_alter_renamed (
    id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL DEFAULT 'unknown'
);
```

The new table now has a `NOT NULL DEFAULT 'unknown'` constraint on
`product_name` that plain `ALTER TABLE` could never have added to an
existing column — achieved entirely through table rebuilding.

## How this connects to Oakhaven

`project/bronze/schema.sql` never uses `ALTER TABLE` at all — every
table is dropped and recreated from scratch on each build
(`project/build.py` deletes the whole `.db` file and starts over).
That's a defensible choice for a from-scratch practice-data generator,
but it's *not* how a real production schema evolves: you don't drop a
live table with a decade of customer orders in it just to add a
column. If Oakhaven's schema needed a real migration — say, adding a
`loyalty_tier` column to `bronze_customers` after go-live — you'd
reach for `ALTER TABLE ... ADD COLUMN ... DEFAULT ...` (Example 1's
pattern), not a rebuild.

## Common mistakes

- **Expecting `ALTER COLUMN` to exist.** It doesn't, in any form. To
  change a column's type or add a constraint to an existing column,
  use the rename/recreate/copy/drop pattern.
- **Adding a `NOT NULL` column without a default and being surprised
  by the error.** SQLite needs to know what to backfill into existing
  rows; give it a `DEFAULT`.
- **Running the rebuild pattern outside a transaction.** If the
  `INSERT ... SELECT` fails partway (or the process is killed) without
  a transaction wrapping the whole sequence, you can be left with
  neither table in a clean state. Always wrap it in `BEGIN`/`COMMIT`.
- **Forgetting indexes and views don't automatically follow a rebuilt
  table.** If the old table had indexes, or views/triggers referenced
  its old name, those need to be recreated against the new table too.
- **Doing any of this against `project/oakhaven.db` directly.** Always
  work on a scratch copy — the shared file is being read concurrently.

## Key takeaways

- SQLite's `ALTER TABLE` supports exactly five things: rename table,
  rename column, add column, drop column — nothing else.
- `ADD COLUMN` can't add `UNIQUE`, can't add `PRIMARY KEY`, and a `NOT
  NULL` addition needs a constant `DEFAULT` to backfill existing rows.
- There is no `ALTER COLUMN` / `MODIFY COLUMN` — to change a type or
  add a constraint to an existing column, rebuild the table
  (rename → create → copy → drop, inside a transaction).
- This is meaningfully more restrictive than Postgres/MySQL — don't
  assume a migration script written for another engine will run
  unmodified against SQLite.

---

<!-- nav -->
Previous: [1. DDL Basics and Type Affinity](01-ddl-basics-and-type-affinity.md). Next: [3. Transactions](03-transactions.md). Exercises: [2. ALTER TABLE and Schema Evolution](../../exercises/04-expert/02-alter-table-and-schema-evolution.md).
<!-- /nav -->
