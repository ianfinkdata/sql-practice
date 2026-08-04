# Exercises: Portable, Idempotent DDL Patterns

Exercise 1 is read-only (a `grep` over `.sql` files). Every other
exercise creates database objects — work against your own scratch
copy:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Audit the real project for the idempotent pattern

Using `grep`, confirm that every `.sql` file in `project/silver/` and
`project/gold/` starts with `DROP VIEW IF EXISTS` for the view it
defines. How many files total follow this pattern?

<details>
<summary>Show solution</summary>

```bash
grep -rc "DROP VIEW IF EXISTS" project/silver/ project/gold/
```

```
project/silver/silver_calendar.sql:1
project/silver/silver_customers.sql:1
project/silver/silver_sales.sql:1
project/silver/silver_employees.sql:1
project/silver/silver_products.sql:1
project/gold/dim_date.sql:1
project/gold/agg_daily_sales.sql:1
project/gold/dim_product.sql:1
project/gold/agg_monthly_sales_by_category.sql:1
project/gold/dim_customer.sql:1
project/gold/dim_employee.sql:1
project/gold/agg_customer_ltv.sql:1
project/gold/fact_sales.sql:1
```

All 13 files (5 silver + 8 gold) — every view-defining `.sql` file in
the project follows the pattern exactly once.

</details>

---

### 2. Confirm `CREATE OR REPLACE VIEW` isn't valid SQLite

On your scratch copy, try `CREATE OR REPLACE VIEW ex_v AS SELECT 1;`.
Capture the exact error.

<details>
<summary>Show solution</summary>

```sql
CREATE OR REPLACE VIEW ex_v AS SELECT 1;
```

```
Error: in prepare, near "OR": syntax error
  CREATE OR REPLACE VIEW ex_v AS SELECT 1;
         ^--- error here
```

SQLite's parser doesn't recognize `OR REPLACE` after `CREATE VIEW` at
all — this isn't a runtime restriction, it's a syntax error, meaning
SQLite doesn't understand the statement as valid SQL in the first
place.

</details>

---

### 3. Reproduce the "already exists" failure, then fix it

On your scratch copy: create a view `ex_v2` with a plain `CREATE
VIEW` (no guard). Run the *exact same statement* again and capture the
error. Then create a *different* view, `ex_v3`, using the
`DROP VIEW IF EXISTS` + `CREATE VIEW` pattern, and run that pair
twice to prove it doesn't error either time.

<details>
<summary>Show solution</summary>

```sql
CREATE VIEW ex_v2 AS SELECT 1 AS x;
CREATE VIEW ex_v2 AS SELECT 1 AS x;
```

```
Error: in prepare, view ex_v2 already exists
  CREATE VIEW ex_v2 AS SELECT 1 AS x;
              ^--- error here
```

```sql
DROP VIEW IF EXISTS ex_v3;
CREATE VIEW ex_v3 AS SELECT 1 AS x;
DROP VIEW IF EXISTS ex_v3;
CREATE VIEW ex_v3 AS SELECT 1 AS x;
SELECT 'ran twice fine' AS ok;
```

```
ok
---------------
ran twice fine
```

Same underlying `CREATE VIEW` statement, run twice both times — the
only difference is the `DROP VIEW IF EXISTS` guard in front of it.

</details>

---

### 4. `IF NOT EXISTS` is idempotent but doesn't update the schema

