# 6. Time Intelligence

<!-- nav -->
Previous: [5. Recursive CTEs](05-recursive-ctes.md). Next: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md). Exercises: [6. Time Intelligence](../../exercises/03-advanced/06-time-intelligence.md).
<!-- /nav -->

## The idea

"Time intelligence" is the umbrella term for pulling calendar meaning out
of dates: which year, which month, which quarter, which weekday, how many
days between two dates. SQLite stores dates as plain `TEXT` (ISO
`YYYY-MM-DD` strings, per Oakhaven's convention), so all of this comes down
to a handful of built-in date functions rather than a special date type.

This module covers those functions directly; the next module covers the
*date spine* pattern that depends on them.

## The three core SQLite date functions

- **`date(dateval, modifier, ...)`** — returns a date, optionally shifted
  by modifiers like `'+1 day'`, `'-3 months'`, `'start of month'`,
  `'weekday 1'`. Already seen throughout the recursive CTE module
  (`date(d, '+1 day')`).
- **`strftime(format, dateval)`** — formats a date into a string, or
  extracts a specific part as text: `'%Y'` (year), `'%m'` (month, zero
  padded), `'%d'` (day), `'%w'` (weekday, `0`=Sunday..`6`=Saturday), `'%W'`
  (week of year).
- **`julianday(dateval)`** — converts a date into a Julian day number (a
  plain floating-point count of days since a fixed epoch). Not useful on
  its own, but subtracting two `julianday()` calls gives you a day
  difference — SQLite has no `DATEDIFF()`; this is how it's done instead.

`strftime()` returns text, so extracted year/month values need `CAST(...
AS INTEGER)` before you sort or compare them numerically — this is exactly
what `gold/dim_date.sql` does (see below).

## Example 1: extracting date parts

```sql
SELECT order_date,
       strftime('%Y', order_date) AS yr,
       strftime('%m', order_date) AS mo,
       CASE CAST(strftime('%w', order_date) AS INTEGER)
         WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
         WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday'
         WHEN 5 THEN 'Friday' WHEN 6 THEN 'Saturday'
       END AS weekday
FROM fact_sales
WHERE order_date IS NOT NULL
LIMIT 3;
```

Verified output:

| order_date | yr | mo | weekday |
|---|---|---|---|
| 2024-03-05 | 2024 | 03 | Tuesday |
| 2024-03-05 | 2024 | 03 | Tuesday |
| 2021-11-04 | 2021 | 11 | Thursday |

This is exactly the logic behind `gold/dim_date.sql`, Oakhaven's date
dimension view, built on top of `silver_calendar` (itself a thin
pass-through over the recursive-CTE-built `bronze_calendar`):

```sql
CREATE VIEW dim_date AS
SELECT
    datekey,
    date,
    CAST(strftime('%Y', date) AS INTEGER) AS year,
    CAST(strftime('%m', date) AS INTEGER) AS month,
    CASE CAST(strftime('%m', date) AS INTEGER)
        WHEN 1 THEN 'January' WHEN 2 THEN 'February' WHEN 3 THEN 'March'
        WHEN 4 THEN 'April' WHEN 5 THEN 'May' WHEN 6 THEN 'June'
        WHEN 7 THEN 'July' WHEN 8 THEN 'August' WHEN 9 THEN 'September'
        WHEN 10 THEN 'October' WHEN 11 THEN 'November' WHEN 12 THEN 'December'
    END AS month_name,
    ((CAST(strftime('%m', date) AS INTEGER) - 1) / 3) + 1 AS quarter,
    CAST(strftime('%d', date) AS INTEGER) AS day_of_month,
    CAST(strftime('%w', date) AS INTEGER) AS day_of_week,
    CASE CAST(strftime('%w', date) AS INTEGER)
        WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    CASE WHEN CAST(strftime('%w', date) AS INTEGER) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend
FROM silver_calendar;
```

The `quarter` formula is worth pausing on: `((month - 1) / 3) + 1`. SQLite
does *integer* division here (both operands are integers), so month 1–3
gives `(0..2)/3 = 0`, `+1 = 1`; month 4–6 gives `(3..5)/3 = 1`, `+1 = 2`;
and so on. Verified against real rows:

```sql
SELECT date, year, month, quarter FROM dim_date
WHERE date IN ('2026-01-15','2026-04-01','2026-07-01','2026-10-01');
```

| date | year | month | quarter |
|---|---|---|---|
| 2026-01-15 | 2026 | 1 | 1 |
| 2026-04-01 | 2026 | 4 | 2 |
| 2026-07-01 | 2026 | 7 | 3 |
| 2026-10-01 | 2026 | 10 | 4 |

Every dimension used throughout this course — year, month name, quarter,
weekday name, weekend flag — is derived this way, once, in `dim_date`, so
no downstream query has to repeat this logic.

## Example 2: day differences with `julianday()`

*Question: how many days elapsed between order and shipment?*

```sql
SELECT order_id, order_line_id, order_date, ship_date,
       CAST(julianday(ship_date) - julianday(order_date) AS INTEGER) AS days_to_ship
FROM silver_sales
WHERE ship_date IS NOT NULL AND order_date IS NOT NULL
LIMIT 5;
```

Verified output:

| order_id | order_line_id | order_date | ship_date | days_to_ship |
|---|---|---|---|---|
| 1 | 1 | 2024-03-05 | 2024-03-15 | 10 |
| 1 | 2 | 2024-03-05 | 2024-03-15 | 10 |
| 2 | 1 | 2021-11-04 | 2021-11-11 | 7 |
| 2 | 2 | 2021-11-04 | 2021-11-11 | 7 |
| 3 | 1 | 2023-01-13 | 2023-01-23 | 10 |

`julianday()` returns a float, so the raw subtraction can carry a tiny
fractional remainder even for whole dates (SQLite's Julian day arithmetic)
— `CAST(... AS INTEGER)` truncates that away, giving a clean day count.

`silver_sales` deliberately does *not* filter out bad rows here — recall
from the data dictionary that ~2% of orders have a `ship_date`
chronologically *before* `order_date` (intentional bad data). This same
query surfaces those instantly as negative day counts:

```sql
SELECT order_id, order_line_id, order_date, ship_date,
       CAST(julianday(ship_date) - julianday(order_date) AS INTEGER) AS days_to_ship
FROM silver_sales
WHERE ship_date IS NOT NULL AND order_date IS NOT NULL
  AND julianday(ship_date) < julianday(order_date)
LIMIT 5;
```

Verified output:

| order_id | order_line_id | order_date | ship_date | days_to_ship |
|---|---|---|---|---|
| 111 | 1 | 2023-10-26 | 2023-10-23 | -3 |
| 133 | 1 | 2021-05-23 | 2021-05-22 | -1 |
| 158 | 1 | 2023-10-13 | 2023-10-10 | -3 |
| 158 | 2 | 2023-10-13 | 2023-10-10 | -3 |
| 323 | 1 | 2021-11-11 | 2021-11-07 | -4 |

Total count of these: **216** rows — matching the facts sheet's documented
figure exactly (`silver_sales` ship_date-before-order_date, 1.8%). This is
a good habit to build: a `julianday()` difference is also a cheap, free
data-quality check.

## Example 3: `date()` modifiers for month boundaries

```sql
SELECT order_date,
       date(order_date, 'start of month') AS month_start,
       date(order_date, 'start of month', '+1 month', '-1 day') AS month_end
FROM fact_sales
WHERE order_date IS NOT NULL
LIMIT 3;
```

Verified output:

| order_date | month_start | month_end |
|---|---|---|
| 2024-03-05 | 2024-03-01 | 2024-03-31 |
| 2024-03-05 | 2024-03-01 | 2024-03-31 |
| 2021-11-04 | 2021-11-01 | 2021-11-30 |

`date()` modifiers chain left to right: `'start of month'` snaps to the
1st, then `'+1 month'` advances a month, then `'-1 day'` steps back one —
landing exactly on the last day of the *original* month, correctly
handling months of different lengths (28/29/30/31 days) with no manual
case logic.

## Common mistakes

- **Comparing `strftime()` output as text without casting.** `'%Y'`
  returns `TEXT`; `'9' > '10'` is true as strings (lexicographic) but false
  as numbers. Always `CAST(... AS INTEGER)` before doing numeric
  comparisons or sorting on extracted date parts — `dim_date` does this
  everywhere.
- **Subtracting date strings directly** (`ship_date - order_date`) instead
  of via `julianday()`. SQLite dates are `TEXT`; direct arithmetic on them
  doesn't do what you want. Always go through `julianday()` for date math.
- **Forgetting `julianday()` differences can be fractional** if either
  input includes a time component, not just a date. Oakhaven's ISO dates
  are date-only after silver-layer parsing, so this rarely bites here, but
  it's a common surprise with raw timestamp data.
- **Reinventing `dim_date`'s derivations inline, query after query.**
  Every derivation shown here (year, month, quarter, weekday, weekend
  flag) already exists as a column on `dim_date` — join to it instead of
  recomputing `strftime()` expressions in every query.

## Key takeaways

- SQLite has three core date functions: `date()` (shift/format a date),
  `strftime()` (extract parts as text), `julianday()` (convert to a
  day-number float for arithmetic).
- Always `CAST(strftime(...) AS INTEGER)` before treating extracted date
  parts numerically.
- Day differences go through `julianday(a) - julianday(b)`, then usually
  `CAST(... AS INTEGER)` to drop the fractional remainder.
- `gold/dim_date.sql` centralizes every common date derivation
  (year/month/month_name/quarter/day_name/is_weekend) exactly once — prefer
  joining to it over recomputing `strftime()` logic in every query.

---

<!-- nav -->
Previous: [5. Recursive CTEs](05-recursive-ctes.md). Next: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md). Exercises: [6. Time Intelligence](../../exercises/03-advanced/06-time-intelligence.md).
<!-- /nav -->
