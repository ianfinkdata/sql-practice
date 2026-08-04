# Exercises: The Date-Spine Pattern

<!-- nav -->
Curriculum: [7. The Date-Spine Pattern](../../curriculum/03-advanced/07-the-date-spine-pattern.md). Previous: [6. Time Intelligence](06-time-intelligence.md). Next: [8. Writing Your First Silver View](08-writing-your-first-silver-view.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Zero-order days in a single month

Using `agg_daily_sales`, list every zero-order day (`order_line_count =
0`) that falls in December 2025, with its `day_name`.

<details>
<summary>Show solution</summary>

```sql
SELECT order_date, day_name
FROM agg_daily_sales
WHERE order_line_count = 0 AND order_date LIKE '2025-12%';
```

Verified output:

| order_date | day_name |
|---|---|
| 2025-12-21 | Sunday |

Only one zero-order day in all of December 2025 — most days in this
window had at least some order activity.

</details>

---

### 2. Build your own category-scoped date spine

Using the `dim_date` LEFT JOIN pattern (spine on the left), build a
day-by-day order-line count for the `Winter Sports` category only, for
the first 10 days of January 2021. (Hint: move the category filter into
the `ON` clause of the join, not `WHERE` — otherwise you'll accidentally
turn the `LEFT JOIN` back into an effective `INNER JOIN`.)

<details>
<summary>Show solution</summary>

```sql
SELECT d.date, COUNT(f.order_line_id) AS lines
FROM dim_date d
LEFT JOIN fact_sales f ON f.datekey = d.datekey
    AND f.product_id IN (SELECT product_id FROM dim_product WHERE category = 'Winter Sports')
WHERE d.date BETWEEN '2021-01-01' AND '2021-01-10'
GROUP BY d.date
ORDER BY d.date;
```

Verified output:

| date | lines |
|---|---|
| 2021-01-01 | 1 |
| 2021-01-02 | 0 |
| 2021-01-03 | 1 |
| 2021-01-04 | 1 |
| 2021-01-05 | 2 |
| 2021-01-06 | 2 |
| 2021-01-07 | 1 |
| 2021-01-08 | 0 |
| 2021-01-09 | 1 |
| 2021-01-10 | 0 |

Note the category filter (`f.product_id IN (...)`) lives in the `ON`
clause, alongside the join key — this is what keeps every date row
(including 2021-01-02, 2021-01-08, 2021-01-10, which had zero Winter
Sports lines) in the result. Moving that same filter to `WHERE` would
silently drop those three rows, since `WHERE` evaluates after the join and
discards rows where the filtered (fact-side) column is `NULL`.

</details>

---

### 3. Count the gap across the whole window

Using the same category-scoped spine pattern as Exercise 2, but for the
*entire* operational window (2021-01-01 through 2026-06-30), count how
many days had zero `Winter Sports` order lines.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM (
    SELECT d.date, COUNT(f.order_line_id) AS lines
    FROM dim_date d
    LEFT JOIN fact_sales f ON f.datekey = d.datekey
        AND f.product_id IN (SELECT product_id FROM dim_product WHERE category = 'Winter Sports')
    WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
    GROUP BY d.date
    HAVING lines = 0
);
```

Verified output: **888** days out of 2,007 in the window had zero Winter
Sports order lines — a single category is naturally sparser day-to-day
than the whole-store `agg_daily_sales` view (which only has 54 zero-order
days across all categories combined).

</details>

---

### 4. Count zero-order days for a narrower category and quarter

Using the same pattern, count zero-order days for the `Accessories`
category specifically within Q1 2021 (2021-01-01 through 2021-03-31).

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM (
    SELECT d.date, COUNT(f.order_line_id) AS lines
    FROM dim_date d
    LEFT JOIN fact_sales f ON f.datekey = d.datekey
        AND f.product_id IN (SELECT product_id FROM dim_product WHERE category = 'Accessories')
    WHERE d.date BETWEEN '2021-01-01' AND '2021-03-31'
    GROUP BY d.date
    HAVING lines = 0
);
```

Verified output: **50** zero-Accessories-order days out of the 90 days in
Q1 2021.

</details>

---

### 5. Prove the gap-filling matters: INNER JOIN vs LEFT JOIN row counts

For the full 2021-01-01–2026-06-30 window, compute (a) the total number
of calendar days in `dim_date` for that range, and (b) the number of
*distinct* dates that appear via an `INNER JOIN` to `fact_sales` (i.e. no
date-spine gap-filling). Confirm the difference between (a) and (b)
equals the 54 zero-order days documented in the facts sheet.

<details>
<summary>Show solution</summary>

```sql
-- (a) total days in the window
SELECT COUNT(*) AS total_days
FROM dim_date WHERE date BETWEEN '2021-01-01' AND '2026-06-30';

-- (b) distinct days that show up via INNER JOIN (i.e. days with >=1 order)
SELECT COUNT(*) AS days_with_orders FROM (
    SELECT d.date
    FROM dim_date d
    JOIN fact_sales f ON f.datekey = d.datekey
    WHERE d.date BETWEEN '2021-01-01' AND '2026-06-30'
    GROUP BY d.date
);
```

Verified output:

| total_days |
|---|
| 2007 |

| days_with_orders |
|---|
| 1953 |

2007 − 1953 = **54**, exactly matching `agg_daily_sales`'s documented
zero-order-day count. Every one of those 54 days would silently
disappear from an `INNER JOIN`-based report instead of showing up as a
legitimate `0`.

</details>

---

<!-- nav -->
Curriculum: [7. The Date-Spine Pattern](../../curriculum/03-advanced/07-the-date-spine-pattern.md). Previous: [6. Time Intelligence](06-time-intelligence.md). Next: [8. Writing Your First Silver View](08-writing-your-first-silver-view.md).
<!-- /nav -->
