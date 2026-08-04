# 7. The Date-Spine Pattern

<!-- nav -->
Previous: [6. Time Intelligence](06-time-intelligence.md). Next: [8. Writing Your First Silver View](08-writing-your-first-silver-view.md). Exercises: [7. The Date-Spine Pattern](../../exercises/03-advanced/07-the-date-spine-pattern.md).
<!-- /nav -->

## The idea

If you build a sales-by-day report with a plain `GROUP BY order_date` over
`fact_sales`, you get one row per day **that had at least one order**. Days
with zero orders simply don't appear — not as a row with `0`, but as
nothing at all. For a lot of real questions ("show me a chart of daily
sales for the quarter," "what's our longest streak without an order?")
that silent absence is actively wrong: a missing row looks identical to a
day that was never queried, and most charting/BI tools will just skip the
gap rather than plot a zero.

The fix is the **date-spine pattern**: start from a complete, gapless
calendar (`dim_date`, itself built from the recursive-CTE-generated
`bronze_calendar` — Module 5), and `LEFT JOIN` your actual data onto it.
Every date in the spine survives; dates with no matching data just get
`NULL`s from the joined side, which you then `COALESCE` down to `0`.

## The pattern

```sql
SELECT d.date, ..., COALESCE(SUM(f.measure), 0) AS total
FROM dim_date d
LEFT JOIN fact_table f ON f.datekey = d.datekey
WHERE d.date BETWEEN start_date AND end_date
GROUP BY d.date, ...
```

The load-bearing detail: **the spine table is on the left of the `LEFT
JOIN` and drives the `FROM` clause.** Get this backwards — `FROM
fact_table f LEFT JOIN dim_date d ON ...` — and you're back to only seeing
dates that already have data, because now `fact_table` (not the spine) is
what decides which rows exist.

## Worked example: dissecting `gold/agg_daily_sales.sql`

Full contents:

```sql
DROP VIEW IF EXISTS agg_daily_sales;
CREATE VIEW agg_daily_sales AS
SELECT
    d.date AS order_date,
    d.year,
    d.month,
    d.day_name,
    d.is_weekend,
    COUNT(f.order_line_id) AS order_line_count,
    ROUND(COALESCE(SUM(f.net_amount), 0), 2) AS total_net_amount
FROM dim_date d
LEFT JOIN fact_sales f ON f.datekey = d.datekey
WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
GROUP BY d.date, d.year, d.month, d.day_name, d.is_weekend
ORDER BY d.date;
```

Reading it against the pattern above:

- **`FROM dim_date d`** — the spine drives the query. `dim_date` has 7,670
  rows (2018-01-01 through 2038-12-31); this view only wants the
  operational sales window, filtered later.
- **`LEFT JOIN fact_sales f ON f.datekey = d.datekey`** — every date row
  from `dim_date` is kept regardless of whether it finds a match in
  `fact_sales`. Days with orders get one matched row per order line (which
  is why the aggregates below need `GROUP BY`); days without orders get a
  single unmatched row where every `f.*` column is `NULL`.
- **`WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'`** — restricts the
  spine to Oakhaven's actual operational window. The file's own comment
  flags that these literals mirror `build_lib/config.py`'s `SALES_START`
  and `SNAPSHOT_DATE` constants, and must be kept in sync if those ever
  change — a good example of a magic-value dependency worth documenting
  in the SQL itself.
- **`COUNT(f.order_line_id)`** — counting a *column* (not `COUNT(*)`) is
  deliberate: `COUNT(column)` ignores `NULL`s, so on a zero-order day
  (where `f.order_line_id` is `NULL` from the unmatched `LEFT JOIN`) this
  correctly evaluates to `0`. `COUNT(*)` would instead count the single
  unmatched placeholder row and wrongly report `1`.
- **`COALESCE(SUM(f.net_amount), 0)`** — `SUM()` over zero non-null rows
  returns `NULL` in SQL, not `0`. `COALESCE(..., 0)` converts that `NULL`
  into an honest `0.0` so a zero-order day reports `total_net_amount = 0`
  instead of a missing/`NULL` total.

## Verifying the gap-filling actually works

The facts sheet states the operational window (2021-01-01 through
2026-06-30) contains exactly **54** zero-order days. Confirmed directly:

```sql
SELECT COUNT(*) FROM agg_daily_sales WHERE order_line_count = 0;
```

| COUNT(*) |
|---|
| 54 |

A sample of them:

```sql
SELECT order_date, day_name, is_weekend, order_line_count, total_net_amount
FROM agg_daily_sales WHERE order_line_count = 0 ORDER BY order_date LIMIT 6;
```

| order_date | day_name | is_weekend | order_line_count | total_net_amount |
|---|---|---|---|---|
| 2021-01-08 | Friday | 0 | 0 | 0.0 |
| 2021-03-02 | Tuesday | 0 | 0 | 0.0 |
| 2021-03-13 | Saturday | 1 | 0 | 0.0 |
| 2021-03-26 | Friday | 0 | 0 | 0.0 |
| 2021-04-30 | Friday | 0 | 0 | 0.0 |
| 2021-05-01 | Saturday | 1 | 0 | 0.0 |

These are real calendar days that genuinely had zero orders — a weekday
(Friday) is just as likely to show up here as a weekend day, since
Oakhaven's order volume isn't modeled with a strong day-of-week
seasonality. Without the date spine, all 54 of these rows would simply not
exist in the output.

To see exactly what the `INNER JOIN` mistake would have cost, rebuild the
same query with a plain `JOIN` instead of `LEFT JOIN`:

```sql
SELECT COUNT(*) FROM (
  SELECT d.date FROM dim_date d
  JOIN fact_sales f ON f.datekey = d.datekey
  WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
  GROUP BY d.date
);
```

| COUNT(*) |
|---|
| 1953 |

The full window has 2,007 days (`SELECT COUNT(*) FROM dim_date WHERE date
BETWEEN '2021-01-01' AND '2026-06-30'`); an `INNER JOIN` produces only
1,953 of them — exactly 2,007 − 1,953 = **54** short, matching the
zero-order-day count precisely. That's the date-spine pattern's entire
value proposition, quantified.

## Common mistakes

- **Putting the fact table first in the `FROM` clause.** `FROM fact_sales
  f LEFT JOIN dim_date d ON ...` looks superficially similar but drives
  the row set from the *fact* table, silently reintroducing the exact gaps
  the spine was supposed to eliminate.
- **Using `COUNT(*)` instead of `COUNT(column)`** when counting matched
  rows after a `LEFT JOIN`. `COUNT(*)` counts the placeholder row itself on
  unmatched dates, always reporting at least 1, even on a genuine
  zero-order day.
- **Forgetting `COALESCE()` around `SUM()`/`AVG()`.** These return `NULL`,
  not `0`, when there's nothing to aggregate — which then breaks any
  downstream arithmetic or chart that isn't expecting a `NULL`.
- **Filtering on a joined (fact-side) column in `WHERE` instead of
  `ON`.** Adding a `fact_sales` condition to `WHERE` (rather than folding
  it into the `ON` clause) silently turns the `LEFT JOIN` back into an
  effective `INNER JOIN`, because `WHERE` evaluates after the join and
  discards any row where that column is `NULL` — including every
  zero-order day. If you need to filter the fact side while still keeping
  spine rows with no match, the condition belongs in `ON`, not `WHERE`.

## Key takeaways

- The date-spine pattern: `FROM dim_date LEFT JOIN fact_table ON
  datekey = datekey`, spine on the left, so every date survives regardless
  of whether it has matching data.
- `agg_daily_sales` uses exactly this pattern and genuinely needs it: 54
  of the 2,007 days in its 2021-01-01–2026-06-30 window have zero orders,
  and would silently vanish under a plain `JOIN`.
- `COUNT(column)` (ignores `NULL`) and `COALESCE(SUM(...), 0)` (converts a
  `NULL` sum to `0`) are the two companion techniques that make the
  zero-order rows report clean `0`s instead of `NULL`s.
- This pattern generalizes beyond dates: any time you need "every X, even
  ones with no matching data," start the `FROM` clause from the complete
  list of X and `LEFT JOIN` the data onto it.

---

<!-- nav -->
Previous: [6. Time Intelligence](06-time-intelligence.md). Next: [8. Writing Your First Silver View](08-writing-your-first-silver-view.md). Exercises: [7. The Date-Spine Pattern](../../exercises/03-advanced/07-the-date-spine-pattern.md).
<!-- /nav -->
