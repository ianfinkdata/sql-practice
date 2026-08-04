# 4. Views

<!-- nav -->
Previous: [3. Transactions](03-transactions.md). Next: [5. Indexes and EXPLAIN QUERY PLAN](05-indexes-and-explain-query-plan.md). Exercises: [4. Views](../../exercises/04-expert/04-views.md).
<!-- /nav -->

## The idea

A **view** is a saved `SELECT` statement that behaves like a table for
querying purposes, but stores no data of its own — every time you
query a view, the database re-runs the underlying `SELECT` against
the live data. This is different from a **materialized view** (a
feature some other engines offer, and one SQLite does not have at
all): a materialized view *does* store its result set on disk, and has
to be explicitly refreshed when the underlying data changes.

Oakhaven's entire silver and gold layers — everything you've queried
in Tiers 2 and 3, like `silver_customers`, `silver_sales`,
`dim_product`, `fact_sales`, `agg_monthly_sales_by_category` — are
plain SQLite views, not tables. Not one of them stores a single row.
Every one of `project/silver/*.sql` and `project/gold/*.sql` is a
`CREATE VIEW` statement wrapping a `SELECT`.

## Why views, not tables, for silver/gold

This is a deliberate architectural choice with a real trade-off:

**Always fresh, no refresh step.** Because a view has no stored data,
there's no "last refreshed at..." staleness to worry about, and no
separate job that has to run to keep silver/gold in sync with bronze.
Change a bronze row, and every view built on top of it reflects that
change on the very next query — instantly, with no rebuild.

**Recompute cost, every single query.** The flip side: SQLite
re-executes the *entire* view definition (all the `CASE` expressions,
`JOIN`s, window functions) every time you query it, and every time you
query something built *on top of* it. `fact_sales` is a view over
`silver_sales`, which is itself a view over `bronze_sales` — a query
against `agg_monthly_sales_by_category` (a view over `fact_sales`,
`dim_date`, and `dim_product`) recomputes the entire chain, bronze
cleaning included, on every execution. For Oakhaven's ~12,000-row
`bronze_sales`, that cost is negligible. At real production scale
(millions or billions of rows), a chain of views this deep can become
a real performance problem — which is exactly the kind of situation
that motivates materialized tables (or, in engines that support them,
materialized views) instead.

For a learning project built around a dataset this size, "always
correct, recomputed cheaply" beats "fast, but needs a refresh
pipeline to trust." That's the trade Oakhaven makes.

## CREATE VIEW syntax

```sql
CREATE VIEW view_name AS
SELECT ...
FROM ...
[JOIN ...]
[WHERE ...]
[GROUP BY ...];
```

A view can be queried exactly like a table: `SELECT ... FROM
view_name WHERE ...`, joined to other tables/views, aggregated, and so
on. It cannot (in standard use) be the target of `INSERT`/`UPDATE`/
`DELETE` unless you set up an `INSTEAD OF` trigger — out of scope
here, and not used anywhere in this project.

## Verified examples

### Example 1 — a view reflects underlying changes immediately, no refresh needed

This one modifies data, so it runs against a **scratch copy**:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

```sql
SELECT product_id, category FROM bronze_products WHERE product_id = 1;
SELECT product_id, category FROM silver_products WHERE product_id = 1;
```

```
product_id  category
----------  --------
1           footwear

product_id  category
----------  --------
1           Footwear
```

Now change the raw bronze value to a *different* messy variant of the
same category:

```sql
UPDATE bronze_products SET category = 'FOOTWEAR  ' WHERE product_id = 1;
SELECT product_id, category FROM silver_products WHERE product_id = 1;
```

```
product_id  category
----------  --------
1           Footwear
```

No `REFRESH`, no rebuild step — `silver_products` picked up the new
raw value and normalized it correctly the instant it was queried,
because the view's `SELECT` runs fresh every time.

### Example 2 — dissecting `silver_products.sql`

This is a real view definition, read directly from
`project/silver/silver_products.sql` (read-only — no scratch copy
needed to *read* a `.sql` file):

```sql
DROP VIEW IF EXISTS silver_products;
CREATE VIEW silver_products AS
WITH base AS (
    SELECT
        p.product_id,
        TRIM(p.product_name) AS product_name,
        LOWER(TRIM(REPLACE(p.category, '  ', ' '))) AS category_key,
        NULLIF(TRIM(p.subcategory), '') AS subcategory,
        TRIM(p.brand) AS brand,
        p.unit_cost AS unit_cost,
        p.unit_price AS unit_price,
        p.is_discontinued AS is_discontinued_raw,
        TRIM(p.sku) AS sku,
        p.weight_kg AS weight_kg_raw,
        p.created_at AS created_at_raw
    FROM bronze_products p
)
SELECT
    product_id,
    product_name,
    CASE category_key
        WHEN 'footwear' THEN 'Footwear'
        WHEN 'foot wear' THEN 'Footwear'
        -- ... 8 more WHEN branches for the remaining canonical categories
        ELSE NULL
    END AS category,
    subcategory,
    brand,
    unit_cost,
    unit_price,
    CASE
        WHEN LOWER(TRIM(is_discontinued_raw)) IN ('y', 'yes', 'true', '1') THEN 1
        WHEN LOWER(TRIM(is_discontinued_raw)) IN ('n', 'no', 'false', '0') THEN 0
        ELSE NULL
    END AS is_discontinued,
    sku,
    COUNT(*) OVER (PARTITION BY sku) > 1 AS sku_is_duplicate,
    CASE
        WHEN weight_kg_raw IS NULL THEN NULL
        WHEN weight_kg_raw LIKE '% kg' THEN CAST(TRIM(REPLACE(weight_kg_raw, ' kg', '')) AS REAL)
        ELSE CAST(weight_kg_raw AS REAL)
    END AS weight_kg,
    CASE
        WHEN created_at_raw IS NULL THEN NULL
        WHEN created_at_raw LIKE '__/__/____'
            THEN substr(created_at_raw, 7, 4) || '-' || substr(created_at_raw, 1, 2) || '-' || substr(created_at_raw, 4, 2)
        WHEN created_at_raw LIKE '____-__-__ __:__:__' THEN substr(created_at_raw, 1, 10)
        WHEN created_at_raw LIKE '____-__-__' THEN created_at_raw
        ELSE NULL
    END AS created_at
FROM base;
```