On your scratch copy: create `ex_t (id INTEGER, name TEXT)` using
`CREATE TABLE IF NOT EXISTS`, insert one row, then run `CREATE TABLE
IF NOT EXISTS` *again* for `ex_t` — but this time with an extra
column, `extra_col TEXT`, in the definition. Check `.schema ex_t`
afterward. Did the extra column get added?

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE IF NOT EXISTS ex_t (id INTEGER, name TEXT);
INSERT INTO ex_t VALUES (1, 'original');
CREATE TABLE IF NOT EXISTS ex_t (id INTEGER, name TEXT, extra_col TEXT);
SELECT * FROM ex_t;
.schema ex_t
```

```
1|original
CREATE TABLE ex_t (id INTEGER, name TEXT);
```

No — the second `CREATE TABLE IF NOT EXISTS` was silently a no-op,
because `ex_t` already existed; `extra_col` never got added, and no
error was raised either. This is the key trap `IF NOT EXISTS` sets:
it's idempotent in the narrow sense of "won't error on rerun," but it
does **not** guarantee the object matches your *current* `CREATE`
statement — it guarantees the *opposite*, that whatever existed first
wins. This is exactly why the silver/gold layer uses `DROP ... IF
EXISTS` + unconditional `CREATE` instead: it guarantees the object
always ends up matching the current `.sql` file, not whatever ran
first.

</details>

---

### 5. `CREATE INDEX IF NOT EXISTS` — the one place `IF NOT EXISTS` is usually the right call

Unlike tables/views (Exercise 4), an index's definition rarely needs
to "win" over a pre-existing one with the same name in the way a
view's business logic does — an index is purely a performance
structure, not a source of truth for the data's shape. On your scratch
copy, create an index using `CREATE INDEX IF NOT EXISTS`, then run the
identical statement again and confirm it doesn't error.

<details>
<summary>Show solution</summary>

```sql
CREATE INDEX IF NOT EXISTS idx_ex ON bronze_products(category);
CREATE INDEX IF NOT EXISTS idx_ex ON bronze_products(category);
SELECT 'ran twice fine' AS ok;
```

```
ok
---------------
ran twice fine
```

For indexes specifically, `IF NOT EXISTS` is usually the pragmatic
choice over `DROP INDEX IF EXISTS` + `CREATE INDEX`: since an index
with a given name is either present (and already correct, if your
script hasn't changed the index's definition) or needs creating from
scratch, there's rarely a "stale old index body" problem the way
there is with view logic. If you *do* need to change an existing
index's columns, though, you'd still need `DROP INDEX` first — `CREATE
INDEX IF NOT EXISTS` alone won't update it, for the same reason
Exercise 4 showed for tables.

</details>

---

### 6. Simulate a `build.py`-style rerun after editing a view's logic

This mirrors what actually happens when someone edits one of
`project/silver/*.sql` or `project/gold/*.sql` and reruns
`python project/build.py`. On your scratch copy: create a view
`ex_gold_v1` that groups `bronze_sales` by raw `channel` (messy,
4 variants). Query it. Then, using the `DROP VIEW IF EXISTS` +
`CREATE VIEW` pattern, redefine the *same* view name with cleaned-up
grouping logic (normalize `channel` before grouping). Query it again
— confirm the view now reflects the new logic, with no separate
"migration" step needed.

<details>
<summary>Show solution</summary>

```sql
DROP VIEW IF EXISTS ex_gold_v1;
CREATE VIEW ex_gold_v1 AS
SELECT channel, COUNT(*) AS n FROM bronze_sales GROUP BY channel;
SELECT * FROM ex_gold_v1;
```

```
channel   n
--------  ----
In-Store  3006
Online    2961
in store  2954
online    3079
```

Messy: 4 rows instead of 2, because raw `channel` has inconsistent
casing/hyphenation. Now "edit the file" and rerun the guarded pattern:

```sql
DROP VIEW IF EXISTS ex_gold_v1;
CREATE VIEW ex_gold_v1 AS
SELECT LOWER(TRIM(REPLACE(channel, '-', ' '))) AS channel_key, COUNT(*) AS n
FROM bronze_sales GROUP BY channel_key;
SELECT * FROM ex_gold_v1;
```

```
channel_key  n
-----------  ----
in store     5960
online       6040
```

Now 2 clean rows, matching the facts sheet's channel totals exactly
(In-Store: 5,960 lines; Online: 6,040 lines). The `DROP VIEW IF
EXISTS` guard is what made this rerun safe — without it, the second
`CREATE VIEW ex_gold_v1` would have failed with "view already exists,"
exactly as in Exercise 3, and the improved logic would never have
taken effect. This is the entire reason `project/build.py` can be
rerun after any edit to any silver/gold `.sql` file and always end up
with the database matching the current state of the code.

</details>
