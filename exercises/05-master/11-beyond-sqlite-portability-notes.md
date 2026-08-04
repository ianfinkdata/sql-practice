# Exercises: Beyond SQLite — Portability Notes

<!-- nav -->
Curriculum: [11. Beyond SQLite: Portability Notes](../../curriculum/05-master/11-beyond-sqlite-portability-notes.md). Previous: [10. Capstone: Design a Novel Gold View](10-capstone-build-a-novel-gold-view.md). Next: [Portfolio](../../portfolio/README.md).
<!-- /nav -->

All solutions verified against `project/oakhaven.db` (or, for
syntax-only checks, an in-memory SQLite database — noted where used).

## 1. Rewrite a `strftime` date-trunc as `date()` modifiers

`dim_date` computes `year`/`month`/`month_name` using `strftime()`.
Using `date()` with modifiers instead (the pattern you'd translate
toward `DATE_TRUNC` on a production engine), write a query that returns
the start-of-month and end-of-month dates for `'2026-06-30'`.

<details>
<summary>Show solution</summary>

```sql
SELECT
    date('2026-06-30', 'start of month') AS start_of_month,
    date('2026-06-30', 'start of month', '+1 month', '-1 day') AS end_of_month;
```

| start_of_month | end_of_month |
|---|---|
| 2026-06-01 | 2026-06-30 |

On Snowflake/Postgres/Databricks this collapses to a single
`DATE_TRUNC('month', d)` call for the start-of-month value; there's no
direct equivalent modifier chain needed. This is the general pattern:
SQLite's date arithmetic tends to need more explicit modifier chaining
than a dedicated `DATE_TRUNC` function does.

</details>

## 2. Reproduce the `QUALIFY`-equivalent CTE pattern

Write a query that deduplicates `dim_customer` down to one row per
distinct `LOWER(TRIM(email))`, keeping the lowest `customer_id` in each
group, using the CTE + `ROW_NUMBER()` + outer-`WHERE rn = 1` pattern
that SQLite requires in place of `QUALIFY`. Return just the count of
deduplicated rows.

<details>
<summary>Show solution</summary>

```sql
WITH ranked AS (
    SELECT customer_id, email,
           ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) AS rn
    FROM dim_customer
)
SELECT COUNT(*) AS deduped_count
FROM ranked
WHERE rn = 1;
```

| deduped_count |
|---|
| 537 |

On Snowflake/BigQuery/Databricks, the exact same result is reachable
in a single `SELECT`:

```sql
SELECT COUNT(*) FROM (
    SELECT customer_id
    FROM dim_customer
    QUALIFY ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) = 1
);
```

(This second query does **not** run on SQLite — `QUALIFY` isn't
supported there. It's shown for comparison, not to execute against
`oakhaven.db`.)

Note this count (537) is smaller than you might expect from "600
customers minus 30 known near-duplicates = 570" — that's because rows
with a NULL or empty `email` all collapse into a single `LOWER(TRIM(email))`
= NULL partition together (SQL window functions treat NULL as one
group for partitioning purposes), which is a real limitation of this
naive dedup approach worth knowing about, not a bug in the count.

</details>

## 3. Upsert syntax: SQLite vs. a `MERGE`-shaped mental model

Using an in-memory SQLite database (`sqlite3 :memory:`, since this
doesn't touch `oakhaven.db`), create a two-column table, seed it with
2 rows, then run a single `INSERT ... ON CONFLICT ... DO UPDATE`
statement that updates row `id = 1`'s value and inserts a brand-new row
`id = 3` in the same statement.

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);
INSERT INTO t VALUES (1, 'a'), (2, 'x');
INSERT INTO t (id, v) VALUES (1, 'b'), (3, 'c')
    ON CONFLICT(id) DO UPDATE SET v = excluded.v;
