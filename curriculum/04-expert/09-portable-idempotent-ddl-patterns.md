# 9. Portable, Idempotent DDL Patterns


<!-- nav -->
Previous: [8. Writing Your First Gold View](08-writing-your-first-gold-view.md). Next: [Tier 5 — Master](../05-master/README.md).
<!-- /nav -->

## The idea

**Idempotent** means "running it twice has the same effect as running
it once." An idempotent build script can be rerun safely, any number
of times, without erroring out or leaving things in an inconsistent
state. This matters enormously for DDL specifically, because plain
`CREATE TABLE`/`CREATE VIEW` are **not** idempotent by default — run
either one twice against an object that already exists, and SQLite
raises an error.

`project/build.py` is designed to be rerun constantly — every time you
or a classmate wants a fresh copy of Oakhaven, `python project/build.py`
runs again from scratch. That only works cleanly because every DDL
statement in `project/bronze/`, `project/silver/`, and `project/gold/`
follows an idempotent pattern.

## The pattern: `DROP ... IF EXISTS` then `CREATE ...`

```sql
DROP VIEW IF EXISTS view_name;
CREATE VIEW view_name AS
SELECT ...;
```

or, for a table:

```sql
DROP TABLE IF EXISTS table_name;
CREATE TABLE table_name (...);
```

The `IF EXISTS` is what makes the `DROP` safe to run even the *first*
time, when the object doesn't exist yet — without it, the very first
run of a fresh database would fail on `DROP TABLE table_name` because
there's nothing to drop yet. Combined, `DROP ... IF EXISTS` followed
by an unconditional `CREATE` guarantees the object ends up in exactly
the state the `CREATE` statement describes, no matter how many times
you run it, and no matter whether it existed before.

## Why not `CREATE OR REPLACE VIEW`?

If you've used Postgres or MySQL, you'd reach for `CREATE OR REPLACE
VIEW` here — a single statement that does the drop-and-recreate for
you. **SQLite does not support this syntax at all:**

```sql
CREATE OR REPLACE VIEW demo_v AS SELECT 1;
```

```
Error: in prepare, near "OR": syntax error
  CREATE OR REPLACE VIEW demo_v AS SELECT 1;
         ^--- error here
```

This is a genuine portability gap, not a style choice — SQL written
for Postgres/MySQL that uses `CREATE OR REPLACE VIEW` simply will not
run against SQLite. The two-statement `DROP VIEW IF EXISTS` +
`CREATE VIEW` pattern is the *only* way to get equivalent behavior in
SQLite, and it's exactly what every one of Oakhaven's silver and gold
view files uses.

## Verified: the failure mode this pattern prevents

All against a **scratch copy**:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

### Without the guard — fails on the second run

```sql
CREATE VIEW demo_v2 AS SELECT 1 AS x;
CREATE VIEW demo_v2 AS SELECT 1 AS x;   -- run again, unmodified
```

```
Error: in prepare, view demo_v2 already exists
  CREATE VIEW demo_v2 AS SELECT 1 AS x;
              ^--- error here
```

This is exactly the error a naive build script would hit on its
*second* run — the entire point of a rerunnable build breaks on the
very first rerun.

### With the guard — safe to run any number of times, and picks up changes

```sql
DROP VIEW IF EXISTS demo_v3;
CREATE VIEW demo_v3 AS SELECT 1 AS x;
DROP VIEW IF EXISTS demo_v3;
CREATE VIEW demo_v3 AS SELECT 2 AS x;   -- a *different* definition this time
SELECT * FROM demo_v3;
```

```
2
```

Not just "no error" — the view's definition was genuinely replaced.
This matters for a real workflow: if you edit `project/gold/agg_daily_sales.sql`
and rerun the build, the idempotent pattern guarantees the *new* SQL
in that file wins, not a stale cached definition from a previous run.

### Confirming the pattern is used consistently across the real project

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

