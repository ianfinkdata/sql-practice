# Exercises: Views

<!-- nav -->
Curriculum: [4. Views](../../curriculum/04-expert/04-views.md). Previous: [3. Transactions](03-transactions.md). Next: [5. Indexes and EXPLAIN QUERY PLAN](05-indexes-and-explain-query-plan.md).
<!-- /nav -->

Exercises 1, 2, 4, and 5 are read-only (querying/reading `.sql` files
against the shared `project/oakhaven.db`). Exercise 3 modifies data —
use your own scratch copy for that one:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Confirm `silver_calendar` really is a thin pass-through

The lesson claims `silver_calendar` does almost nothing — just
renames/passes through `bronze_calendar`. Verify this two ways: (a)
compare row counts, (b) compare the first few rows of each.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_calendar;
SELECT COUNT(*) FROM silver_calendar;
```

```
7670
7670
```

```sql
SELECT * FROM bronze_calendar LIMIT 3;
SELECT * FROM silver_calendar LIMIT 3;
```

```
20180101|2018-01-01
20180102|2018-01-02
20180103|2018-01-03

20180101|2018-01-01
20180102|2018-01-02
20180103|2018-01-03
```

Identical row counts and identical values — confirming
`project/silver/silver_calendar.sql`'s own comment that it's "a thin
pass-through view." All the interesting date-part logic (year, month,
quarter, day names, weekend flag) lives one layer further downstream,
in `gold/dim_date.sql`.

</details>

---

### 2. Dissect `silver_employees.sql`

Read `project/silver/silver_employees.sql`. Identify: (a) which raw
column gets mapped through a `CASE` expression to normalize its
casing, using the same pattern as `silver_products.category`, and (b)
which two columns share *identical* date-parsing logic (down to the
exact `CASE` branches) — copy-pasted rather than factored out. Why
might that duplication be an acceptable trade-off in a SQLite view,
given SQLite views can't call reusable user-defined functions without
a custom build?

<details>
<summary>Show solution</summary>

(a) `department` and `region` are both mapped through `CASE`
expressions against their lowercased/trimmed raw values, exactly like
`silver_products.category`:

```sql
CASE department_key
    WHEN 'sales' THEN 'Sales'
    WHEN 'support' THEN 'Support'
    WHEN 'warehouse' THEN 'Warehouse'
    WHEN 'management' THEN 'Management'
    ELSE NULL
END AS department,
```

(b) `hire_date` and `termination_date` share identical three-format
date-parsing `CASE` logic (`MM/DD/YYYY`, `YYYY-MM-DD HH:MM:SS`,
`YYYY-MM-DD`) — the exact same pattern also appears independently in
`silver_customers.signup_date` and `silver_sales.order_date`/
`ship_date`.

Why it's an acceptable trade-off: SQL views (in standard SQLite,
without loading a custom extension) have no equivalent of a reusable
function you can define once and call from multiple views — every
view's `SELECT` has to be fully self-contained. The alternative to
duplicating a handful of `CASE`/`LIKE` lines four times is introducing
a custom SQLite scalar function via the C API/loadable extension,
which is far more operational complexity than a learning-focused
project like this needs. Duplication here is a small, contained,
readable cost — not a maintenance trap, since all four copies are
short and unlikely to need independent changes.

</details>

---

### 3. Watch a view update the instant its source data changes

On your scratch copy, change `bronze_employees.department` for
`employee_id = 1` to a *new* messy variant not already in the pool —
say, `'  SALES  '` (extra whitespace, all-caps). Query `silver_employees`
for that employee immediately afterward, with no rebuild step. Does it
normalize correctly?

<details>
<summary>Show solution</summary>

```sql
UPDATE bronze_employees SET department = '  SALES  ' WHERE employee_id = 1;
SELECT employee_id, department FROM silver_employees WHERE employee_id = 1;
```

```
employee_id  department
-----------  ----------
1            Sales
```

`silver_employees`'s `LOWER(TRIM(e.department))` normalization handled
the extra whitespace and casing correctly, and — because it's a view,
not a materialized table — there was no refresh step. The next query
against `silver_employees` simply re-ran the view's `SELECT` against
the now-changed `bronze_employees` row.

</details>

---

### 4. Find a view that adds almost nothing on top of the one below it

Compare `project/gold/dim_product.sql`'s column list against
`silver_products`'s output columns (from Module 4's dissection). Is
`dim_product` doing any real transformation, or is it closer to
`silver_calendar`'s "thin pass-through" pattern? What does that tell
you about the difference in *purpose* between a silver view and a gold
dimension view, even when the SQL itself barely changes?

<details>
<summary>Show solution</summary>

```sql
PRAGMA table_info(dim_product);
```

```
0|product_id
1|product_name
2|category
3|subcategory
4|brand
5|unit_cost
6|unit_price
7|is_discontinued
8|sku
9|sku_is_duplicate
10|weight_kg
11|created_at
```

This is exactly `silver_products`'s output column list, unchanged —
`dim_product` is `SELECT <same 12 columns> FROM silver_products`, no
transformation at all (confirm by reading `project/gold/dim_product.sql`
directly).

The distinction is about *role*, not *SQL complexity*: `silver_products`
exists to answer "is this row's data clean?" — its job is cleaning.
`dim_product` exists to answer "is this the customer-facing product
dimension a report should join against?" — its job is being a stable,
documented, business-facing name in the star schema, even when (as
here) it happens to add zero additional logic. A gold dimension view
can be a thin wrapper and still be doing real work: establishing a
naming/interface contract that's allowed to diverge from silver later
without every downstream `fact_sales`/`agg_*` query needing to change.

</details>

---

### 5. Trace a full dependency chain

Draw out (as text, e.g. `a -> b -> c`) every view `agg_customer_ltv`
transitively depends on, all the way down to bronze tables. You'll
need to read `project/gold/agg_customer_ltv.sql`,
`project/gold/dim_customer.sql`, `project/gold/fact_sales.sql`, and
`project/silver/silver_customers.sql`/`silver_sales.sql`.

<details>
<summary>Show solution</summary>

```
agg_customer_ltv
  -> dim_customer -> silver_customers -> bronze_customers
  -> fact_sales    -> silver_sales    -> bronze_sales
