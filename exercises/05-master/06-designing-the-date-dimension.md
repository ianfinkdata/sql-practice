# Exercises: 6. Designing the Date Dimension

<!-- nav -->
Curriculum: [6. Designing the Date Dimension](../../curriculum/05-master/06-designing-the-date-dimension.md). Previous: [5. Slowly Changing Dimensions: Type 1 and Type 2](05-slowly-changing-dimensions-scd-1-and-2.md). Next: [7. Designing the Fact Table](07-designing-the-fact-table.md).
<!-- /nav -->

Work against `project/oakhaven.db`. Read-only — every query below is a
`SELECT`.

---

### 1. Verify the calendar's completeness

Confirm `dim_date`'s total row count and its full date span.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS total_days, MIN(date) AS min_date, MAX(date) AS max_date
FROM dim_date;
```

| total_days | min_date | max_date |
|---|---|---|
| 7670 | 2018-01-01 | 2038-12-31 |

One row for every day from 2018-01-01 through 2038-12-31, no gaps —
21 full years, built once, independent of any fact table.

</details>

---

### 2. A sanity check most "messy" dimensions can't offer: leap days

Count how many `2026`-through-`2038`-range leap days (`month = 2`,
`day_of_month = 29`) exist in `dim_date`. Does the count look right
for the span?

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM dim_date WHERE month = 2 AND day_of_month = 29;
```

| COUNT(*) |
|---|
| 5 |

5 leap days across the full 2018–2038 span (2020, 2024, 2028, 2032,
2036 are the leap years in that range). This kind of exhaustive
correctness check — "does every leap year in the range have exactly
one Feb 29, and no non-leap year has one" — is cheap and conclusive
for a manufactured date dimension, precisely because there's no source
messiness to account for. You could never run an equivalently
confident check against, say, `dim_customer`'s `state` column.

</details>

---

### 3. Reproduce the zero-order-day pattern yourself

Using a `LEFT JOIN` from `dim_date` to `fact_sales` (dimension first,
fact second — not the other way around), restricted to the date range
`fact_sales.order_date` actually spans (2021-01-01 through
2026-06-30), count how many calendar days have zero order lines.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS zero_order_days
FROM (
    SELECT d.datekey, COUNT(f.order_id) AS n
    FROM dim_date d
    LEFT JOIN fact_sales f ON f.datekey = d.datekey
    WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
    GROUP BY d.datekey
) day_counts
WHERE n = 0;
```

| zero_order_days |
|---|
| 54 |

54 days had no sales activity at all, and this query still finds them
correctly — because it starts from the complete `dim_date` calendar
and joins *out* to whatever `fact_sales` rows happen to exist, rather
than starting from `fact_sales` (which, by definition, can never
contain a day where nothing happened). Try rewriting this query
starting `FROM fact_sales` with a `RIGHT`-style intent instead, and
notice it becomes awkward or impossible in SQLite — that awkwardness
is itself evidence for why "dimension-first" is the correct join
direction for this kind of report.

</details>

---

### 4. Confirm the `datekey` encoding is internally consistent

For every row in `dim_date`, confirm that the stored `datekey` integer
actually equals the `YYYYMMDD` encoding of that row's `date` column
(i.e., that there's no drift between the two).

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS total,
       SUM(CASE WHEN datekey = CAST(strftime('%Y%m%d', date) AS INTEGER) THEN 1 ELSE 0 END) AS matching
FROM dim_date;
```

| total | matching |
|---|---|
| 7670 | 7670 |

All 7,670 rows match — `datekey` and `date` are always consistent
encodings of the same day. This kind of self-consistency check is
worth running on any date dimension you inherit or build yourself:
it's cheap, and a mismatch (e.g., off-by-one-day drift from a time
zone bug) is a serious, hard-to-notice-otherwise correctness bug.

</details>

---

### 5. Explore the role-playing dimension opportunity

`fact_sales` carries both `order_date` and `ship_date`, but only
`order_date` is converted into a `datekey` and stored as a join key.
First, check how many `fact_sales` rows have a non-`NULL` `ship_date`.
Then, without modifying any gold object, write a query that joins
those rows to `dim_date` a *second* time — via `ship_date` instead of
`datekey` — to pull back the day-of-week and quarter the order was
*shipped* (not placed).

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS total, SUM(CASE WHEN ship_date IS NOT NULL THEN 1 ELSE 0 END) AS has_ship_date
FROM fact_sales;
```

| total | has_ship_date |
|---|---|
| 12000 | 10269 |

10,269 of 12,000 order lines have a `ship_date` (the remaining ~15%
are `NULL`, per the data dictionary). Now join those rows to
`dim_date` on `ship_date` instead of the fact table's stored
`datekey`:

```sql
SELECT f.order_id, f.order_line_id, f.order_date, f.ship_date,
       d.day_name AS ship_day_name, d.quarter AS ship_quarter
FROM fact_sales f
JOIN dim_date d ON CAST(strftime('%Y%m%d', f.ship_date) AS INTEGER) = d.datekey
WHERE f.ship_date IS NOT NULL
ORDER BY f.order_id
LIMIT 5;
```

| order_id | order_line_id | order_date | ship_date | ship_day_name | ship_quarter |
|---|---|---|---|---|---|
| 1 | 1 | 2024-03-05 | 2024-03-15 | Friday | 1 |
| 1 | 2 | 2024-03-05 | 2024-03-15 | Friday | 1 |
| 2 | 1 | 2021-11-04 | 2021-11-11 | Thursday | 4 |
| 2 | 2 | 2021-11-04 | 2021-11-11 | Thursday | 4 |
| 3 | 1 | 2023-01-13 | 2023-01-23 | Monday | 1 |

The exact same `dim_date` table — no changes, no new object — answers
"what quarter did this order *ship* in" just as well as "what quarter
was it *placed* in," simply by joining on a different date column.
This is the general concept of a **role-playing dimension**: one
physical dimension table, logically reused under different aliases for
different roles a single fact row can have (here, "order date" and
"ship date" are two roles of the same underlying `dim_date`). Wiring
this permanently into `fact_sales` (e.g., adding a `ship_datekey`
column) is a fact-table design decision, out of scope for this
dimension-focused module — but recognizing that the dimension itself
requires zero changes to support it is the key insight.

</details>

---

<!-- nav -->
Curriculum: [6. Designing the Date Dimension](../../curriculum/05-master/06-designing-the-date-dimension.md). Previous: [5. Slowly Changing Dimensions: Type 1 and Type 2](05-slowly-changing-dimensions-scd-1-and-2.md). Next: [7. Designing the Fact Table](07-designing-the-fact-table.md).
<!-- /nav -->
