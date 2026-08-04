# 8. Writing Your First Gold View


<!-- nav -->
Previous: [7. Constraints and Data Integrity](07-constraints-and-data-integrity.md). Next: [9. Portable, Idempotent DDL Patterns](09-portable-idempotent-ddl-patterns.md).
<!-- /nav -->

## The idea

This is the medallion architecture's payoff module. Across this
course you've moved through three layers, each read-only for you but
each doing a distinct job:

- **Bronze** — raw, messy, as-ingested (`bronze_sales`,
  `bronze_customers`, ...). No cleaning, no constraints (Module 7).
- **Silver** — cleaned, standardized, one row per source row
  (`silver_sales`, `silver_customers`, ...). Fixes formats, normalizes
  casing, recomputes trustworthy values — but doesn't aggregate or
  reshape for a specific business question.
- **Gold** — business-ready, consumption-ready. This is what a
  dashboard, a report, or a business stakeholder actually queries.
  Gold is where dimensional modeling (`dim_customer`, `dim_product`,
  `dim_employee`, `dim_date`), fact tables (`fact_sales`), and
  pre-aggregated rollups (`agg_monthly_sales_by_category`,
  `agg_customer_ltv`, `agg_daily_sales`) all live.

What makes a view *gold* isn't a technical property — it's a business
one. A gold view answers a question a real stakeholder would actually
ask ("how are sales trending by category, month over month?"), usually
pre-joined across dimensions and pre-aggregated to the grain that
question needs, so the consumer doesn't have to know the underlying
silver/bronze plumbing at all.

## Dissecting `agg_monthly_sales_by_category.sql`

The real file, in full, from `project/gold/agg_monthly_sales_by_category.sql`:

```sql
-- agg_monthly_sales_by_category: monthly rollup of net sales by product
-- category. Inner-joins to dim_date/dim_product, so order lines with a
-- NULL order_date or an orphan product_id are (by design) excluded --
-- they can't be placed on a calendar or into a category. No
-- order_status filter is applied here; that's left as a lesson exercise.

DROP VIEW IF EXISTS agg_monthly_sales_by_category;
CREATE VIEW agg_monthly_sales_by_category AS
SELECT
    d.year,
    d.month,
    d.month_name,
    p.category,
    COUNT(*) AS order_line_count,
    SUM(f.quantity) AS total_quantity,
    ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_date d ON d.datekey = f.datekey
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY d.year, d.month, d.month_name, p.category
ORDER BY d.year, d.month, p.category;
```

Walking through what makes this *gold*, not just "another view":

- **It sits on top of `fact_sales`, a gold-layer view, not directly on
  `silver_sales` or `bronze_sales`.** Gold views build on gold facts
  and dimensions — that's the whole point of having them. This keeps
  the aggregation logic separate from the cleaning logic in Module 4's
  view chain.
- **`JOIN dim_date` and `JOIN dim_product`, both **inner** joins, not
  `LEFT JOIN`.** This is a deliberate, documented business decision
  (see the comment): an order line with a `NULL` `order_date` (and
  therefore `NULL` `datekey`) can't be placed on a calendar month, and
  one with an orphan `product_id` can't be placed in a category — both
  get silently dropped from this particular rollup. That's a real
  trade-off a gold view author has to make explicitly and document,
  not something to leave implicit. (Contrast with `agg_daily_sales.sql`,
  which deliberately uses a `LEFT JOIN` from `dim_date` so zero-order
  days still appear as rows — a different business need, a different
  join direction.)
- **The grain is exactly what a stakeholder would ask for**: one row
  per (year, month, category) — not per order line. `COUNT(*)`,
  `SUM(quantity)`, and `ROUND(SUM(net_amount), 2)` collapse potentially
  hundreds of order lines into one summary row per month/category
  combination.
- **`ROUND(..., 2)`** — gold output is meant to be *read*, often
  directly by a report or dashboard, so money values are rounded to
  cents rather than left as raw floating point.
- **`ORDER BY d.year, d.month, p.category`** — baked into the view
  itself, so anyone querying it gets a naturally chronological,
  grouped result without having to remember to add their own
  `ORDER BY`.
- **`DROP VIEW IF EXISTS` before `CREATE VIEW`** — the idempotent
  pattern from Module 9, so `project/build.py` can rerun this file
  every time without erroring on "view already exists."

Real, verified output:

```sql
SELECT * FROM agg_monthly_sales_by_category LIMIT 5;
```

