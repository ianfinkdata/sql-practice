# 6. Designing the Date Dimension

## The idea

Every other dimension in this tier has been shaped by the messiness of
its source data: `dim_customer` inherits near-duplicate people,
`dim_employee` inherits an SCD-shaped hire/termination pattern,
`dim_product` inherits SKU collisions. `dim_date` is different, and
that difference is the whole lesson.

A date dimension isn't extracted from a messy operational system at
all — it's **manufactured**, once, from pure calendar math. There's
nothing to deduplicate (a calendar date can't have a near-duplicate).
There's nothing to historize with SCD logic (October 12th, 2024 will
never need a "corrected" version of itself). And critically, a
well-built date dimension doesn't depend on which fact rows happen to
exist — it should be complete and correct for its entire declared
range *before* a single fact row is loaded, and stay complete even for
dates where nothing happened.

This makes `dim_date` one of the most reusable objects you will ever
build in a data warehousing career. The exact pattern shown here —
an integer `YYYYMMDD` key plus a view deriving year/month/quarter/
day-of-week/weekend attributes from it — works, nearly unchanged, in
Snowflake, BigQuery, Databricks, Postgres, or any other SQL engine.
Swap `strftime()` for that engine's date functions
(`DATE_TRUNC`/`EXTRACT` in Postgres, `FORMAT_DATE` in BigQuery, etc.)
and the design survives completely intact. Very little else in this
tier travels that cleanly across ecosystems — build a good date
dimension once and you'll recognize it (and rebuild variants of it)
for the rest of your career.

## Dissecting `dim_date`

```sql
-- project/gold/dim_date.sql
CREATE VIEW dim_date AS
SELECT
    datekey,
    date,
    CAST(strftime('%Y', date) AS INTEGER) AS year,
    CAST(strftime('%m', date) AS INTEGER) AS month,
    CASE CAST(strftime('%m', date) AS INTEGER)
        WHEN 1 THEN 'January' ... WHEN 12 THEN 'December'
    END AS month_name,
    ((CAST(strftime('%m', date) AS INTEGER) - 1) / 3) + 1 AS quarter,
    CAST(strftime('%d', date) AS INTEGER) AS day_of_month,
    CAST(strftime('%w', date) AS INTEGER) AS day_of_week,  -- 0=Sunday .. 6=Saturday
    CASE CAST(strftime('%w', date) AS INTEGER)
        WHEN 0 THEN 'Sunday' ... WHEN 6 THEN 'Saturday'
    END AS day_name,
    CASE WHEN CAST(strftime('%w', date) AS INTEGER) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend
FROM silver_calendar;
```

Structurally it's simple on purpose: one `SELECT` over
`silver_calendar` (itself a thin pass-through over `bronze_calendar`,
which is built by a `WITH RECURSIVE` date-spine INSERT, not scraped
from any messy source). Every derived column — `year`, `month`,
`month_name`, `quarter`, `day_of_month`, `day_of_week`, `day_name`,
`is_weekend` — is computed once, in one place, from `date`. That's the
core value proposition: without this view, *every* query that needed
"is this a weekend" or "which quarter" would have to repeat that
`strftime` logic inline, and any inconsistency between two analysts'
inline definitions becomes a silent reporting discrepancy. Centralize
it once, in the dimension, and every query downstream inherits the
same correct definition for free.

`datekey` — an `INTEGER` in `YYYYMMDD` form (e.g. `20260630`) — is the
join key `fact_sales.datekey` references, rather than joining on the
`TEXT` `date` column directly. An integer key is smaller, indexes and
joins faster than a text/date type in most engines, and sorts
correctly as a plain number — another detail that generalizes well
beyond SQLite.

## Examples

### 1. Full span and row count

```sql
SELECT COUNT(*) AS total_days, MIN(date) AS min_date, MAX(date) AS max_date
FROM dim_date;
```

| total_days | min_date | max_date |
|---|---|---|
| 7670 | 2018-01-01 | 2038-12-31 |

`dim_date` covers **every day from 2018-01-01 through 2038-12-31** —
7,670 rows, no gaps. Compare that to the actual range of dates
appearing in `fact_sales.order_date`: **2021-01-01 through
2026-06-30** (from `project/docs/facts_sheet.md`). The date dimension
is deliberately built far wider than any fact table currently needs.
That's the point: a date dimension is built once for a generously wide
range and then just... sits there, ready, regardless of how the fact
tables around it grow. You never want a warehouse to break because
someone loaded a fact row for a date the calendar dimension "forgot"
to include.

### 2. One row, fully decoded

```sql
SELECT datekey, date, year, month, month_name, quarter,
       day_of_month, day_of_week, day_name, is_weekend
FROM dim_date
WHERE date = '2026-06-30';
```

| datekey | date | year | month | month_name | quarter | day_of_month | day_of_week | day_name | is_weekend |
|---|---|---|---|---|---|---|---|---|---|
| 20260630 | 2026-06-30 | 2026 | 6 | June | 2 | 30 | 2 | Tuesday | 0 |

Every attribute a typical BI report needs — fiscal-style quarter
grouping, human-readable month/day names, a weekend flag for filtering
out non-business days — is a plain column lookup, not a computed
expression re-run per query.