SELECT * FROM t ORDER BY id;
```

| id | v |
|---|---|
| 1 | b |
| 2 | x |
| 3 | c |

Row 1 updated (`'a'` → `'b'`), row 2 untouched, row 3 newly inserted —
all from one statement. This is SQLite's row-at-a-time upsert
primitive; a production `MERGE` statement generalizes this same
match/update/insert logic to operate across an entire incoming batch
of rows at once (e.g. loading a day's worth of new/changed silver rows
into a gold dimension table), rather than one explicit row list.

</details>

## 4. Reproduce the `CREATE OR REPLACE VIEW` failure

Confirm for yourself that SQLite rejects `CREATE OR REPLACE VIEW`, and
explain why every file in `project/gold/` and `project/silver/`
instead opens with `DROP VIEW IF EXISTS ...;` followed by a separate
`CREATE VIEW ...;` statement.

<details>
<summary>Show solution</summary>

```sql
CREATE OR REPLACE VIEW ex_test AS SELECT 1;
```

```
Error: in prepare, near "OR": syntax error
```

SQLite's `CREATE VIEW` statement has no `OR REPLACE` option, so
`project/gold/*.sql` and `project/silver/*.sql` each use the two-statement
`DROP VIEW IF EXISTS` + `CREATE VIEW` pattern to achieve the same
"replace this view if it already exists" behavior. On Snowflake,
BigQuery, Databricks, or Postgres, `CREATE OR REPLACE VIEW` works as a
single statement, and the leading `DROP` becomes unnecessary (though
harmless) if you port one of these files over.

</details>

## 5. Find a different dynamic-typing example than the lesson's

Module 11's lesson used `bronze_products.weight_kg` (declared `TEXT`,
storing both `"1.2"` and `"1.2 kg"`) as its dynamic-typing example.
Find a different column in `bronze_sales` that shows the same
"declared as one type, actually holds mixed underlying values" pattern,
using `typeof()`.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT typeof(order_total) FROM bronze_sales;
```

| typeof(order_total) |
|---|
| text |
| null |

`bronze_sales.order_total` is declared `TEXT` in `project/bronze/schema.sql`,
and — matching the data dictionary's description of it as "deliberately
untrustworthy" — actually stores a mix of plain numeric-looking strings
(`"536.26"`), `$`-prefixed strings (`"$411.30"`), and literal
placeholder text (`"TBD"`, `"N/A"`), plus NULLs. All of it lives happily
in one `TEXT` column because SQLite only ever suggests a type per
column, never enforces one. On a strictly-typed engine, a column meant
to eventually hold a decimal amount would need to be declared as a
string type at the bronze layer specifically so it *can* hold `"TBD"`
without the load failing — exactly the same design implication the
lesson drew from `weight_kg`.

</details>

## 6. Reasoning: porting `fact_sales` to Snowflake

No new SQL for this one. Suppose you're porting `project/gold/fact_sales.sql`
to run on Snowflake instead of SQLite. List every change you'd need to
make to the view definition itself (not the underlying tables) based on
what this module covered, and briefly say why each one is needed.

<details>
<summary>Show solution</summary>

Looking at the actual `fact_sales.sql` definition:

1. **`DROP VIEW IF EXISTS fact_sales; CREATE VIEW fact_sales AS ...`**
   becomes a single `CREATE OR REPLACE VIEW fact_sales AS ...` —
   Snowflake supports the one-statement form directly, so the separate
   `DROP` is no longer needed (though leaving it wouldn't break
   anything if you kept both statements).
2. **`CAST(strftime('%Y%m%d', s.order_date) AS INTEGER) AS datekey`**
   needs to become Snowflake's date-formatting equivalent, e.g.
   `TO_NUMBER(TO_CHAR(s.order_date::DATE, 'YYYYMMDD'))` — `strftime()`
   doesn't exist outside SQLite.
3. Everything else in the view — the plain column selections, no
   `QUALIFY`, no `MERGE`, no surrogate key generation — needs **no
   change**. `fact_sales` is a simple `SELECT ... FROM silver_sales`
   with one date-formatting expression; the vast majority of its logic
   is standard SQL that runs unmodified on any engine. That's worth
   noticing: most of a well-written gold-layer view is portable by
   default, and only the handful of syntax areas this module covered
   need translation.

</details>

---

<!-- nav -->
Curriculum: [11. Beyond SQLite: Portability Notes](../../curriculum/05-master/11-beyond-sqlite-portability-notes.md). Previous: [10. Capstone: Design a Novel Gold View](10-capstone-build-a-novel-gold-view.md). Next: [Portfolio](../../portfolio/README.md).
<!-- /nav -->
