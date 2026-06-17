# LEAD & LAG: Period-over-Period

> Reach into the previous or next row to compute change and growth.

## The idea

Some of the most valuable questions in analytics are about *change*: How does this month compare to last month? Did revenue go up or down? By what percent?

To answer those, a row needs to peek at its **neighbor** — the row just before it, or just after. That's precisely what `LAG` and `LEAD` do.

Picture the rows lined up in order, like a row of dominoes.

- **`LAG(column)`** looks **backward** — it fetches the value from the *previous* row. ("What was last month's revenue?")
- **`LEAD(column)`** looks **forward** — it fetches the value from the *next* row. ("What's coming up next?")

Both rely on an `ORDER BY` inside `OVER` to define what "previous" and "next" even mean. And both can reach further than one step: `LAG(amount, 3)` looks three rows back. You can also supply a default for when there's no neighbor: `LAG(amount, 1, 0)` returns 0 at the very first row instead of NULL.

Once you can pull last period's value alongside this period's, the math is easy. Subtract for the raw **change**. Divide and multiply by 100 for **growth percent**. That single move — current value next to prior value, on the same row — is the engine behind nearly every "vs. last period" report.

A close cousin: **`FIRST_VALUE`** and **`LAST_VALUE`** grab the first or last value in the whole window (the earliest or latest in the order), handy for "compare every month to the very first month" style baselines.

## Why it matters

"Up or down from last time" drives dashboards, board decks, and KPIs everywhere. Month-over-month revenue. Week-over-week signups. Year-over-year growth. Each is a period-over-period comparison, and `LAG` is the natural tool — it puts the prior period's number right beside the current one, ready to subtract.

## See it

Compare each month's sales to the previous month, and compute the change:

```sql
SELECT
  month,
  monthly_total,
  LAG(monthly_total) OVER (ORDER BY month) AS prev_month,
  monthly_total - LAG(monthly_total) OVER (ORDER BY month) AS change
FROM (
  SELECT
    DATE_TRUNC('month', sale_date) AS month,
    SUM(amount) AS monthly_total
  FROM sales
  GROUP BY DATE_TRUNC('month', sale_date)
) m;
```

Each row now carries both this month and last month, so the subtraction gives the month-over-month change.

Turn that change into a **growth percentage**:

```sql
SELECT
  month,
  monthly_total,
  ROUND(
    100.0 * (monthly_total - LAG(monthly_total) OVER (ORDER BY month))
          / LAG(monthly_total) OVER (ORDER BY month),
    1
  ) AS growth_pct
FROM monthly_sales;
```

Compare every month to the **first** month on record with `FIRST_VALUE`:

```sql
SELECT
  month,
  monthly_total,
  FIRST_VALUE(monthly_total) OVER (ORDER BY month) AS baseline
FROM monthly_sales;
```

> **Dialect note:** `DATE_TRUNC` is Postgres-style. SQL Server, MySQL, and BigQuery truncate dates differently; the date module covers this. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **The first row's `LAG` is NULL** (and the last row's `LEAD` is too). Any arithmetic against NULL yields NULL — supply a default (`LAG(x, 1, 0)`) or expect blanks at the edges.
- **Divide-by-zero on growth percent.** If the prior period was 0, the percentage blows up. Guard with `NULLIF` or a `CASE`.
- **`ORDER BY` defines "previous."** Wrong or missing order and "the previous row" is meaningless — neighbors are whatever order the engine happened to pick.
- **`LAST_VALUE` surprises people.** Because of the default window frame, `LAST_VALUE` often returns the *current* row, not the final one. It needs an explicit full frame (`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`) to behave as expected — see the frames module.
- **Partition for per-group comparisons.** Comparing each region to *its own* prior month needs `PARTITION BY region`, or last month's number leaks in from another region.

## Practice

1. In plain English, explain when you'd reach for `LAG` versus `LEAD`.
2. Write a query that shows each month's total sales alongside the previous month's total.
3. Extend it to compute month-over-month growth as a percentage, safely handling a prior month of zero.
4. Use `FIRST_VALUE` to show each month's total next to the earliest month's total, then describe what dividing them would tell you.

---
**Prev:** [Running Totals & Moving Averages](./03-running-totals.md) · **Next:** [Window Frames](./05-window-frames.md)
