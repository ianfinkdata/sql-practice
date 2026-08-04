# 7. Designing the Fact Table

<!-- nav -->
Previous: [6. Designing the Date Dimension](06-designing-the-date-dimension.md). Next: [8. Star vs. Snowflake Schema](08-star-vs-snowflake-schema.md). Exercises: [7. Designing the Fact Table](../../exercises/05-master/07-designing-the-fact-table.md).
<!-- /nav -->

## The idea

A fact table records that *something happened*, at a stated grain, and
holds two kinds of columns: **foreign keys** that connect each event to
the dimensions that describe it (who, what, when, where), and
**measures** — the numbers you actually want to aggregate. Everything
else the previous modules covered (dimension design, grain, SCD, the
date dimension) exists in service of this one table. It's the thing a
BI tool queries.

Designing a fact table is really three decisions, made in order:

1. **Grain** — what does one row mean? ("One row per order line" is
   Oakhaven's answer — you can't change your mind about this later
   without rebuilding the table.)
2. **Foreign keys** — which dimensions does each row connect to, and
   what happens when a key doesn't resolve?
3. **Measures** — which numeric columns get summed/averaged, and does
   that aggregation even make sense?

This module dissects `project/gold/fact_sales.sql` as the concrete
answer Oakhaven gives to all three.

## Grain: the contract everything else depends on

```sql
SELECT COUNT(*) AS rows, COUNT(DISTINCT order_id || '-' || order_line_id) AS distinct_grain
FROM fact_sales;
```

| rows | distinct_grain |
|---|---|
| 12000 | 12000 |

Every row count matches its distinct-grain-key count: `fact_sales` has
exactly one row per `(order_id, order_line_id)` pair, no more, no
fewer. That's the grain statement made verifiable — "one row per order
line" isn't a comment, it's a property you can check with `COUNT(*) =
COUNT(DISTINCT grain_key)`. If those two numbers ever diverged, the
fact table would be silently double-counting or dropping order lines,
and every downstream `SUM()` would be wrong. Always run this check
before trusting a fact table (yours or someone else's).

## Foreign keys: connect, don't validate

Here's the full view:

```sql
CREATE VIEW fact_sales AS
SELECT
    s.order_id,
    s.order_line_id,
    s.customer_id,
    s.product_id,
    s.employee_id,
    CAST(strftime('%Y%m%d', s.order_date) AS INTEGER) AS datekey,
    s.order_date,
    s.ship_date,
    s.quantity,
    s.unit_price,
    s.discount_pct,
    s.net_amount,
    s.payment_method,
    s.order_status,
    s.channel,
    s.is_customer_orphan,
    s.is_product_orphan
FROM silver_sales s;
```

Four foreign keys, one per dimension: `customer_id` → `dim_customer`,
`product_id` → `dim_product`, `employee_id` → `dim_employee`, `datekey`
→ `dim_date`. Notice what's *not* here: no `JOIN` to any of those
dimensions, and no `WHERE` clause filtering out rows whose keys don't
resolve. `fact_sales` is built straight off `silver_sales` — it carries
the keys, it does not validate them.

That's deliberate, and it's the same discipline Tier 4's constraints
lesson taught for bronze: don't silently drop bad data, surface it so
someone downstream can decide what to do with it. Four things are
passed through instead of fixed or filtered:

- **`is_customer_orphan`** — `1` when `customer_id` doesn't exist in
  `bronze_customers`. Computed in `silver_sales`, carried through
  unchanged.
- **`is_product_orphan`** — same idea for `product_id`.
- **NULL `employee_id`** — not an error. It means an online/no-rep
  sale (see the data dictionary: ~10% of bronze rows have this by
  design).
- **NULL `datekey`** — happens when `order_date` couldn't be parsed
  (missing in bronze), so there's nothing to `strftime()` into a key.

```sql
SELECT
    SUM(is_customer_orphan) AS customer_orphans,
    SUM(is_product_orphan) AS product_orphans,
    SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END) AS null_employee_id,
    SUM(CASE WHEN datekey IS NULL THEN 1 ELSE 0 END) AS null_datekey
