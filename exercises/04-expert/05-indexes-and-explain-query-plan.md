# Exercises: Indexes and EXPLAIN QUERY PLAN

<!-- nav -->
Curriculum: [5. Indexes and EXPLAIN QUERY PLAN](../../curriculum/04-expert/05-indexes-and-explain-query-plan.md). Previous: [4. Views](04-views.md). Next: [6. Query Optimization Basics](06-query-optimization-basics.md).
<!-- /nav -->

`EXPLAIN QUERY PLAN` alone is read-only and safe against the shared
database. Any exercise involving `CREATE INDEX` must run against your
own scratch copy:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Confirm bronze has no indexes to begin with

Using `PRAGMA index_list`, confirm that `bronze_sales` and
`bronze_customers` have zero indexes defined (this is read-only —
safe against the real `project/oakhaven.db`). Then run `EXPLAIN QUERY
PLAN` on `SELECT * FROM bronze_sales WHERE order_id = 500;` and
confirm it's a full scan.

<details>
<summary>Show solution</summary>

```sql
PRAGMA index_list(bronze_sales);
PRAGMA index_list(bronze_customers);
```

```
(no rows returned for either — confirms zero indexes)
```

```sql
EXPLAIN QUERY PLAN SELECT * FROM bronze_sales WHERE order_id = 500;
```

```
QUERY PLAN
`--SCAN bronze_sales
```

No indexes, so every filter on `bronze_sales` is a full scan of all
12,000 rows, regardless of the column.

</details>

---

### 2. Add an index and watch SCAN become SEARCH

On your scratch copy, run `EXPLAIN QUERY PLAN` on `SELECT * FROM
bronze_sales WHERE employee_id = 5;` before creating any index. Then
create an index on `employee_id` and run the exact same query plan
check again.

<details>
<summary>Show solution</summary>

```sql
EXPLAIN QUERY PLAN SELECT * FROM bronze_sales WHERE employee_id = 5;
```

```
QUERY PLAN
`--SCAN bronze_sales
```

```sql
CREATE INDEX idx_es_employee ON bronze_sales(employee_id);
EXPLAIN QUERY PLAN SELECT * FROM bronze_sales WHERE employee_id = 5;
```

```
QUERY PLAN
`--SEARCH bronze_sales USING INDEX idx_es_employee (employee_id=?)
```

</details>

---

### 3. Column order matters in a composite index

On your scratch copy, create a composite index on `(order_status,
order_date)`. Then check `EXPLAIN QUERY PLAN` for two different
queries: one filtering on both columns, and one filtering *only* on
`order_date` (the second column in the index, not the first). Does
the index get used for both?

<details>
<summary>Show solution</summary>

```sql
CREATE INDEX idx_es_status_date ON bronze_sales(order_status, order_date);

EXPLAIN QUERY PLAN
SELECT * FROM bronze_sales WHERE order_status = 'Completed' AND order_date = '2023-05-15';
```

```
QUERY PLAN
`--SEARCH bronze_sales USING INDEX idx_es_status_date (order_status=? AND order_date=?)
```

```sql
EXPLAIN QUERY PLAN
SELECT * FROM bronze_sales WHERE order_date = '2023-05-15';
```

```
QUERY PLAN
`--SCAN bronze_sales
```

Filtering on both columns uses the index. Filtering *only* on
`order_date` — the second column — falls back to a full scan, because
a composite index is physically sorted first by `order_status`, then
by `order_date` within each status. Without a value for the leading
column, SQLite can't jump to the right starting point in the index;
it's like trying to use a phone book sorted by (last name, first name)
to look someone up by first name alone. The rule of thumb: put the
column you'll filter on *most often, or alone*, first in a composite
index.

</details>

---

### 4. An index changes the plan, never the result

On your scratch copy, run `SELECT COUNT(*), SUM(quantity) FROM
bronze_sales WHERE channel = 'Online';` before creating any index on
`channel`. Then create the index and run the exact same query again.
Confirm the numbers are identical — an index can never change *what*
a query returns, only *how* the database finds it.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*), SUM(quantity) FROM bronze_sales WHERE channel = 'Online';
```

```
2961|8025
```

