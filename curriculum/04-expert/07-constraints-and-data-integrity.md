# 7. Constraints and Data Integrity

<!-- nav -->
Previous: [6. Query Optimization Basics](06-query-optimization-basics.md). Next: [8. Writing Your First Gold View](08-writing-your-first-gold-view.md). Exercises: [7. Constraints and Data Integrity](../../exercises/04-expert/07-constraints-and-data-integrity.md).
<!-- /nav -->

## The idea

A constraint is a rule the database enforces on every write, forever
— not a rule you hope application code remembers to check. `PRIMARY
KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` are the four workhorse
constraint types, and they're the single biggest structural difference
between Oakhaven's bronze layer and a "real" production schema.

Reread the note at the top of `project/docs/data_dictionary.md`:

> Bronze tables are the raw, as-ingested layer: no primary keys, no
> foreign keys, no CHECK constraints. That absence is deliberate...

Every category of messiness you've cleaned up in Tiers 2–3 —
duplicate near-people, orphan `customer_id`/`product_id` values in
`bronze_sales`, negative quantities, mixed-boolean text instead of
real booleans — is messiness that constraints exist specifically to
prevent *at write time*, before it ever becomes a downstream cleaning
problem.

## The four constraint types

```sql
CREATE TABLE demo_customers (
    customer_id INTEGER PRIMARY KEY,              -- unique, non-null, identifies each row
    email       TEXT UNIQUE,                       -- no two rows may share a value
    is_active   INTEGER CHECK (is_active IN (0, 1)) -- only these values allowed
);

CREATE TABLE demo_sales (
    order_id      INTEGER,
    order_line_id INTEGER,
    customer_id   INTEGER NOT NULL,
    quantity      INTEGER CHECK (quantity > 0),
    PRIMARY KEY (order_id, order_line_id),          -- composite PK
    FOREIGN KEY (customer_id) REFERENCES demo_customers(customer_id)
);
```

- **`PRIMARY KEY`** — uniquely identifies each row; implicitly `NOT
  NULL` and `UNIQUE`. Can be a single column or, as above, a
  composite of multiple columns (mirroring `bronze_sales`'s real grain
  of `(order_id, order_line_id)`).
- **`FOREIGN KEY`** — requires a value to exist as a `PRIMARY KEY` (or
  `UNIQUE`) value in another table, or be `NULL`. This is what
  guarantees referential integrity between tables.
- **`UNIQUE`** — no two rows may share the same value in that column
  (or column combination), but unlike `PRIMARY KEY`, `NULL`s are
  allowed and multiple `NULL`s don't count as duplicates of each
  other.
- **`CHECK`** — an arbitrary boolean expression that must be true (or
  `NULL`) for every row; the general-purpose "custom rule" constraint.

**Important SQLite-specific gotcha:** foreign keys are **off by
default** in SQLite, for backward-compatibility reasons. You must run
`PRAGMA foreign_keys = ON;` per connection for `FOREIGN KEY` clauses
to actually be enforced — declaring them in `CREATE TABLE` alone does
nothing without this pragma. (`project/build.py` explicitly sets
`PRAGMA foreign_keys = OFF;` before creating bronze — a deliberate,
documented choice, not an oversight.)

## Verified examples

All against a **scratch copy** — every example here is a write:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

### Example 1 — the real orphan-FK problem bronze actually has

`bronze_sales` has no `FOREIGN KEY` on `customer_id` or `product_id`.
Per `project/docs/facts_sheet.md`, that absence let real orphan rows
accumulate:

```sql
SELECT COUNT(*) FROM bronze_sales s
WHERE NOT EXISTS (SELECT 1 FROM bronze_customers c WHERE c.customer_id = s.customer_id);
```

```
103
```

```sql
SELECT COUNT(*) FROM bronze_sales s
WHERE NOT EXISTS (SELECT 1 FROM bronze_products p WHERE p.product_id = s.product_id);
```

```
122
```

103 order lines reference a `customer_id` that doesn't exist anywhere
in `bronze_customers`; 122 reference a nonexistent `product_id`. These
aren't hypothetical — they're real rows in the actual database,
exactly matching the facts sheet. `silver_sales.sql` has to surface
them defensively via `is_customer_orphan`/`is_product_orphan` columns
(computed with `NOT EXISTS`) precisely *because* nothing stopped them
from being written in the first place.

### Example 2 — a foreign key would have rejected every one of them

Build a small, properly-constrained analog:

```sql
CREATE TABLE demo_customers (
    customer_id INTEGER PRIMARY KEY,
    email TEXT UNIQUE,
    is_active INTEGER CHECK (is_active IN (0, 1))
);
CREATE TABLE demo_sales (
    order_id INTEGER,
    order_line_id INTEGER,
    customer_id INTEGER NOT NULL,
    quantity INTEGER CHECK (quantity > 0),
    PRIMARY KEY (order_id, order_line_id),
    FOREIGN KEY (customer_id) REFERENCES demo_customers(customer_id)
);
INSERT INTO demo_customers (customer_id, email, is_active) VALUES (1, 'a@x.com', 1), (2, 'b@x.com', 0);

PRAGMA foreign_keys = ON;
INSERT INTO demo_sales VALUES (100, 1, 1, 3);
SELECT * FROM demo_sales;
```