FROM fact_sales;
```

| customer_orphans | product_orphans | null_employee_id | null_datekey |
|---|---|---|---|
| 103 | 122 | 1243 | 58 |

12,103 rows (about 10%) have at least one of these conditions, and
every one of them still made it into `fact_sales`. If the view had
inner-joined to the dimensions instead, all 12,103 would have vanished
without a trace — and nobody querying `fact_sales` would ever know
data was missing. Instead, an analyst can write `WHERE
is_customer_orphan = 0` to exclude bad rows *when they choose to*, or
`WHERE is_customer_orphan = 1` to go investigate them. That choice
belongs to the query, not the pipeline. (`agg_customer_ltv` and
`agg_monthly_sales_by_category`, covered in later modules, make their
own different choices about how to handle this — LEFT JOIN vs. INNER
JOIN — which is exactly the point: the fact table stays neutral, and
each downstream aggregate decides for itself.)

## Measures: additive, semi-additive, non-additive

Not every number in a fact table can be summed the same way. Getting
this wrong is one of the most common real-world dimensional-modeling
mistakes, so it's worth naming the three categories explicitly.

**Additive measures** can be summed across *any* dimension — customer,
product, date, all of them — and the sum still means something.
`quantity` and `net_amount` are Oakhaven's additive measures: "total
units sold" and "total revenue" are meaningful whether you're summing
across one customer, one day, or the whole table. This is the easy,
default case, and most measures in most fact tables are additive.

**Semi-additive measures** can be summed across *some* dimensions but
not others — typically not across time. Oakhaven's `fact_sales`
doesn't literally carry one (order-line revenue is fully additive), but
the pattern shows up the moment you compute a running/cumulative total,
which behaves like a balance snapshot:

```sql
SELECT order_date, total_net_amount,
       ROUND(SUM(total_net_amount) OVER (ORDER BY order_date), 2) AS running_total_net_amount
FROM agg_daily_sales
ORDER BY order_date
LIMIT 8;
```

| order_date | total_net_amount | running_total_net_amount |
|---|---|---|
| 2021-01-01 | 2318.71 | 2318.71 |
| 2021-01-02 | 3381.01 | 5699.72 |
| 2021-01-03 | 1914.65 | 7614.37 |
| 2021-01-04 | 3594.94 | 11209.31 |
| 2021-01-05 | 3059.74 | 14269.05 |
| 2021-01-06 | 7591.42 | 21860.47 |
| 2021-01-07 | 8585.33 | 30445.8 |
| 2021-01-08 | 0.0 | 30445.8 |

`running_total_net_amount` is valid to *read* at any single row — on
2021-01-07, cumulative revenue to date was $30,445.80. But it is
**not** valid to `SUM()` across rows: adding the running totals for
2021-01-06 and 2021-01-07 together (21860.47 + 30445.80) produces a
meaningless number that double-counts everything before 01-06. This is
exactly how a real semi-additive measure behaves — an account balance,
an inventory-on-hand snapshot, a headcount at end-of-month: correct to
sum across products/stores/departments *at a point in time*, wrong to
sum across time itself.

**Non-additive measures** can't be meaningfully summed across *any*
dimension — usually because they're ratios or averages, not counts of
things. `discount_pct` is Oakhaven's non-additive measure:

```sql
SELECT
    ROUND(SUM(discount_pct), 2) AS meaningless_sum,
    ROUND(AVG(discount_pct), 4) AS naive_avg_discount,
    ROUND(1 - SUM(net_amount) * 1.0 / SUM(quantity * unit_price), 4) AS true_weighted_avg_discount