```sql
CREATE INDEX idx_es_channel ON bronze_sales(channel);
SELECT COUNT(*), SUM(quantity) FROM bronze_sales WHERE channel = 'Online';
```

```
2961|8025
```

Identical: 2,961 matching rows, summing to 8,025 units, both times.
If adding an index ever changes a query's *results*, the index isn't
the problem — something else changed (different data, a different
predicate, a bug in the query itself).

</details>

---

### 5. Diagnose a join that isn't using an available index

On your scratch copy, create an index on `bronze_customers(customer_id)`
(note: `customer_id` isn't declared `PRIMARY KEY` in bronze, so it has
no implicit index — Module 7 covers why). Then check `EXPLAIN QUERY
PLAN` for a join between `bronze_sales` and `bronze_customers` filtered
by `bronze_customers.state`. Which table does SQLite scan, and which
does it search? Explain why, given only one side of the join has a
useful filter predicate on an indexed column.

<details>
<summary>Show solution</summary>

```sql
CREATE INDEX idx_customers_id ON bronze_customers(customer_id);

EXPLAIN QUERY PLAN
SELECT s.order_id, c.state
FROM bronze_sales s
JOIN bronze_customers c ON c.customer_id = s.customer_id
WHERE c.state = 'CA';
```

```
QUERY PLAN
|--SCAN c
`--SEARCH s USING AUTOMATIC COVERING INDEX (customer_id=?)
```

SQLite scans `bronze_customers` (`c`) — because the filter
`c.state = 'CA'` is on `state`, which has no index, `state` itself
still requires a scan to find matching customers. But once it has
each matching customer's `customer_id`, it searches `bronze_sales`
efficiently (via an automatic covering index it builds for this join,
since `bronze_sales.customer_id` also has no persistent index in this
exercise). The `idx_customers_id` index you created doesn't help this
particular query at all — it would help a query that filters
`bronze_customers` *by* `customer_id`, not one that filters by
`state` and only joins on `customer_id`. This is a good illustration
of matching the index to the actual filter column, not just any
column that happens to be involved in the query.

</details>

---

### 6. Design the right index for a real Oakhaven query pattern

Consider this query, which mirrors a realistic "recent orders for a
customer" lookup:

```sql
SELECT order_id, order_date, quantity, unit_price
FROM bronze_sales
WHERE customer_id = 41
ORDER BY order_date DESC;
```

On your scratch copy: check the plan with no index, design and create
a single index that would help both the `WHERE` and the `ORDER BY`
in one structure, then confirm the plan improved.

<details>
<summary>Show solution</summary>

```sql
EXPLAIN QUERY PLAN
SELECT order_id, order_date, quantity, unit_price
FROM bronze_sales
WHERE customer_id = 41
ORDER BY order_date DESC;
```

```
QUERY PLAN
|--SCAN bronze_sales
`--USE TEMP B-TREE FOR ORDER BY
```

Two costs here: a full scan for the filter, *and* a temporary sort
structure built just for `ORDER BY`. A composite index on
`(customer_id, order_date)` can fix both at once — the leading column
serves the `WHERE customer_id = 41` filter, and because rows within
each `customer_id` are already stored sorted by `order_date` in the
index, SQLite can walk them in that order directly instead of
building a separate sort structure:

```sql
CREATE INDEX idx_es_customer_date ON bronze_sales(customer_id, order_date);

EXPLAIN QUERY PLAN
SELECT order_id, order_date, quantity, unit_price
FROM bronze_sales
WHERE customer_id = 41
ORDER BY order_date DESC;
```

```
QUERY PLAN
`--SEARCH bronze_sales USING INDEX idx_es_customer_date (customer_id=?)
```

No more `SCAN`, and no more separate `TEMP B-TREE FOR ORDER BY` step
— one index serves both the filter and the sort.

</details>

---

<!-- nav -->
Curriculum: [5. Indexes and EXPLAIN QUERY PLAN](../../curriculum/04-expert/05-indexes-and-explain-query-plan.md). Previous: [4. Views](04-views.md). Next: [6. Query Optimization Basics](06-query-optimization-basics.md).
<!-- /nav -->
