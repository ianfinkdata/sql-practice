# Running Totals & Moving Averages

> Add an `ORDER BY` to an aggregate window and watch it accumulate.

## The idea

In the intro, `SUM(amount) OVER (PARTITION BY region)` gave every row the *same* total — its region's grand total. Useful, but static. The number doesn't change as you move down the rows.

Now add an `ORDER BY` *inside* the `OVER`. Something quietly powerful happens: the sum stops being a single grand total and becomes a **running total** — it accumulates row by row, in the order you specified.

Think of a bank statement. Each line shows a transaction, but the column you actually care about is the **running balance** — your money *after* each transaction, building up over time. That's exactly what `SUM(amount) OVER (ORDER BY date)` produces: each row gets the sum of itself and everything that came before it.

The mental shift is this: **`PARTITION BY` alone = the same total everywhere. Adding `ORDER BY` = a total that grows as you go.** The order tells SQL what "before" means.

The same trick works with `AVG`. `AVG(amount) OVER (ORDER BY date)` gives a *running average* — the average of everything up to and including the current row. Pair it with a window frame (next module) and you get a **moving average**: the average of, say, the last 7 days only — a smoothed line that's the backbone of trend analysis.

## Why it matters

Cumulative measures are everywhere in reporting. Sales-to-date. Account balance over time. Running headcount. Progress toward a quota. Anytime someone asks "and how much *total* by that point?", they want a running total.

Moving averages matter just as much. Raw daily numbers are jumpy and noisy; a 7-day moving average smooths out the weekday/weekend wobble and reveals the real trend underneath. Analysts reach for these constantly.

## See it

A running total of sales over time — each row shows the cumulative amount through that date:

```sql
SELECT
  sale_date,
  amount,
  SUM(amount) OVER (ORDER BY sale_date) AS running_total
FROM sales;
```

Read top to bottom: each `running_total` is that day's amount plus every prior day's.

Now a **partitioned** running total — restart the accumulation for each region, so you get one independent running balance per region:

```sql
SELECT
  c.region,
  s.sale_date,
  s.amount,
  SUM(s.amount) OVER (
    PARTITION BY c.region
    ORDER BY s.sale_date
  ) AS region_running_total
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id;
```

The `PARTITION BY` resets the total to zero whenever the region changes; the `ORDER BY` makes it climb within each region.

A running average works identically — just swap the function:

```sql
SELECT
  sale_date,
  amount,
  AVG(amount) OVER (ORDER BY sale_date) AS running_avg
FROM sales;
```

> **Dialect note:** True *moving* averages (last N rows only) require a window frame clause, which behaves slightly differently across engines. We cover frames in the next module; for fine print see the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **`ORDER BY` is what creates the running behavior.** Drop it and you're back to a single grand total on every row.
- **Ties in the `ORDER BY` can surprise you.** If several rows share the same `sale_date`, the default frame lumps them together — every tied row shows the same accumulated value, jumping past all of them at once. (More on this in the frames module.)
- **A running average is not a moving average.** Plain `AVG OVER (ORDER BY ...)` averages *everything so far*. A moving average needs an explicit frame to limit it to the last N rows.
- **Sort your output too.** The `ORDER BY` inside `OVER` shapes the window, but doesn't guarantee the displayed rows come out sorted — add a final `ORDER BY` if you want them in order on the page.
- **Partition before you accumulate** when each group should have its own independent total; otherwise the total bleeds across groups.

## Practice

1. Explain, in plain English, the difference between `SUM(amount) OVER (PARTITION BY region)` and `SUM(amount) OVER (ORDER BY sale_date)`.
2. Write a query producing a running total of all sales amounts, ordered by sale date.
3. Modify it so each region accumulates its own separate running total.
4. Produce a running average of sale amounts over time, and describe how it differs from a true 7-day moving average.

---
**Prev:** [Ranking](./02-ranking.md) · **Next:** [LEAD & LAG: Period-over-Period](./04-lead-lag.md)