FROM fact_sales
WHERE quantity > 0 AND net_amount IS NOT NULL;
```

| meaningless_sum | naive_avg_discount | true_weighted_avg_discount |
|---|---|---|
| 1284.8 | 0.1144 | 0.1151 |

`SUM(discount_pct)` (1284.8) is nonsense — "the sum of a bunch of
percentages" isn't a business quantity anyone asked for. Even the naive
`AVG(discount_pct)` (0.1144, an unweighted average of every line's
discount rate) is subtly wrong: it treats a $5 line and a $5,000 line
as equally important. The correct answer, `true_weighted_avg_discount`
(0.1151), is recomputed from the two *additive* components that make
it up — `SUM(net_amount)` and `SUM(quantity * unit_price)` — and only
divided at the very end. The lesson generalizes: when a measure isn't
additive, don't aggregate it directly; decompose it into additive
pieces, aggregate those, and recombine.

## Examples

### 1. Confirm the grain holds with no duplicates or gaps

```sql
SELECT order_id, order_line_id, COUNT(*)
FROM fact_sales
GROUP BY order_id, order_line_id
HAVING COUNT(*) > 1;
```

Zero rows returned — no `(order_id, order_line_id)` pair repeats. This
is the same grain check as above, phrased as a "prove me wrong" query
instead of a count comparison; either style is a good habit to keep in
your back pocket for any fact table you build.

### 2. See the orphan flags in action

```sql
SELECT order_id, order_line_id, customer_id, is_customer_orphan
FROM fact_sales
WHERE is_customer_orphan = 1
LIMIT 5;
```

| order_id | order_line_id | customer_id | is_customer_orphan |
|---|---|---|---|
| 97 | 1 | 9318 | 1 |
| 97 | 2 | 9318 | 1 |
| 190 | 1 | 4124 | 1 |
| 190 | 2 | 4124 | 1 |
| 190 | 3 | 4124 | 1 |

Orphan `customer_id`s like `9318` and `4124` are well outside the real
1–600 range, which makes them easy to eyeball as fake. Every line of
order 97 shares the same bad `customer_id`, and so does every line of
order 190 — a reminder that `bronze_sales` generates order-level
attributes once per order and repeats them, so a corrupt `customer_id`
corrupts the whole order, not just one line.

### 3. Additive measures roll up correctly at any grain

```sql
SELECT channel, COUNT(*) AS lines, SUM(quantity) AS total_units, ROUND(SUM(net_amount), 2) AS total_net_amount
FROM fact_sales
GROUP BY channel
ORDER BY total_net_amount DESC;
```

| channel | lines | total_units | total_net_amount |
|---|---|---|---|
| In-Store | 5960 | 16440 | 4380739.06 |
| Online | 6040 | 16509 | 4361549.98 |

`quantity` and `net_amount` sum cleanly no matter how you group them —
by channel here, by category or by day elsewhere in this repo. That
reliability is *why* they're the measures, not an accident.

## Common mistakes

- **Filtering orphans/NULLs out of the fact table itself.** That
  decision belongs to each downstream query or aggregate, not to the
  fact table. Baking a `WHERE is_customer_orphan = 0` into
  `fact_sales` would silently delete evidence that ~1% of orders
  reference nonexistent customers — evidence someone needs to see to
  fix the upstream system.
- **Picking a grain, then quietly violating it.** If `fact_sales` ever
  gained a second row per order line (say, one row per line per
  discount-code-applied), `COUNT(*) = COUNT(DISTINCT grain_key)` would
  break, and every `SUM()` written against the old assumption would
  silently overcount. Re-check the grain invariant after any schema
  change.
- **Summing a non-additive measure because it's numeric.** `discount_pct`,
  `unit_price`, any percentage, ratio, or rate — SQL will happily
  compute `SUM()` on these, and the result will be wrong every time.
  If a measure is a ratio, decompose it into its additive numerator and
  denominator instead.
- **Summing a semi-additive measure across the "wrong" dimension** —
  usually time. Running totals, balances, and point-in-time snapshots
  are real, useful measures; they just can't be added to each other
  across the dimension they're already cumulative over.

## Key takeaways

- Fact table design is grain, then foreign keys, then measures — in
  that order, because the grain decision constrains everything after
  it.
- `COUNT(*) = COUNT(DISTINCT grain_key)` is a cheap, mechanical way to
  verify a stated grain actually holds.
- Foreign keys in a fact table connect to dimensions; they don't
  validate against them. `fact_sales` passes through
  `is_customer_orphan`, `is_product_orphan`, NULL `employee_id`, and
  NULL `datekey` by design, so bad data is visible and query-able
  instead of silently vanishing — the same "surface, don't hide"
  discipline as Tier 4's constraints lesson, just applied at the gold
  layer instead of the DDL layer.
- Measures split into three kinds: additive (`quantity`, `net_amount` —
  sum across anything), semi-additive (running totals/balances — sum
  across some dimensions, not time), and non-additive (`discount_pct` —
  never sum directly; decompose into additive parts and recombine).
- This grain → keys → measures thinking is the same recipe whether
  you're modeling retail order lines, hospital claims, or ad
  impressions — it's portable well beyond Oakhaven.

---

<!-- nav -->
Previous: [6. Designing the Date Dimension](06-designing-the-date-dimension.md). Next: [8. Star vs. Snowflake Schema](08-star-vs-snowflake-schema.md). Exercises: [7. Designing the Fact Table](../../exercises/05-master/07-designing-the-fact-table.md).
<!-- /nav -->
