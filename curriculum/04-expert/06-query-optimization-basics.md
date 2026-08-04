# 6. Query Optimization Basics


<!-- nav -->
Previous: [5. Indexes and EXPLAIN QUERY PLAN](05-indexes-and-explain-query-plan.md). Next: [7. Constraints and Data Integrity](07-constraints-and-data-integrity.md).
<!-- /nav -->

## The idea

Module 5 showed *that* indexes change `SCAN` into `SEARCH`. This
module is about writing queries that actually let SQLite use an index
when one exists — because it's entirely possible to have the right
index in place and still get a full scan, just by phrasing a
`WHERE` clause the wrong way.

A predicate that *can* use an index is called **sargable** ("Search
ARGument-able"). The core idea: SQLite can only use an index to jump
straight to matching rows if it can look up the *raw, unmodified*
column value in the index. The moment you wrap the indexed column in a
function or transform it, the index — which stores the original
values — can no longer be searched directly; SQLite falls back to
checking every row.

## Principle 1: don't wrap the indexed column in a function

```sql
CREATE INDEX idx_bronze_customers_email ON bronze_customers(email);

EXPLAIN QUERY PLAN
SELECT * FROM bronze_customers WHERE email = 'test@example.com';
```

```
QUERY PLAN
`--SEARCH bronze_customers USING INDEX idx_bronze_customers_email (email=?)
```

Now the same logical filter, but wrapped in `LOWER()`:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_customers WHERE LOWER(email) = 'test@example.com';
```

```
QUERY PLAN
`--SCAN bronze_customers
```

Identical intent — "find this email, case-insensitively" — but the
index on `email` stores raw values, not `LOWER(email)` values, so
SQLite can't use it to look up `LOWER(email) = '...'` directly. It has
to compute `LOWER(email)` for every row to check the match, which
means visiting every row: a full scan. (SQLite does support
*expression indexes* — `CREATE INDEX ... ON table(LOWER(column))` —
which would fix this specific case; the point here is that the
*plain* index on `email` doesn't help once you wrap the column.)

## Principle 2: leading wildcards defeat LIKE, trailing wildcards don't

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_customers WHERE email LIKE '%example.com';
```

```
QUERY PLAN
`--SCAN bronze_customers
```

A leading `%` means "match anything, then this suffix" — there's no
way to binary-search a sorted index for that, so SQLite scans. But a
**trailing** wildcard (`'test%'`, "starts with") is a genuinely
sargable range condition — SQLite *can* express `LIKE 'test%'` as
`email >= 'test' AND email < 'testz...'` and search the index. It
requires case-sensitive comparison to line up with how the index is
sorted, though, so with SQLite's default case-insensitive `LIKE`:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_customers WHERE email LIKE 'test%';
```

```
QUERY PLAN
`--SCAN bronze_customers
```

...it still scans. Two ways to unlock the index for a prefix search:

```sql
PRAGMA case_sensitive_like = ON;
EXPLAIN QUERY PLAN
SELECT * FROM bronze_customers WHERE email LIKE 'test%';
```

```
QUERY PLAN
`--SEARCH bronze_customers USING INDEX idx_bronze_customers_email (email>? AND email<?)
```

or use `GLOB` instead of `LIKE` (`GLOB` is case-sensitive by default,
no pragma needed):

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_customers WHERE email GLOB 'test*';
```

```
QUERY PLAN
`--SEARCH bronze_customers USING INDEX idx_bronze_customers_email (email>? AND email<?)
```

Same `(email>? AND email<?)` range search either way — SQLite rewrote
the prefix match into a range scan it can serve from the index.

## Principle 3: avoid `SELECT *` when you don't need every column

`bronze_sales` has 14 columns:

```sql
SELECT COUNT(*) FROM pragma_table_info('bronze_sales');
```

```
14
```

`SELECT *` pulls all 14 off disk for every matching row, even if your
query only needs `order_id` and `net_amount`-adjacent fields. This
matters for three reasons that compound as tables grow:

- **More bytes read off disk** per row, for columns you'll never use.
- **More data shipped over the wire** if the database is remote
  (irrelevant for a local `.db` file, but real for client/server
  engines).
- **Covering indexes stop working.** If you had an index on exactly
  the columns a query needs, SQLite can sometimes answer the query
  *entirely from the index*, without touching the table at all — but
  only if every column the query references is in that index.
  `SELECT *` guarantees it needs a column that isn't, forcing a trip
  back to the full row.

Naming exact columns also documents intent — a reader (or your future
self) sees exactly what the query depends on, instead of "everything,
for reasons unstated."

## Principle 4: `WHERE`, not post-filtering — let SQLite prune early

Filter in the `WHERE` clause of the innermost query, not by pulling
everything into a subquery/CTE and filtering afterward, when the two
are logically equivalent. SQLite's planner is generally good at
pushing predicates down on its own, but writing the filter where the
data lives keeps intent clear and avoids relying on the planner
noticing an equivalence it might not always find, especially across
views. Recall from Module 4 that `agg_monthly_sales_by_category` is a
view over `fact_sales`, which is a view over `silver_sales`, which is
a view over `bronze_sales` — filtering as early in that chain as
possible (e.g. filtering `WHERE p.category = 'Climbing'` in a join
against `dim_product`, as in Module 5's Example 3/4) gives the planner
the best chance to use an index deep in the chain.

## When an index won't help, even sargable

Not every filter benefits from an index, even written correctly:

- **Low-selectivity columns.** A column like `channel` (only `Online`/
  `In-Store`, i.e. roughly half the table matches either value) rarely
  benefits — SQLite may reasonably decide a scan is cheaper than
  jumping around the index and then fetching each matching row
  individually. Indexes pay off most on high-selectivity columns
  (unique or near-unique IDs).
- **Small tables.** `bronze_employees` (~35 rows) will almost always
  be scanned regardless of indexing — the entire table already fits
  in a single page or two, so there's nothing meaningful to save.
- **Queries that need most of the table anyway.** If a query's `WHERE`
  clause matches 80% of rows, an index lookup (jump to index, then
  fetch each matching row from the table) can cost *more* than simply
  scanning the table in physical order. This is exactly the kind of
  call `EXPLAIN QUERY PLAN` reveals — trust it over intuition.

## Common mistakes

- **Wrapping indexed columns in functions in `WHERE`** (`LOWER(x) =`,
  `DATE(x) =`, `x + 1 =`) and then being confused why an index isn't
  used. Verified above — this alone flips `SEARCH` to `SCAN`.
- **Assuming `LIKE` with a trailing wildcard always uses an index.**
  It needs case-sensitive comparison to line up with the index; check
  `EXPLAIN QUERY PLAN`, don't assume.
- **Reflexively adding indexes without checking whether the column is
  selective enough to benefit** — see Module 5's common mistakes for
  the flip side of this.
- **`SELECT *` out of habit** in application code or reports, then
  discarding most of the columns downstream anyway.

## Key takeaways

- A predicate is **sargable** when SQLite can use it to search an
  index directly — wrapping the indexed column in a function
  (`LOWER(email) = ...`) breaks that, forcing a full scan, verified
  above.
- Leading-wildcard `LIKE '%x'` can never use an index; trailing-wildcard
  `LIKE 'x%'` can, but only with case-sensitive comparison
  (`PRAGMA case_sensitive_like = ON` or `GLOB` instead of `LIKE`).
- Select only the columns you need — it reduces I/O and keeps covering
  indexes usable.
- Not every filter benefits from an index — low selectivity and small
  tables are two real reasons a `SCAN` can beat a `SEARCH`. Always
  check `EXPLAIN QUERY PLAN` rather than assuming.

---

<!-- nav -->
Previous: [5. Indexes and EXPLAIN QUERY PLAN](05-indexes-and-explain-query-plan.md). Next: [7. Constraints and Data Integrity](07-constraints-and-data-integrity.md).
<!-- /nav -->