```

`agg_customer_ltv` joins `dim_customer` (a thin wrapper over
`silver_customers`, itself a cleaning layer over `bronze_customers`)
against `fact_sales` (a thin wrapper over `silver_sales`, a cleaning +
`net_amount`-recomputation layer over `bronze_sales`). A single query
against `agg_customer_ltv` therefore re-executes: `bronze_customers`'s
scan, `silver_customers`'s full name/phone/state/date normalization,
`bronze_sales`'s scan, `silver_sales`'s full date/discount/net_amount
recomputation, then the final `LEFT JOIN` and aggregation —  every
single time it's queried. This is the "recompute cost" trade-off from
the lesson made concrete: four layers of view logic, all re-run fresh
on every query, in exchange for zero staleness.

</details>

---

### 6. Would a materialized table change the *answer*, or just the *cost*?

Suppose Oakhaven's gold layer used materialized tables instead of
views, refreshed once per day. A customer places a new order at
9:00am; the daily refresh runs at midnight. If someone queries
`agg_customer_ltv` for that customer at 10:00am the same day, what
would they see with materialized tables vs. with the current
view-based design? Which design would you pick for a project where
correctness matters more than raw query speed, and why is that the
right call for a learning-focused practice database specifically?

<details>
<summary>Show solution</summary>

With **materialized tables** refreshed once per day: the 10:00am query
would **not** reflect the 9:00am order — the customer's
`lifetime_net_amount` and `order_count` would be stale until the next
midnight refresh, up to nearly 24 hours later.

With the current **view-based** design: the 10:00am query recomputes
`agg_customer_ltv` from scratch, joining live `fact_sales` (itself a
live view over `silver_sales` over `bronze_sales`) — the 9:00am order
is included immediately, with zero staleness.

For a learning project, correctness-over-speed is the right call: the
whole point of Oakhaven is that every query result should be
explainable and trustworthy against the current state of the data,
without a learner needing to reason about "was the aggregate refreshed
since I last changed something?" At Oakhaven's ~12,000-row scale, the
recompute cost is invisible anyway — there's no real performance
trade-off to weigh here, only the conceptual one the lesson describes.
A production system serving millions of rows to a live dashboard might
reasonably make the opposite trade for query speed, accepting bounded
staleness in exchange for not recomputing a four-layer view chain on
every page load.

</details>

---

<!-- nav -->
Curriculum: [4. Views](../../curriculum/04-expert/04-views.md). Previous: [3. Transactions](03-transactions.md). Next: [5. Indexes and EXPLAIN QUERY PLAN](05-indexes-and-explain-query-plan.md).
<!-- /nav -->
