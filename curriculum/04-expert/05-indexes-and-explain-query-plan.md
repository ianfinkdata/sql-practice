# 5. Indexes and EXPLAIN QUERY PLAN


<!-- nav -->
Previous: [4. Views](04-views.md). Next: [6. Query Optimization Basics](06-query-optimization-basics.md).
<!-- /nav -->

## The idea

Without an index, finding rows that match a `WHERE` condition means
SQLite checking every single row in the table, one at a time — a
**full table scan**. That's fine for a handful of rows. It gets slow
as tables grow, because the work scales linearly with row count: twice
the rows, twice the work, every single query.

An **index** is a separate, sorted data structure (a B-tree, under the
hood) built on one or more columns, that lets SQLite jump straight to
matching rows instead of checking every one. Think of it like a book's
index: instead of reading every page to find "SQLite," you look up
"SQLite" in the back, alphabetically sorted, and jump straight to the
right pages.

`EXPLAIN QUERY PLAN` is how you *see* whether SQLite is scanning or
searching — it doesn't run the query, it shows you the strategy
SQLite's query planner picked for it.

## Syntax

```sql
CREATE INDEX index_name ON table_name(column_name);
CREATE INDEX index_name ON table_name(col1, col2);  -- composite index

DROP INDEX index_name;

EXPLAIN QUERY PLAN
SELECT ...;
```

## Verified examples

All against a **scratch copy**, on `bronze_sales` — big enough (12,000
rows) for the scan-vs-search difference to actually matter:

```bash
cp project/oakhaven.db /tmp/scratch_expert.db
sqlite3 /tmp/scratch_expert.db
```

### Example 1 — before an index: a full table scan

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_sales WHERE customer_id = 41;
```

```
QUERY PLAN
`--SCAN bronze_sales
```

`SCAN bronze_sales` means exactly what it says: SQLite walks every row
in the table checking `customer_id = 41`. With `.timer on`:

```sql
SELECT COUNT(*) FROM bronze_sales WHERE customer_id = 41;
```

```
43
Run Time: real 0.010 user 0.008556 sys 0.002191
```

### Example 2 — after an index: a search

```sql
CREATE INDEX idx_bronze_sales_customer_id ON bronze_sales(customer_id);

EXPLAIN QUERY PLAN
SELECT * FROM bronze_sales WHERE customer_id = 41;
```

```
QUERY PLAN
`--SEARCH bronze_sales USING INDEX idx_bronze_sales_customer_id (customer_id=?)
```

`SEARCH ... USING INDEX` means SQLite went straight to the matching
rows via the index's B-tree instead of scanning every row. Same query,
same result:

```sql
SELECT COUNT(*) FROM bronze_sales WHERE customer_id = 41;
```

```
43
Run Time: real 0.003 user 0.003125 sys 0.000185
```

At 12,000 rows the wall-clock difference (10ms → 3ms) is modest — but
notice the *plan* changed completely, and the row count is identical
either way (an index changes *how* SQLite finds rows, never *which*
rows it returns). At millions of rows, that scan-vs-search difference
is the entire ballgame between a query that returns instantly and one
that times out.

### Example 3 — SQLite's query planner sometimes builds its own index on the fly

```sql
DROP INDEX idx_bronze_sales_customer_id;

EXPLAIN QUERY PLAN
SELECT s.order_id, p.product_name
FROM bronze_sales s
JOIN bronze_products p ON p.product_id = s.product_id
WHERE p.category = 'Climbing';
```

```
QUERY PLAN
|--SCAN p
|--BLOOM FILTER ON s (product_id=?)
`--SEARCH s USING AUTOMATIC COVERING INDEX (product_id=?)
```

With no index on `bronze_sales.product_id`, SQLite's planner
recognized the join would benefit from one and built a temporary
**automatic covering index** in memory just for this query, plus a
Bloom filter to cheaply reject non-matching rows before the full
search. This is the query planner doing its best without help — but a
temporary index is rebuilt every single time the query runs, which is
wasted work for a query you run often.

### Example 4 — a real, persistent index removes the "AUTOMATIC" workaround

```sql
CREATE INDEX idx_bronze_sales_product_id ON bronze_sales(product_id);

EXPLAIN QUERY PLAN
SELECT s.order_id, p.product_name
FROM bronze_sales s
JOIN bronze_products p ON p.product_id = s.product_id
WHERE p.category = 'Climbing';
```

```
QUERY PLAN
|--SCAN p
`--SEARCH s USING INDEX idx_bronze_sales_product_id (product_id=?)
```

Same strategy, but now backed by a real index that persists across
queries instead of being rebuilt from scratch every time.

```sql
PRAGMA index_list(bronze_sales);
```

```
0|idx_bronze_sales_product_id|0|c|0
```

`PRAGMA index_list(table_name)` lists every index defined on a table —
useful for auditing what indexes already exist before deciding whether
you need a new one.

## How this connects to Oakhaven

Bronze tables have zero indexes beyond SQLite's implicit rowid — that
follows directly from having no `PRIMARY KEY`/`UNIQUE` constraints
(Module 7), since those are what typically create indexes as a side
effect. Every query you've run against bronze/silver/gold so far has
been a full scan under the hood. At Oakhaven's scale (thousands, not
millions, of rows) that's invisible. If this were a production
warehouse with years of sales history, `bronze_sales.customer_id` and
`bronze_sales.product_id` would be prime index candidates — exactly
the columns `fact_sales` joins against `dim_customer` and
`dim_product` on every query.

## Common mistakes

- **Indexing every column "just in case."** Indexes speed up reads but
  slow down writes (every `INSERT`/`UPDATE`/`DELETE` has to update
  every index on that table too) and take up disk space. Index
  columns you actually filter, join, or sort on — not everything.
- **Expecting an index to help a query that doesn't filter selectively
  enough.** An index on a column with only 2 distinct values (like a
  boolean-ish `is_active`) rarely helps much — half the table matches
  either way, so SQLite may reasonably choose a scan anyway. Indexes
  pay off most on columns with high selectivity (many distinct
  values, like an ID).
- **Assuming `CREATE INDEX` changes query results.** It never does —
  only the *strategy* SQLite uses to find the same rows. If a query's
  output changes after adding an index, the index isn't the cause;
  look elsewhere.
- **Forgetting to check `EXPLAIN QUERY PLAN` before assuming an index
  is being used.** SQLite's planner decides at query time whether an
  index actually helps for that specific query — creating one doesn't
  guarantee it's used. Verify with `EXPLAIN QUERY PLAN`, don't assume.
- **Running `CREATE INDEX` against the shared `project/oakhaven.db`.**
  Always work on a scratch copy.

## Key takeaways

- No index means a full table `SCAN`; a matching index lets SQLite
  `SEARCH` via a sorted B-tree instead — verified above on
  `bronze_sales`, going from `SCAN` to `SEARCH USING INDEX`.
- `EXPLAIN QUERY PLAN` shows the strategy without running the query —
  always check it before assuming an index is (or isn't) helping.
- SQLite's planner can build temporary "automatic covering indexes"
  for a single query; a real `CREATE INDEX` persists and avoids
  rebuilding that structure every time.
- `PRAGMA index_list(table_name)` shows what indexes already exist.
- Indexes trade write speed and disk space for read speed — index
  what you actually filter/join/sort on, not everything.

---

<!-- nav -->
Previous: [4. Views](04-views.md). Next: [6. Query Optimization Basics](06-query-optimization-basics.md).
<!-- /nav -->
