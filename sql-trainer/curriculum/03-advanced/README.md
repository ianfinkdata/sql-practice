# Tier 3 — Advanced: Analytics

> Answer the questions a single `GROUP BY` can't.

Welcome to the tier where SQL stops being a way to *retrieve* data and becomes a way to *analyze* it. In Tier 2 you learned to group, join, and nest queries. That gets you a long way — but it hits a wall the moment you want to keep every row *and* compare it to its group, rank rows within groups, accumulate running totals, measure period-over-period change, walk a hierarchy, or reshape data for human eyes.

This tier is built around **window functions** — the single biggest leap in analytical SQL — and the supporting cast that makes real reporting possible: CTEs, recursion, date intelligence, pivoting, and text wrangling. Work through them in order; each builds on the last.

## Modules

1. [Window Functions: The Big Idea](./01-window-functions-intro.md) — Calculate across related rows without collapsing them; `OVER`, `PARTITION BY`, `ORDER BY`.
2. [Ranking](./02-ranking.md) — `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`, ties, and the top-N-per-group pattern.
3. [Running Totals & Moving Averages](./03-running-totals.md) — Accumulating sums and averages with `OVER (ORDER BY ...)`, partitioned.
4. [LEAD & LAG: Period-over-Period](./04-lead-lag.md) — Peek at the previous or next row to compute change, deltas, and growth percent.
5. [Window Frames](./05-window-frames.md) — `ROWS` vs `RANGE`, frame boundaries, the default-frame gotcha, and rolling N-row averages.
6. [Common Table Expressions (CTEs)](./06-ctes.md) — `WITH` for readability and reuse; chaining CTEs; CTE vs subquery vs view.
7. [Recursive CTEs](./07-recursive-ctes.md) — Anchor plus recursive member; hierarchies, sequences, and calendars.
8. [Date & Time Intelligence](./08-date-time-intelligence.md) — Extracting, truncating, date math, calendar tables, YTD and rolling windows (heavy on dialects).
9. [Pivot & Unpivot](./09-pivot-unpivot.md) — Rows to columns with conditional aggregation, and back again; `PIVOT`/`UNPIVOT` where supported.
10. [Strings & Regular Expressions](./10-strings-regex.md) — String functions, `LIKE`, and regex pattern matching for cleaning and extracting text.

## The shared dataset

Every example in this tier uses the same four tables, so you can focus on the technique, not the schema:

- `customers(customer_id, customer_name, region, signup_date, email)`
- `sales(sale_id, sale_date, customer_id, rep_id, amount)`
- `sales_rep(rep_id, rep_name, commission_rate, hire_date)`
- `products(product_id, product_name, category, unit_price)`

> **A note on dialects:** This tier wades into the parts of SQL that vary most between database engines — date functions and regular expressions especially. Where it matters, you'll find a **Dialect note** pointing to the [Dialect Decoder](../../dialect-decoder/). When in doubt, check it.

---
**Prev:** [Tier 2: Intermediate](../02-intermediate/) · **Next:** [Tier 4: Expert](../04-expert/)
