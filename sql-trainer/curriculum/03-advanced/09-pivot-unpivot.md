# Pivot & Unpivot

> Turn rows into columns (and back) to reshape data for reading.

## The idea

Databases love **tall, narrow** data: one fact per row. `(region, month, total)`, over and over. It's efficient and flexible — but it's awkward to *read*. A human scanning a report would rather see a **grid**: regions down the side, months across the top, totals filling the cells. That grid shape is what a spreadsheet gives you.

**Pivoting** is the transformation from tall to wide — taking the *values* in a column and spreading them out into *new columns*. The distinct months stop being rows and become headers; the totals slot into the grid. You're rotating the data ninety degrees.

The everyday way to pivot in standard SQL is **conditional aggregation**: a `CASE` inside an aggregate. The idea is delightfully simple — for each output column, write a `CASE` that says "use the amount *only* when this row belongs in this column, otherwise contribute nothing," then aggregate. One `CASE`-wrapped `SUM` per column you want. You decide the columns up front, by hand.

**Unpivoting** is the reverse: a wide grid back into tall rows. You have `q1, q2, q3, q4` columns and want one `(quarter, amount)` row per value. This is the shape databases (and `GROUP BY`) actually prefer, so unpivoting is common when cleaning up spreadsheet-style imports.

Some databases offer dedicated `PIVOT` / `UNPIVOT` keywords that do this more compactly — but they're among the *least* portable features in SQL, so the `CASE` approach is the reliable lingua franca worth knowing first.

## Why it matters

Reports are for people, and people read grids. "Monthly revenue by region" as a matrix is instantly scannable; the same data as 48 tall rows is not. Pivoting is how you hand a database result to a human (or a spreadsheet, or a charting tool) in the shape they expect.

Unpivoting matters when data *arrives* in grid form — exports, manually-built spreadsheets — and you need it tall so you can filter, group, and join it normally. Reshaping is a daily reality of data work.

## See it

Pivot sales into a grid: one row per region, one column per quarter, using conditional aggregation:

```sql
SELECT
  c.region,
  SUM(CASE WHEN EXTRACT(QUARTER FROM s.sale_date) = 1 THEN s.amount ELSE 0 END) AS q1,
  SUM(CASE WHEN EXTRACT(QUARTER FROM s.sale_date) = 2 THEN s.amount ELSE 0 END) AS q2,
  SUM(CASE WHEN EXTRACT(QUARTER FROM s.sale_date) = 3 THEN s.amount ELSE 0 END) AS q3,
  SUM(CASE WHEN EXTRACT(QUARTER FROM s.sale_date) = 4 THEN s.amount ELSE 0 END) AS q4
FROM sales s
JOIN customers c ON c.customer_id = s.customer_id
GROUP BY c.region;
```

Read one `CASE` column at a time: "sum the amount, but only for quarter 1; everything else contributes zero." The `GROUP BY c.region` gives one row per region. The result is a clean region-by-quarter matrix.

**Unpivot** the grid back to tall rows. The portable way stacks the columns with `UNION ALL`:

```sql
SELECT region, 'q1' AS quarter, q1 AS amount FROM quarterly_grid
UNION ALL SELECT region, 'q2', q2 FROM quarterly_grid
UNION ALL SELECT region, 'q3', q3 FROM quarterly_grid
UNION ALL SELECT region, 'q4', q4 FROM quarterly_grid;
```

Each `SELECT` peels off one column and labels it, then they stack into a tall `(region, quarter, amount)` result.

> **Dialect note:** SQL Server and Oracle provide dedicated `PIVOT` and `UNPIVOT` operators; Snowflake and BigQuery have their own `PIVOT` syntax. None are standard or interchangeable, and most can't pivot an *unknown* set of values without dynamic SQL. The `CASE` and `UNION ALL` approaches shown here run nearly everywhere. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **You must know the columns in advance.** Conditional aggregation needs one `CASE` per output column, written by hand. A truly *dynamic* number of columns requires dynamic SQL — a different, more advanced tool.
- **Choose your "empty cell" deliberately.** `ELSE 0` fills gaps with zero; omit it (or use `ELSE NULL`) if you'd rather show blanks. Zero and NULL tell different stories.
- **Pick the right aggregate.** `SUM` for totals, `MAX`/`MIN` when each cell holds a single value, `COUNT` for tallies. The wrong one silently distorts the grid.
- **Wide tables are for reading, not storing.** Pivot at the *presentation* layer; keep your stored data tall and tidy.
- **Vendor `PIVOT` syntax doesn't travel.** A `PIVOT` query from SQL Server won't run on Postgres. The `CASE` form is your portable fallback.

## Practice

1. In plain English, explain what pivoting does and why a grid is easier for people to read than tall rows.
2. Write a conditional-aggregation query that shows total sales per region broken into four quarter columns.
3. Decide whether empty cells in that grid should be 0 or NULL, and justify your choice.
4. Take a four-column quarterly grid and describe (or write) how you'd unpivot it back into `(region, quarter, amount)` rows.

---
**Prev:** [Date & Time Intelligence](./08-date-time-intelligence.md) · **Next:** [Strings & Regular Expressions](./10-strings-regex.md)
