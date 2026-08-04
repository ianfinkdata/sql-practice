# 3. Window Functions II — Running Totals & Moving Aggregates


<!-- nav -->
Previous: [2. Window Functions I — ROW_NUMBER, RANK, DENSE_RANK](02-window-functions-i-row-number-rank.md). Next: [4. LEAD, LAG, and Period-over-Period Comparisons](04-lead-lag-period-over-period.md).
<!-- /nav -->

## The idea

The previous lesson used window functions to rank rows. This lesson uses
the exact same `OVER (...)` mechanism for a different job: accumulating a
value as you move down a sorted list — a **running total** — or averaging
over a sliding slice of nearby rows — a **moving average**.

The key new idea is the **frame**: the specific slice of rows, relative to
the current row, that a window function considers. So far we've used the
default frame implicitly. This lesson makes it explicit.

## Syntax

```sql
SUM(value_column) OVER (
    [PARTITION BY grouping_column]
    ORDER BY sort_column
    [ROWS BETWEEN frame_start AND frame_end]
)
```

When you add `ORDER BY` inside `OVER (...)` to an aggregate function like
`SUM()`, `AVG()`, `MAX()`, or `MIN()`, its **default frame** becomes "from
the start of the partition through the current row" — which is exactly
what a running total needs, with no extra syntax required.

To compute something over a fixed-size sliding window instead (a moving
average, say), specify the frame explicitly:

```sql
ROWS BETWEEN 6 PRECEDING AND CURRENT ROW   -- current row + 6 before it = 7-row window
```

## Example 1: a running total of daily sales

`agg_daily_sales` is Oakhaven's date-spine view — one row per calendar
day, including zero-order days (that pattern is dissected fully in a later
module). Running `SUM(total_net_amount)` ordered by date gives a
cumulative total:

```sql
SELECT order_date, total_net_amount,
       ROUND(SUM(total_net_amount) OVER (ORDER BY order_date), 2) AS running_total
FROM agg_daily_sales
WHERE order_date BETWEEN '2021-01-01' AND '2021-01-10'
ORDER BY order_date;
```

Verified output:

| order_date | total_net_amount | running_total |
|---|---|---|
| 2021-01-01 | 2318.71 | 2318.71 |
| 2021-01-02 | 3381.01 | 5699.72 |
| 2021-01-03 | 1914.65 | 7614.37 |
| 2021-01-04 | 3594.94 | 11209.31 |
| 2021-01-05 | 3059.74 | 14269.05 |
| 2021-01-06 | 7591.42 | 21860.47 |
| 2021-01-07 | 8585.33 | 30445.80 |
| 2021-01-08 | 0.0 | 30445.80 |
| 2021-01-09 | 4533.02 | 34978.82 |
| 2021-01-10 | 6908.29 | 41887.11 |

Notice 2021-01-08: `total_net_amount` is 0.0 (a zero-order day), and the
running total simply doesn't move that day — exactly the behavior you'd
want, and a preview of why the date-spine pattern (a later module) matters
for this kind of query to be *complete* in the first place.

## Example 2: a 7-day moving average

Sales are noisy day to day. A trailing moving average smooths that out.
This needs an explicit frame — `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`
means "the current row plus the 6 before it," i.e. a 7-day window:

```sql
SELECT order_date, total_net_amount,
       ROUND(AVG(total_net_amount) OVER (
           ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_7d
FROM agg_daily_sales
WHERE order_date BETWEEN '2021-01-01' AND '2021-01-14'
ORDER BY order_date;
```

Verified output (first few rows):

| order_date | total_net_amount | moving_avg_7d |
|---|---|---|
| 2021-01-01 | 2318.71 | 2318.71 |
| 2021-01-02 | 3381.01 | 2849.86 |
| 2021-01-03 | 1914.65 | 2538.12 |
| 2021-01-04 | 3594.94 | 2802.33 |
| 2021-01-05 | 3059.74 | 2853.81 |
| 2021-01-06 | 7591.42 | 3643.41 |
| 2021-01-07 | 8585.33 | 4349.40 |
| 2021-01-08 | 0.0 | 4018.16 |

Early rows (before 7 days of history exist) average over however many rows
*are* available — SQLite doesn't require a full 7-row frame; it uses
whatever's there. That's usually what you want, but it's worth knowing so
a thin early average doesn't surprise you.

## Example 3: running totals partitioned by category

Add `PARTITION BY` and the running total resets per group — same
mechanism as Module 2's ranking, applied to `SUM()`:

```sql
SELECT category, year, month, total_net_amount,
       ROUND(SUM(total_net_amount) OVER (PARTITION BY category ORDER BY year, month), 2)
           AS category_running_total
FROM agg_monthly_sales_by_category
WHERE category = 'Climbing' AND year = 2021
ORDER BY month
LIMIT 6;
```

Verified output:

| category | year | month | total_net_amount | category_running_total |
|---|---|---|---|---|
| Climbing | 2021 | 1 | 17972.83 | 17972.83 |
| Climbing | 2021 | 2 | 33663.09 | 51635.92 |
| Climbing | 2021 | 3 | 28847.21 | 80483.13 |
| Climbing | 2021 | 4 | 14295.57 | 94778.70 |
| Climbing | 2021 | 5 | 22400.84 | 117179.54 |
| Climbing | 2021 | 6 | 22866.67 | 140046.21 |

Each `category`'s running total is independent — this is `agg_monthly_sales_by_category`
grouped by `category, year, month` in the gold layer, then window-summed
per category here.

## Common mistakes

- **Assuming `SUM(x) OVER (ORDER BY y)` (no explicit frame) behaves like
  `SUM(x) OVER ()` (no `ORDER BY` at all).** Adding `ORDER BY` silently
  changes the default frame from "the whole partition" to "start of
  partition through current row." This is the single most common window
  function surprise — always ask "does this have an `ORDER BY`, and if so,
  what frame does that imply?"
- **Forgetting `PARTITION BY` and getting one giant running total** across
  categories/customers/whatever should have been independent groups.
- **Off-by-one frame errors.** `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`
  is a 7-row window (6 + the current row), not 6. `ROWS BETWEEN 7
  PRECEDING AND 1 PRECEDING` would be a genuinely-preceding 7-day window
  that excludes today — useful when you don't want "today" polluting an
  average meant to represent "typical."
- **Applying a moving average to a date range with gaps** and not
  realizing the "7 rows" aren't necessarily "7 calendar days" unless the
  underlying rows already form a complete date spine (as `agg_daily_sales`
  does, but a raw `GROUP BY order_date` over `fact_sales` would not).

## Key takeaways

- Adding `ORDER BY` inside `OVER (...)` to an aggregate changes its
  default frame to "start of partition through current row" — that's what
  makes a running total work with no extra syntax.
- `ROWS BETWEEN n PRECEDING AND CURRENT ROW` defines a fixed-size trailing
  window of `n + 1` rows, for moving averages/sums.
- `PARTITION BY` resets the running total/moving aggregate per group,
  exactly as it resets ranks in `ROW_NUMBER()`/`RANK()`.
- Running totals and moving averages are only meaningful over a *complete*
  ordered sequence — gaps in the underlying data (missing dates, missing
  months) will silently distort them unless you're working from a
  gap-free spine.

---

<!-- nav -->
Previous: [2. Window Functions I — ROW_NUMBER, RANK, DENSE_RANK](02-window-functions-i-row-number-rank.md). Next: [4. LEAD, LAG, and Period-over-Period Comparisons](04-lead-lag-period-over-period.md).
<!-- /nav -->