All 13 view-defining `.sql` files in silver and gold — every single
one — start with exactly this guard. It's not an occasional
convenience; it's a project-wide convention.

`project/bronze/schema.sql` uses the table equivalent for the same
reason:

```sql
DROP TABLE IF EXISTS bronze_customers;
CREATE TABLE bronze_customers (...);
```

(repeated for all five bronze tables). `CREATE TABLE IF NOT EXISTS`
would *also* be idempotent in a narrow sense — it wouldn't error on a
rerun — but it would silently **keep the old table's schema and data**
if the table already existed, which is the wrong behavior for a
generator that's supposed to produce a fresh, byte-identical dataset
every time. `DROP ... IF EXISTS` + unconditional `CREATE` is the right
choice specifically because bronze *wants* a clean slate on every
rebuild, not a merge with whatever was there before.

## How `project/build.py` relies on this

`build.py` itself takes an even more direct approach at the top level
— it deletes `project/oakhaven.db` outright and reconnects to a fresh
file (`os.remove(DB_PATH)` before `sqlite3.connect(DB_PATH)`), so the
per-object `DROP ... IF EXISTS` guards inside `schema.sql` and the
silver/gold `.sql` files are technically redundant *at that specific
call site*. But those same `.sql` files are also designed to be
**runnable standalone** — for instance, `bronze/calendar_recursive_cte.sql`
is explicitly documented as runnable on its own, and any of the
silver/gold `.sql` files could reasonably be re-executed by hand
against an existing database while debugging a single view. The
`DROP ... IF EXISTS` guard is what makes that safe: rerun any one file
in isolation, anytime, without first checking whether its object
already exists.

## Common mistakes

- **Assuming `CREATE OR REPLACE VIEW` works in SQLite.** It's valid
  Postgres/MySQL syntax, invalid SQLite syntax — verified above. Use
  `DROP VIEW IF EXISTS` + `CREATE VIEW` instead.
- **Using `CREATE TABLE IF NOT EXISTS` when you actually want a clean
  rebuild.** `IF NOT EXISTS` guards make a statement idempotent but
  preserve the *existing* object if there is one — that's the wrong
  tool when the goal is "this object should end up looking exactly
  like this definition," which is what a build/deploy script usually
  wants for views and generated tables.
- **Forgetting the guard makes a script fail on rerun, not on first
  run.** This is an easy trap: a DDL script without `IF EXISTS` works
  perfectly the first time you run it, and only breaks the *second*
  time — which can be well after you've moved on and forgotten you
  wrote it that way.
- **Dropping and recreating a table that has dependent views without
  also handling those views.** A view defined `SELECT ... FROM
  some_table` will fail at *query* time (not at the view's own
  `CREATE VIEW` time — SQLite doesn't validate view bodies against
  schema until they're queried) if `some_table` was dropped and never
  recreated. Oakhaven's `build.py` handles this by always running
  bronze schema creation before silver, and silver before gold, in a
  fixed order.

## Key takeaways

- Idempotent DDL means "safe to run any number of times" — essential
  for any build/deploy script that might be rerun.
- SQLite has **no** `CREATE OR REPLACE VIEW` (or `TABLE`) — the
  portable equivalent is `DROP ... IF EXISTS` followed by an
  unconditional `CREATE`, verified above to both avoid the "already
  exists" error and actually pick up a changed definition.
- All 13 silver/gold view files in this project, and all 5 bronze
  table definitions, follow this exact pattern — it's a project-wide
  convention, not a one-off.
- `CREATE TABLE/VIEW IF NOT EXISTS` is idempotent too, but preserves
  the old definition if one exists — the wrong choice when you want a
  rebuild to reflect the current `.sql` file's contents.

---

<!-- nav -->
Previous: [8. Writing Your First Gold View](08-writing-your-first-gold-view.md). Next: [Tier 5 — Master](../05-master/README.md).
<!-- /nav -->