```
year  month  month_name  category          order_line_count  total_quantity  total_net_amount
----  -----  ----------  ----------------  ----------------  --------------  ----------------
2021  1      January     Accessories       13                42              9801.58
2021  1      January     Apparel           27                89              26856.39
2021  1      January     Camping & Hiking  20                47              14354.88
2021  1      January     Climbing          26                70              17972.83
2021  1      January     Footwear          22                65              12737.88
```

```sql
SELECT COUNT(*) FROM agg_monthly_sales_by_category;
```

```
528
```

528 rows — matches the facts sheet exactly: roughly 66 months
(2021-01 through 2026-06) × up to 8 categories per month.

## Your turn: design a new gold-style aggregate

The gold layer only has three `agg_*` views right now:
`agg_monthly_sales_by_category`, `agg_customer_ltv`, and
`agg_daily_sales`. There are plenty of real business questions those
three don't answer.

**Your task:** write a `SELECT` (not a `CREATE VIEW` — you're
verifying the logic against the read-only shared database, not
persisting anything) that answers a business question none of the
existing gold views cover. Some starting ideas:

- Net sales and order-line count by **payment method** and **year**.
- Net sales by **employee region** (via `dim_employee`), for
  in-person/rep-assisted sales only.
- A **quarterly** (not monthly) version of the category rollup, using
  `dim_date.quarter`.
- Top-N **brands** (via `dim_product.brand`) by lifetime net sales.

Worked example — net sales and order count by payment method and
year:

```sql
SELECT d.year, f.payment_method,
       COUNT(*) AS order_line_count,
       ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_date d ON d.datekey = f.datekey
GROUP BY d.year, f.payment_method
ORDER BY d.year, total_net_amount DESC;
```

Real output (first two years):

```
year  payment_method  order_line_count  total_net_amount
----  --------------  ----------------  ----------------
2021  Credit Card     651               500382.11
2021  PayPal          470               349670.57
2021  Debit Card      448               332872.24
2021  Cash            425               313837.87
2021  Gift Card       193               122247.03
2022  Credit Card     669               515112.09
2022  PayPal          461               360400.38
2022  Cash            431               320068.96
2022  Debit Card      435               311279.96
2022  Gift Card       277               197117.96
```

Notice this one deliberately used only `JOIN dim_date` (no
`dim_product`), since payment method doesn't depend on which product
was sold — matching the join list to exactly what the question needs
is itself part of good gold-view design.

Before you consider your own version done, ask the same questions
`agg_monthly_sales_by_category`'s author had to answer:

- What's the grain — one row per what?
- Inner join or left join, and what does that choice silently exclude
  or include? (Orphan products? NULL order dates? Zero-activity
  periods?)
- Are money values rounded for a human reader?
- Does the `ORDER BY` make the result immediately usable without
  further sorting?

## Common mistakes

- **Building gold directly on bronze**, skipping silver's cleaning
  entirely. `agg_monthly_sales_by_category` never touches
  `bronze_sales` directly — it goes through `fact_sales` →
  `silver_sales`, inheriting all of silver's normalization for free.
- **Choosing `LEFT JOIN` vs. `INNER JOIN` without thinking about it.**
  This single choice determines whether orphans/NULLs/zero-activity
  rows are silently dropped or explicitly preserved — get it wrong and
  a stakeholder's "total sales" number quietly excludes real data (or
  includes rows that shouldn't count).
- **Leaving raw floating-point values unrounded** in a view meant for
  direct human/report consumption.
- **Forgetting the grain changes what aggregate functions mean.** If
  you `GROUP BY` at the wrong level, `COUNT(*)` counts the wrong
  thing — always state the intended grain before writing the query.

## Key takeaways

- Gold views are distinguished by *business readiness*, not any SQL
  feature — pre-joined, pre-aggregated, rounded, ordered, and built to
  answer a specific stakeholder question at a clear grain.
- `agg_monthly_sales_by_category` builds on `fact_sales`/`dim_date`/
  `dim_product` (never raw bronze), uses deliberate inner joins with a
  documented trade-off, rounds money to cents, and orders its own
  output.
- The join direction (`INNER` vs `LEFT`) is a business decision with
  real consequences for which rows silently disappear — make it
  consciously, and document it like the real gold views do.
- Practice by writing (and verifying with real output) a `SELECT` for
  a new gold-style aggregate not already in `project/gold/` — without
  creating an actual view against the shared database.

---

<!-- nav -->
Previous: [7. Constraints and Data Integrity](07-constraints-and-data-integrity.md). Next: [9. Portable, Idempotent DDL Patterns](09-portable-idempotent-ddl-patterns.md).
<!-- /nav -->
