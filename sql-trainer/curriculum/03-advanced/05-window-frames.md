# Window Frames

> Define exactly which neighboring rows a window function sees.

## The idea

So far we've leaned on a hidden setting. When you write `SUM(amount) OVER (ORDER BY date)`, SQL silently decides *which* rows go into that sum. That set of rows — "everything from the start up to the current row" — is the **window frame**. You've been using the default frame without naming it.

A frame is simply a sliding viewport over the ordered rows. For each row, it defines a span: "look from here back to there." The running total works because, by default, the viewport stretches from the very first row down to the current one. Move to the next row and the viewport stretches one row further. That sliding is the running total.

Once you can *control* the frame, you unlock new shapes — most importantly the **moving average**: a frame that holds only the last N rows, sliding along like a fixed-width window scrolling down a column of numbers.

You write a frame with three ingredients:

- A **unit**: `ROWS` (count physical rows) or `RANGE` (group rows by value).
- A **`BETWEEN ... AND ...`** span using boundaries like `UNBOUNDED PRECEDING` (the start), `N PRECEDING`, `CURRENT ROW`, `N FOLLOWING`, `UNBOUNDED FOLLOWING` (the end).

So `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` means "this row plus the two before it" — a 3-row window.

**`ROWS` vs `RANGE`** is the subtle part. `ROWS` counts actual rows — "the previous 3 rows," period. `RANGE` works by *value*: with ties in the `ORDER BY`, `RANGE` pulls in *all* rows sharing the current row's value as if they were one. For a clean count of N rows, you almost always want `ROWS`.

## Why it matters

The default frame is a frequent source of quiet bugs. When `LAST_VALUE` returns the "wrong" answer, or a running total jumps oddly across tied dates, the frame is the culprit. Knowing the default exists — and how to override it — is what separates window functions that *mostly* work from ones you trust.

And the payoff is real: rolling N-period averages, centered moving averages, "this row plus the next two," bounded running totals. None are possible without naming the frame.

## See it

A true 7-row moving average — each row averages itself and the six before it:

```sql
SELECT
  sale_date,
  amount,
  AVG(amount) OVER (
    ORDER BY sale_date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS moving_avg_7
FROM sales;
```

The viewport is always 7 rows wide (fewer at the very start), sliding down one row at a time.

A **centered** 3-row average — one row back, the current row, one row ahead:

```sql
SELECT
  sale_date,
  amount,
  AVG(amount) OVER (
    ORDER BY sale_date
    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
  ) AS centered_avg
FROM sales;
```

And the fix for the classic `LAST_VALUE` gotcha — spell out the full frame so it really reaches the last row:

```sql
SELECT
  sale_date,
  LAST_VALUE(amount) OVER (
    ORDER BY sale_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS final_amount
FROM sales;
```

> **Dialect note:** The default frame when you supply `ORDER BY` but no frame clause is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` in standard SQL — and most engines follow it, but edge behavior around ties and `RANGE` differs. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **The default frame is `RANGE ... UNBOUNDED PRECEDING AND CURRENT ROW`** *only when you give an `ORDER BY`*. With no `ORDER BY`, the frame is the entire partition. This trips people constantly.
- **`RANGE` lumps ties together.** If two rows share a `sale_date`, a `RANGE` frame treats them as one step — your running total can leap past both at once. Use `ROWS` for predictable row-by-row behavior.
- **`LAST_VALUE` needs the full frame.** Without `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, it returns the current row, not the final one.
- **Edges have shorter windows.** A 7-row moving average only has 1, 2, 3... rows to average at the very start. That's expected, not a bug.
- **Frames require an `ORDER BY`** inside the `OVER` to mean anything — "preceding" needs a sequence to precede in.

## Practice

1. In plain English, explain what the default window frame is and why it sometimes surprises people.
2. Write a 5-row moving average of sale amounts ordered by date.
3. Build a centered 3-row average (one before, current, one after) and say why it might be smoother than a trailing average.
4. Describe a situation where `ROWS` and `RANGE` would give different results, and which you'd choose.

---
**Prev:** [LEAD & LAG: Period-over-Period](./04-lead-lag.md) · **Next:** [Common Table Expressions (CTEs)](./06-ctes.md)