Breaking down what's actually happening, clause by clause:

- **The `DROP VIEW IF EXISTS` / `CREATE VIEW` pair** is the idempotent
  pattern Module 9 covers in depth — it lets `project/build.py` rerun
  this file safely every time.
- **The `base` CTE** does two jobs at once: aliasing raw columns with
  a `_raw`/`_key` suffix so the outer `SELECT` can tell "cleaned" from
  "not yet cleaned" apart at a glance, and doing the *cheap*
  normalization (`TRIM`, `LOWER`, `REPLACE('  ', ' ')`) once, so it
  isn't repeated across multiple `CASE` branches downstream.
- **The `category` `CASE` expression** maps all ~40 raw casing/spacing
  variants observed in bronze (`ACCESSORIES `, `Camping and Hiking`,
  `Foot Wear`, etc. — see the facts sheet) down to exactly 8 canonical
  names. Note the `ELSE NULL`: any variant the `base` CTE's
  normalization didn't anticipate becomes `NULL` rather than silently
  passing through a wrong value — a deliberate "fail loud, not
  quiet" choice.
- **`is_discontinued`'s `CASE`** coalesces the mixed-boolean text pool
  (`Y`/`N`/`y`/`n`/`true`/`false`/`1`/`0`/`yes`/`no`/`NULL`) down to a
  real `0`/`1` integer — the same pattern reused for `is_active` in
  `silver_customers` and `is_manager` in `silver_employees`.
- **`sku_is_duplicate` uses a window function**, `COUNT(*) OVER
  (PARTITION BY sku) > 1`, computed *inside a view* — proof that a
  view isn't limited to simple filtering; it can carry the full
  expressive power of a `SELECT`, window functions included.
- **`weight_kg`'s `CASE`** demonstrates parsing dirty `TEXT` into a
  real `REAL`: strip a trailing `" kg"` suffix if present, then `CAST`
  to `REAL` either way. This is the type-affinity discussion from
  Module 1 in action — `weight_kg_raw` is declared `TEXT` in bronze
  specifically *because* it holds non-numeric-looking values like
  `"1.2 kg"` that a `REAL`-affinity column couldn't store faithfully.
- **`created_at`'s `CASE`** is the same three-format date parser
  (`MM/DD/YYYY`, `YYYY-MM-DD HH:MM:SS`, `YYYY-MM-DD`) used verbatim
  across `silver_customers.signup_date`, `silver_employees.hire_date`/
  `termination_date`, and `silver_sales.order_date`/`ship_date` — a
  pattern repeated rather than centralized, since SQLite views can't
  call user-defined functions without a custom SQLite build.

Real output confirming the SKU-collision window function actually
works:

```sql
SELECT product_id, sku, sku_is_duplicate
FROM silver_products WHERE sku_is_duplicate = 1 ORDER BY sku;
```

```
product_id  sku       sku_is_duplicate
----------  --------  ----------------
85          WAT-0095  1
95          WAT-0095  1
129         WIN-0129  1
144         WIN-0129  1
```

Exactly the 4 rows (2 SKUs × 2 products each) the facts sheet
documents.

## Common mistakes

- **Assuming a view caches its result.** It doesn't (not in SQLite,
  and not by default in most engines that call it a plain "view").
  Every query against a view re-executes its `SELECT` from scratch.
- **Forgetting a chain of views compounds recompute cost.**
  `agg_monthly_sales_by_category` → `fact_sales` → `silver_sales` →
  `bronze_sales` means querying the aggregate re-runs the cleaning
  logic in `silver_sales` every time, even though that logic never
  changed. Fine at Oakhaven's scale; worth knowing about at larger
  scale.
- **Trying to `CREATE OR REPLACE VIEW`.** SQLite doesn't support that
  syntax — you must `DROP VIEW IF EXISTS` first, then `CREATE VIEW`
  (Module 9 covers this pattern and why it matters for a rerunnable
  build script).
- **Writing to a view directly** (`INSERT`/`UPDATE`/`DELETE` against
  `silver_products`, for instance) and expecting it to work like a
  table. It will fail (or silently do nothing useful) unless
  `INSTEAD OF` triggers are set up — none exist in this project.

## Key takeaways

- A view is a saved `SELECT`, re-executed fresh on every query — it
  stores no data of its own, unlike a materialized view/table.
- Oakhaven's silver and gold layers are entirely views: always
  correct relative to bronze, at the cost of recomputing the full
  cleaning/aggregation chain on every query.
- `silver_products` shows a view can include CTEs, multi-branch
  `CASE` normalization, and window functions — the full power of
  `SELECT`, not just simple filtering.
- `DROP VIEW IF EXISTS` before `CREATE VIEW` is the idempotent pattern
  used throughout `project/silver/` and `project/gold/` (Module 9).

---

<!-- nav -->
Previous: [3. Transactions](03-transactions.md). Next: [5. Indexes and EXPLAIN QUERY PLAN](05-indexes-and-explain-query-plan.md). Exercises: [4. Views](../../exercises/04-expert/04-views.md).
<!-- /nav -->
