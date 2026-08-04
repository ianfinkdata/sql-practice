# 4. LEAD, LAG, and Period-over-Period Comparisons

<!-- nav -->
Previous: [3. Window Functions II — Running Totals & Moving Aggregates](03-window-functions-ii-running-totals.md). Next: [5. Recursive CTEs](05-recursive-ctes.md). Exercises: [4. LEAD, LAG, and Period-over-Period Comparisons](../../exercises/03-advanced/04-lead-lag-period-over-period.md).
<!-- /nav -->

## The idea

`LAG()` and `LEAD()` are window functions that let a row see the value of
a *different* row — one before it (`LAG`) or after it (`LEAD`) in the same
ordering — without a self-join. This is exactly the tool for "compare this
month to last month," "how many days since this customer's previous
order," or "what happened right after this event."

Before window functions existed, this required joining a table to a
shifted copy of itself. `LAG`/`LEAD` do it in one line.

## Syntax

```sql
LAG(column [, offset [, default]]) OVER (
    [PARTITION BY grouping_column]
    ORDER BY sort_column
)

LEAD(column [, offset [, default]]) OVER (
    [PARTITION BY grouping_column]
    ORDER BY sort_column
)
```

- `offset` (optional, default `1`): how many rows back (`LAG`) or forward
  (`LEAD`) to look.
- `default` (optional): what to return when there's no such row (e.g. the
  very first row has no prior row to `LAG()` to) — otherwise it's `NULL`.
- `ORDER BY` here is **required and load-bearing** — it defines what
  "previous" and "next" even mean. There's no concept of row order in a
  table otherwise.

## Example 1: month-over-month sales change

*Question: how did total net sales change from one month to the next?*
Roll sales up to one row per month, then use `LAG()` to pull the prior
month's total onto the same row as the current month, so the comparison is
a plain subtraction:

```sql
WITH monthly AS (
    SELECT year, month, ROUND(SUM(total_net_amount), 2) AS month_total
    FROM agg_monthly_sales_by_category
    GROUP BY year, month
)
SELECT year, month, month_total,
       LAG(month_total) OVER (ORDER BY year, month) AS prev_month_total,
       ROUND(month_total - LAG(month_total) OVER (ORDER BY year, month), 2) AS mom_change,
       ROUND(100.0 * (month_total - LAG(month_total) OVER (ORDER BY year, month))
             / LAG(month_total) OVER (ORDER BY year, month), 1) AS mom_pct_change
FROM monthly
ORDER BY year, month
LIMIT 8;
```

Verified output:

| year | month | month_total | prev_month_total | mom_change | mom_pct_change |
|---|---|---|---|---|---|
| 2021 | 1 | 140643.78 | *(null)* | *(null)* | *(null)* |
| 2021 | 2 | 128982.68 | 140643.78 | -11661.10 | -8.3 |
| 2021 | 3 | 166081.54 | 128982.68 | 37098.86 | 28.8 |
| 2021 | 4 | 115860.15 | 166081.54 | -50221.39 | -30.2 |
| 2021 | 5 | 124873.83 | 115860.15 | 9013.68 | 7.8 |
| 2021 | 6 | 134540.90 | 124873.83 | 9667.07 | 7.7 |
| 2021 | 7 | 146567.78 | 134540.90 | 12026.88 | 8.9 |
| 2021 | 8 | 136303.96 | 146567.78 | -10263.82 | -7.0 |

The very first row is `NULL` for every `LAG`-derived column — there's no
month before 2021-01 in the data, so `LAG()` correctly has nothing to
return. This is expected, not a bug; decide deliberately (with a `default`
argument, or a `WHERE ... IS NOT NULL` filter downstream) how you want that
edge handled rather than being surprised by it.

## Example 2: days since a customer's previous order

`LEAD`/`LAG` work per-partition just like every other window function.
Partitioning by `customer_id` computes each customer's *own* gap between
consecutive orders, independent of every other customer:

```sql
WITH cust_orders AS (
    SELECT DISTINCT customer_id, order_date
    FROM fact_sales
    WHERE customer_id = 343 AND order_date IS NOT NULL
),
gaps AS (
    SELECT customer_id, order_date,
           LAG(order_date) OVER (ORDER BY order_date) AS prev_date
    FROM cust_orders
)
SELECT order_date, prev_date,
       CAST(julianday(order_date) - julianday(prev_date) AS INTEGER) AS days_since_prev
FROM gaps
ORDER BY order_date
LIMIT 6;
```

Verified output (customer 343, Jennifer Howard — the #2 lifetime-value
customer):

| order_date | prev_date | days_since_prev |
|---|---|---|
| 2021-07-04 | *(null)* | *(null)* |
| 2021-08-12 | 2021-07-04 | 39 |
| 2021-08-19 | 2021-08-12 | 7 |
| 2021-10-21 | 2021-08-19 | 63 |
| 2021-12-01 | 2021-10-21 | 41 |
| 2022-03-06 | 2021-12-01 | 95 |

(`julianday()` is covered properly in the time-intelligence module — here
it's just being used to turn two ISO dates into a day count.)

## Example 3: LEAD as the mirror image of LAG

`LEAD()` is identical to `LAG()` except it looks *forward*. Same monthly
data, but each row now sees *next* month's total instead of the previous
one:

```sql
WITH monthly AS (
    SELECT year, month, ROUND(SUM(total_net_amount), 2) AS month_total
    FROM agg_monthly_sales_by_category GROUP BY year, month
)
SELECT year, month, month_total,
       LEAD(month_total) OVER (ORDER BY year, month) AS next_month_total
FROM monthly ORDER BY year, month LIMIT 5;
```

Verified output:

| year | month | month_total | next_month_total |
|---|---|---|---|
| 2021 | 1 | 140643.78 | 128982.68 |
| 2021 | 2 | 128982.68 | 166081.54 |
| 2021 | 3 | 166081.54 | 115860.15 |
| 2021 | 4 | 115860.15 | 124873.83 |
| 2021 | 5 | 124873.83 | 134540.90 |

Notice each row's `next_month_total` is literally next row's
`month_total` shifted up by one — and it's also exactly what `LAG()` would
put in `prev_month_total` one row later. `LAG` and `LEAD` are two views of
the same relationship; pick whichever reads more naturally for the
question you're asking.

## Common mistakes

- **Omitting `ORDER BY` inside `OVER (...)`.** Without it, "previous row"
  and "next row" are undefined — SQLite won't error, but the result will
  be meaningless because there's no guaranteed row order to shift across.
- **Forgetting to handle the edge `NULL`.** The first row of any partition
  has no `LAG()` value; the last has no `LEAD()` value. If a downstream
  calculation divides by a `LAG()` result (like a percent-change formula),
  that first row will produce `NULL`, not an error — which is usually
  fine, but confirm it's what you want before dropping those rows.
- **Confusing `LAG`/`LEAD` with `ROWS BETWEEN` framing from the previous
  module.** `LAG`/`LEAD` return a *single specific row's* value; framed
  aggregates like a moving average summarize a *range* of rows. They solve
  different problems even though both are window functions.
- **Not partitioning when a comparison should be per-group.** Without
  `PARTITION BY customer_id`, `LAG(order_date)` would pull the previous
  order date from *any* customer's row, not this customer's — a silent
  and easy-to-miss bug.

## Key takeaways

- `LAG()` looks backward, `LEAD()` looks forward, both within an
  `ORDER BY`-defined sequence — no self-join required.
- `ORDER BY` inside `OVER (...)` is mandatory here; it defines what
  "previous"/"next" mean.
- `PARTITION BY` scopes the look-back/look-forward per group (e.g. per
  customer), exactly as in every other window function so far.
- The first row of a partition has no `LAG()` value and the last has no
  `LEAD()` value — both are `NULL` by default unless you supply a
  `default` argument.

---

<!-- nav -->
Previous: [3. Window Functions II — Running Totals & Moving Aggregates](03-window-functions-ii-running-totals.md). Next: [5. Recursive CTEs](05-recursive-ctes.md). Exercises: [4. LEAD, LAG, and Period-over-Period Comparisons](../../exercises/03-advanced/04-lead-lag-period-over-period.md).
<!-- /nav -->
