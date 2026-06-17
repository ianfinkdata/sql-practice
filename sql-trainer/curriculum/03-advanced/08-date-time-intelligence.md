# Date & Time Intelligence

> Slice, truncate, and do arithmetic on dates — the engine of time-based analytics.

## The idea

Almost every analytics question has a *when* in it. Sales by month. Signups this quarter. Year-to-date revenue. Rolling 30-day activity. To answer them you have to treat dates not as opaque labels but as something you can take apart, round off, and do math with.

There are three moves you'll use constantly.

**Extracting parts.** A date is bundled information — year, month, day, weekday — packed together. Extracting pulls one piece out. "What *year* is this sale in?" "What *day of week*?" It's like reading just the month off a calendar page without caring about the day.

**Truncating.** Often you don't want a single part — you want to *round a date down* to the start of its period. Truncating to the month turns every date in March into "March 1st," so all of March collapses into one bucket. This is the secret to clean monthly and weekly grouping: truncate, then `GROUP BY` the truncated value. Think of it as snapping a date back to the first day of its month, week, or year.

**Date arithmetic.** Dates support math. Add 30 days. Subtract two dates to get the number of days between them. Find "90 days ago." This powers rolling windows ("the last 30 days") and age calculations ("days since signup").

Put these together and you can build a **calendar table** (a `dim_date`) — one row per day, pre-loaded with its year, month, quarter, weekday, and flags like "is weekend." Joining your data to a calendar makes time-based reporting dramatically easier, and guarantees that periods with *no* activity still show up.

## Why it matters

Time is the spine of reporting. Trends, seasonality, growth, retention cohorts — all are date logic at heart. Get comfortable truncating to periods and doing date math, and a huge swath of "by week / by month / year-to-date / last N days" questions become routine.

A calendar dimension is the professional touch: it gives every report a consistent vocabulary of time and solves the "missing days" problem once and for all.

## See it

Extract parts of a date:

```sql
SELECT
  sale_date,
  EXTRACT(YEAR  FROM sale_date)  AS yr,
  EXTRACT(MONTH FROM sale_date)  AS mon,
  EXTRACT(DOW   FROM sale_date)  AS day_of_week
FROM sales;
```

Truncate to the month, then group — the standard "sales by month" report:

```sql
SELECT
  DATE_TRUNC('month', sale_date) AS month,
  SUM(amount) AS monthly_total
FROM sales
GROUP BY DATE_TRUNC('month', sale_date)
ORDER BY month;
```

Date arithmetic — sales in the last 30 days, and each customer's tenure in days:

```sql
SELECT *
FROM sales
WHERE sale_date >= CURRENT_DATE - INTERVAL '30 days';

SELECT
  customer_id,
  CURRENT_DATE - signup_date AS days_since_signup
FROM customers;
```

**Year-to-date (YTD)** — everything from January 1st of the current year through today:

```sql
SELECT SUM(amount) AS ytd_total
FROM sales
WHERE sale_date >= DATE_TRUNC('year', CURRENT_DATE)
  AND sale_date <= CURRENT_DATE;
```

A minimal **calendar / dim_date** built from a sequence (recursion from the previous module), enriched with parts:

```sql
WITH RECURSIVE calendar AS (
  SELECT DATE '2026-01-01' AS day
  UNION ALL
  SELECT day + INTERVAL '1 day' FROM calendar WHERE day < DATE '2026-12-31'
)
SELECT
  day,
  EXTRACT(YEAR  FROM day)    AS yr,
  EXTRACT(MONTH FROM day)    AS mon,
  EXTRACT(DOW   FROM day) IN (0, 6) AS is_weekend
FROM calendar;
```

`LEFT JOIN` your sales onto this and even zero-sale days appear in the report.

> **Dialect note:** Date functions vary *more than almost anything else in SQL.* Truncation is `DATE_TRUNC` (Postgres, Snowflake, BigQuery via `DATE_TRUNC`), but SQL Server uses `DATETRUNC` (2022+) or `DATEPART`/`FORMAT` tricks, and MySQL leans on `DATE_FORMAT`. Adding intervals is `+ INTERVAL` in Postgres/MySQL, `DATEADD()` in SQL Server, `DATE_ADD()` in BigQuery. Day-of-week numbering and week-start conventions differ too. Always check the [Dialect Decoder](../../dialect-decoder/) before shipping date logic.

## Watch out

- **Truncate, don't `EXTRACT`, for grouping across years.** Grouping by `EXTRACT(MONTH ...)` alone merges every January from every year into one bucket. Truncate to month (which keeps the year) instead.
- **Watch the boundaries.** "This month" and "last 30 days" are different windows. Be explicit, and decide whether endpoints are inclusive.
- **Beware time zones and timestamps.** A `TIMESTAMP` carries a time-of-day; `>= today` can silently exclude this morning's rows. Cast to `DATE` when you only care about the day.
- **Date functions are the least portable part of SQL.** Code that runs on Postgres may not run on SQL Server at all. Check the dialect every time.
- **Off-by-one on day-of-week.** Some engines start the week on Sunday (0), others Monday (1). Verify before flagging weekends.

## Practice

1. In plain English, explain the difference between *extracting* the month from a date and *truncating* a date to the month, and when each is right for grouping.
2. Write a "sales by month" report that groups correctly even across multiple years.
3. Compute each customer's tenure in days as of today.
4. Build a year-to-date sales total, and describe how a calendar table would help show months with zero sales.

---
**Prev:** [Recursive CTEs](./07-recursive-ctes.md) · **Next:** [Pivot & Unpivot](./09-pivot-unpivot.md)