```
order_id  order_line_id  customer_id  quantity
--------  -------------  -----------  --------
100       1              1            3
```

A valid row, referencing `customer_id = 1`, which really exists.
Now the exact class of write that produced 103 orphan rows in bronze:

```sql
INSERT INTO demo_sales VALUES (101, 1, 9999, 2);
```

```
Runtime error near line 2: FOREIGN KEY constraint failed (19)
```

Rejected immediately, at insert time — `customer_id = 9999` doesn't
exist in `demo_customers`. This is the entire point of a foreign key:
it makes an orphan reference structurally impossible to write, instead
of something you discover later via a `NOT EXISTS` cleanup query.

### Example 3 — CHECK, UNIQUE, and PRIMARY KEY, each catching a real bronze problem

```sql
-- CHECK: bronze_sales.quantity has 359 negative rows and 212 zero rows (facts sheet)
INSERT INTO demo_sales VALUES (102, 1, 1, -5);
```

```
Error: stepping, CHECK constraint failed: quantity > 0 (19)
```

```sql
-- UNIQUE: bronze_products has 4 rows sharing 2 duplicated SKUs (facts sheet)
INSERT INTO demo_customers (customer_id, email, is_active) VALUES (3, 'a@x.com', 1);
```

```
Error: stepping, UNIQUE constraint failed: demo_customers.email (19)
```

```sql
-- PRIMARY KEY: nothing stops a duplicate (order_id, order_line_id) in bronze
INSERT INTO demo_sales VALUES (100, 1, 2, 1);
```

```
Error: stepping, UNIQUE constraint failed: demo_sales.order_id, demo_sales.order_line_id (19)
```

```sql
-- CHECK: bronze_customers.is_active is free-text ('Y','n','true','0',...) instead of a real boolean
INSERT INTO demo_customers (customer_id, email, is_active) VALUES (4, 'd@x.com', 5);
```

```
Error: stepping, CHECK constraint failed: is_active IN (0, 1) (19)
```

Four constraint violations, four real bronze messiness patterns each
one would have caught at the moment of insertion rather than requiring
a cleanup view downstream.

## Why bronze still doesn't have them

It's worth being explicit about *why* this project's bronze layer
deliberately omits constraints, rather than treating it as a mistake
to fix: bronze exists to model **raw, as-ingested data from systems
you don't control** — a legacy application's export, a third-party
feed, a spreadsheet upload. In the real world, you frequently don't
get to add constraints to the *source* system. The medallion
architecture's answer isn't "reject bad data on the way in" (bronze
can't, by definition) — it's "capture it as-is, then clean and
validate it explicitly in silver," which is exactly what
`silver_sales.is_customer_orphan`/`is_product_orphan` do: surface the
problem rather than pretend it doesn't exist.

## Common mistakes

- **Forgetting `PRAGMA foreign_keys = ON;`.** Without it, SQLite
  parses and stores `FOREIGN KEY` clauses but never enforces them —
  orphan inserts will silently succeed. This is the single most common
  "why didn't my constraint work" surprise in SQLite specifically.
- **Assuming constraints "clean up" existing bad data.** They don't —
  a constraint only stops *future* writes that would violate it. If
  `bronze_sales` already had constraints added retroactively, the 103
  existing orphan rows wouldn't be deleted or fixed; the `ALTER
  TABLE`/rebuild adding the constraint would likely just fail outright
  until the bad rows were dealt with first.
- **Adding an FK without an index on the referencing column.** SQLite
  doesn't automatically index foreign key columns (some other engines
  do) — pair a `FOREIGN KEY` with `CREATE INDEX` on that column if
  you'll be joining or filtering on it often (Module 5).
- **Confusing `CHECK` with application-level validation.** A `CHECK`
  constraint runs inside the database, on every write, regardless of
  which application or script performs it — a strictly stronger
  guarantee than "our app's form validation checks this."

## Key takeaways

- `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` enforce rules at
  write time — the database refuses invalid writes rather than
  accepting them and requiring cleanup later.
- Bronze's *actual* orphan-FK counts — 103 orphan `customer_id`, 122
  orphan `product_id` in `bronze_sales` — are real consequences of
  having no `FOREIGN KEY` constraints; verified above, a constrained
  table would have rejected every one of those inserts.
- SQLite requires `PRAGMA foreign_keys = ON;` per connection — `FOREIGN
  KEY` clauses alone are not enough.
- Constraints prevent *future* bad writes; they don't retroactively
  fix data already in a table.
- This is precisely why the medallion architecture separates
  "raw/unconstrained" (bronze) from "cleaned/validated" (silver) —
  bronze often can't add constraints (you don't control the source),
  so validation happens explicitly downstream instead.

---

<!-- nav -->
Previous: [6. Query Optimization Basics](06-query-optimization-basics.md). Next: [8. Writing Your First Gold View](08-writing-your-first-gold-view.md). Exercises: [7. Constraints and Data Integrity](../../exercises/04-expert/07-constraints-and-data-integrity.md).
<!-- /nav -->