### 3. Weekend flag correctness, checked across the whole calendar

```sql
SELECT day_name, is_weekend, COUNT(*)
FROM dim_date
GROUP BY day_name, is_weekend
ORDER BY is_weekend, day_name;
```

| day_name | is_weekend | COUNT(*) |
|---|---|---|
| Friday | 0 | 1096 |
| Monday | 0 | 1096 |
| Thursday | 0 | 1096 |
| Tuesday | 0 | 1096 |
| Wednesday | 0 | 1096 |
| Saturday | 1 | 1095 |
| Sunday | 1 | 1095 |

Every `Saturday`/`Sunday` row has `is_weekend = 1`; every weekday row
has `is_weekend = 0` — no exceptions, across all 7,670 days. This kind
of exhaustive check is cheap to run against a date dimension precisely
*because* it's small, complete, and has no messiness to account for —
a rare property compared to every other dimension in this tier.

### 4. Why "complete regardless of facts" matters: the zero-sales-day pattern

```sql
SELECT COUNT(*) FROM agg_daily_sales WHERE order_line_count = 0;
```

| COUNT(*) |
|---|
| 54 |

`agg_daily_sales` (`project/gold/agg_daily_sales.sql`) is built with a
`LEFT JOIN dim_date ... fact_sales` — starting from every date in
`dim_date` and attaching whatever `fact_sales` rows exist for it, not
the other way around. That LEFT JOIN direction is only meaningful
because `dim_date` is guaranteed complete: 54 days between
2021-01-01 and 2026-06-30 had *zero* order lines, and thanks to this
pattern they still appear as real rows in `agg_daily_sales`, with
`order_line_count = 0` and `total_net_amount = 0.0`, instead of
silently vanishing from the report. If you started from `fact_sales`
and joined *out* to `dim_date` instead, every zero-activity day would
simply never appear — a classic, easy-to-miss reporting bug that a
complete date dimension protects you from by construction.

## Beyond Oakhaven: what real date dimensions add

Oakhaven's `dim_date` is intentionally simple. Production date
dimensions in real warehouses commonly extend the same pattern with:

- **Fiscal calendar columns** (`fiscal_year`, `fiscal_quarter`) when a
  company's fiscal year doesn't align with the calendar year — computed
  once here instead of recomputed per report.
- **Holiday flags** (`is_holiday`, `holiday_name`) for business-day
  calculations.
- **Prior-period keys** (e.g., `prior_year_datekey`) to make
  period-over-period comparisons a join instead of date arithmetic in
  every query.
- **Role-playing reuse**: the same `dim_date` table joined multiple
  times in one query under different aliases for different date roles
  on a single fact row. Oakhaven's `fact_sales` actually has two dates
  per row — `order_date` and `ship_date` — but only `order_date` is
  converted to a `datekey` and joined to `dim_date`; `ship_date` isn't
  wired up the same way. That asymmetry is worth noticing as a natural
  extension point: the *same* `dim_date` table could answer "orders by
  ship date" just as well as "orders by order date," by joining it a
  second time on a second date key. (Building that fact-table wiring
  is out of scope here — it's fact design, not dimension design — but
  recognizing the reuse opportunity is squarely a dimension-design
  insight.)

None of these require rethinking the core design — they're columns
added to the same pre-built, complete, dependency-free table. That
extensibility without redesign is the real mark of a well-built date
dimension.

## Common mistakes

- **Building the date dimension only for the fact table's current
  min/max range.** This looks fine until new data arrives outside that
  range (next year's orders) or until you need a "days with zero
  activity" report — both break immediately if the calendar isn't
  built wider than currently strictly necessary.
- **Deriving date parts ad hoc in every query** (`strftime('%Y', ...)`
  scattered across dozens of reports) instead of centralizing them in
  one dimension. Guarantees inconsistency the first time someone
  writes the logic slightly differently.
- **Using the raw date/text column as the join key** instead of an
  integer surrogate like `datekey`. Works, but is slower to join/index
  in most engines and behaves inconsistently across date/text type
  handling between database systems.
- **Joining fact → dim_date instead of dim_date → fact** when the
  report's purpose is to show a complete time series. The join
  direction determines whether zero-activity periods appear or
  silently disappear — see Example 4.

## Key takeaways

- `dim_date` is fundamentally different from Oakhaven's other
  dimensions: it's manufactured from calendar math, not extracted from
  messy source data, so it has no dedup or SCD concerns.
- A good date dimension is built complete for a wide range up front
  (Oakhaven: 2018-01-01 through 2038-12-31, 7,670 rows) and stays
  correct regardless of what fact data currently exists — proven by
  the 54 zero-order days that still surface correctly in
  `agg_daily_sales` via a `LEFT JOIN dim_date → fact_sales`.
- Centralizing date-part derivation (`year`, `quarter`, `day_name`,
  `is_weekend`, etc.) in one dimension, computed once, is strictly
  better than recomputing it per query.
- This is one of the most portable patterns in all of data
  warehousing — the same integer-datekey-plus-derived-attributes
  design works essentially unchanged in any SQL engine, Oakhaven and
  SQLite included.
