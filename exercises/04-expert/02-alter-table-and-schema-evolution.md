# Exercises: ALTER TABLE and Schema Evolution

<!-- nav -->
Curriculum: [2. ALTER TABLE and Schema Evolution](../../curriculum/04-expert/02-alter-table-and-schema-evolution.md). Previous: [1. DDL Basics and Type Affinity](01-ddl-basics-and-type-affinity.md). Next: [3. Transactions](03-transactions.md).
<!-- /nav -->

Every exercise here modifies a table's structure — work against your
own scratch copy for all of them, never `project/oakhaven.db`:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Read the limitations before you hit them

From memory (or by testing on your scratch copy), list the five things
SQLite's `ALTER TABLE` can do, and name at least two things it
*cannot* do that you'd be able to do in Postgres or MySQL.

<details>
<summary>Show solution</summary>

What it **can** do:

1. `RENAME TO` — rename the table.
2. `RENAME COLUMN ... TO ...` — rename a column.
3. `ADD COLUMN ...` — add a new column (with restrictions, see below).
4. `DROP COLUMN ...` — drop an existing column (SQLite ≥ 3.35.0).

What it **cannot** do, unlike Postgres/MySQL:

- No `ALTER COLUMN` / `MODIFY COLUMN` — you cannot change an existing
  column's declared type directly.
- `ADD COLUMN` cannot add `UNIQUE` or `PRIMARY KEY` constraints.
- Adding a `NOT NULL` column requires a non-`NULL` constant `DEFAULT`
  — SQLite won't guess a backfill value.
- No way to add a `CHECK` or `FOREIGN KEY` constraint to an existing
  table via `ALTER TABLE` at all.

Anything beyond the four supported forms requires the rename →
recreate → copy → drop rebuild pattern (Exercise 5).

</details>

---

### 2. Add a column with a default, and confirm it backfills

On your scratch copy, add a `loyalty_tier TEXT` column to
`bronze_employees`, defaulting to `'standard'`. Confirm the default
was backfilled onto existing rows.

<details>
<summary>Show solution</summary>

```sql
ALTER TABLE bronze_employees ADD COLUMN loyalty_tier TEXT DEFAULT 'standard';
SELECT employee_id, first_name, loyalty_tier FROM bronze_employees LIMIT 3;
```

```
employee_id  first_name  loyalty_tier
-----------  ----------  ------------
1            Alexa       standard
2            sandra      standard
3            Alexandria  standard
```

All three pre-existing rows picked up `'standard'` without any
`UPDATE` statement — `ADD COLUMN ... DEFAULT` backfills automatically.

</details>

---

### 3. Rename a column you just added

Rename `loyalty_tier` (from Exercise 2) to `tier`, and confirm the
data survived the rename.

<details>
<summary>Show solution</summary>

```sql
ALTER TABLE bronze_employees RENAME COLUMN loyalty_tier TO tier;
SELECT employee_id, tier FROM bronze_employees LIMIT 2;
```

```
employee_id  tier
-----------  --------
1            standard
2            standard
```

</details>

---

### 4. Trigger the `NOT NULL` restriction on purpose

Try to add a `badge_number TEXT NOT NULL` column to `bronze_employees`
with no `DEFAULT`. What error do you get, and why does it make sense
given that `bronze_employees` already has 35 rows?

<details>
<summary>Show solution</summary>

```sql
ALTER TABLE bronze_employees ADD COLUMN badge_number TEXT NOT NULL;
```

```
Error: stepping, Cannot add a NOT NULL column with default value NULL
```

The 35 existing rows have no `badge_number` value yet — if SQLite
allowed this, every existing row would need a `NULL` in a column
declared `NOT NULL`, which is a contradiction. SQLite requires a
constant `DEFAULT` precisely so it has *something* non-`NULL` to
backfill into every pre-existing row.

</details>

---

### 5. Use the rebuild pattern to add a CHECK constraint

`ALTER TABLE` cannot add a `CHECK` constraint to an existing table.
On your scratch copy, use the rename → recreate → copy → drop pattern
(inside a transaction) to rebuild `bronze_employees` with a `CHECK`
constraint on `department` restricting it to `'Sales'`, `'Support'`,
`'Warehouse'`, `'Management'`, or `NULL`. Confirm the row count is
unchanged after the rebuild, then confirm the constraint actually
blocks an invalid value.

<details>
<summary>Show solution</summary>

```sql
BEGIN;
ALTER TABLE bronze_employees RENAME TO bronze_employees_old;
CREATE TABLE bronze_employees (
    employee_id       INTEGER,
    first_name        TEXT,
    last_name         TEXT,
    department        TEXT CHECK (department IN ('Sales','Support','Warehouse','Management') OR department IS NULL),
    region            TEXT,
    hire_date         TEXT,
    termination_date  TEXT,
    is_manager        TEXT,
    email             TEXT
);
INSERT INTO bronze_employees (employee_id, first_name, last_name, department, region, hire_date, termination_date, is_manager, email)
SELECT employee_id, first_name, last_name, NULL, region, hire_date, termination_date, is_manager, email
FROM bronze_employees_old;
DROP TABLE bronze_employees_old;
COMMIT;

SELECT COUNT(*) FROM bronze_employees;
```

```
35
```

(Note: real `bronze_employees.department` values are messy strings
like `'MANAGEMENT'`/`'sales'` that wouldn't pass this exact `CHECK` as
written — this solution copies `NULL` into `department` instead of the
raw messy value, to isolate the schema-rebuild mechanics from
`silver_employees`'s casing-normalization job. In practice you'd
normalize the values as part of the `INSERT ... SELECT`, the same way
`silver_employees.sql` does with its `CASE` expression.)

Row count is unchanged: 35 in, 35 out. Now confirm the constraint is
real:

```sql
UPDATE bronze_employees SET department = 'NotADept' WHERE employee_id = 1;
```

```
Error: stepping, CHECK constraint failed: department IN ('Sales','Support','Warehouse','Management') OR department IS NULL (19)
```

Rejected — something `ALTER TABLE` alone could never have added to
the existing table.

</details>

---

### 6. Diagnose a broken migration script

A teammate wrote this migration and says it "doesn't work":

```sql
ALTER TABLE bronze_products ADD COLUMN discount_tier TEXT UNIQUE DEFAULT 'none';
```

Run it on your scratch copy, capture the real error, and explain in
one sentence which specific restriction it violates (there are two
candidate restrictions from this module — identify which one actually
fires first).

<details>
<summary>Show solution</summary>

```sql
ALTER TABLE bronze_products ADD COLUMN discount_tier TEXT UNIQUE DEFAULT 'none';
```

```
Error: in prepare, Cannot add a UNIQUE column
```

This hits the `UNIQUE` restriction, not the `NOT NULL`/default
restriction — `ADD COLUMN` rejects a `UNIQUE` constraint outright, at
`prepare` time, before SQLite even gets to considering the default
value. (It's also worth noting `UNIQUE` wouldn't make sense here even
if it were allowed: backfilling every one of the 150 existing rows
with the identical default value `'none'` would immediately violate
uniqueness across those rows anyway.) The fix is the same rebuild
pattern from Exercise 5 — create a new table with `discount_tier TEXT
UNIQUE` from the start, and populate distinct values as part of the
copy.

</details>

---

<!-- nav -->
Curriculum: [2. ALTER TABLE and Schema Evolution](../../curriculum/04-expert/02-alter-table-and-schema-evolution.md). Previous: [1. DDL Basics and Type Affinity](01-ddl-basics-and-type-affinity.md). Next: [3. Transactions](03-transactions.md).
<!-- /nav -->
