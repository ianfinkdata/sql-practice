# Exercises: Recursive CTEs

<!-- nav -->
Curriculum: [5. Recursive CTEs](../../curriculum/03-advanced/05-recursive-ctes.md). Previous: [4. LEAD, LAG, and Period-over-Period Comparisons](04-lead-lag-period-over-period.md). Next: [6. Time Intelligence](06-time-intelligence.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Count to 10, the recursive way

Write a `WITH RECURSIVE` CTE that generates the integers 1 through 10, one
per row.

<details>
<summary>Show solution</summary>

```sql
WITH RECURSIVE nums(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 10
)
SELECT * FROM nums;
```

Verified output: `n` = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 (10 rows).

</details>

---

### 2. First-of-month dates for the second half of 2026

Write a `WITH RECURSIVE` CTE that generates the first day of each month
from July 2026 through December 2026 (6 rows), using `date(d, '+1
month')` as the step.

<details>
<summary>Show solution</summary>

```sql
WITH RECURSIVE month_starts(d) AS (
    SELECT date('2026-07-01')
    UNION ALL
    SELECT date(d, '+1 month') FROM month_starts WHERE d < date('2026-12-01')
)
SELECT d FROM month_starts;
```

Verified output:

| d |
|---|
| 2026-07-01 |
| 2026-08-01 |
| 2026-09-01 |
| 2026-10-01 |
| 2026-11-01 |
| 2026-12-01 |

</details>

---

### 3. Powers of 2

Write a `WITH RECURSIVE` CTE with two columns (`n`, `val`) that generates
powers of 2, starting at `n=1, val=2`, stopping once `val` would exceed
1024 (i.e. the last row should have `val = 1024`).

<details>
<summary>Show solution</summary>

```sql
WITH RECURSIVE powers(n, val) AS (
    SELECT 1, 2
    UNION ALL
    SELECT n + 1, val * 2 FROM powers WHERE val < 1024
)
SELECT n, val FROM powers;
```

Verified output: 10 rows, `n` 1 through 10, `val` doubling from 2 to 1024
(2, 4, 8, 16, 32, 64, 128, 256, 512, 1024).

</details>

---

### 4. Reproduce a slice of `bronze_calendar` from scratch

Without querying `bronze_calendar` itself, write a `WITH RECURSIVE` CTE
that generates the exact same 6 rows (`datekey`, `date`) that
`bronze/calendar_recursive_cte.sql`'s recursive CTE would produce for
2026-06-25 through 2026-06-30. Then confirm your output matches what's
actually stored in `bronze_calendar` for that range.

<details>
<summary>Show solution</summary>

```sql
WITH RECURSIVE dates(d) AS (
    SELECT date('2026-06-25')
    UNION ALL
    SELECT date(d, '+1 day')
    FROM dates
    WHERE d < date('2026-06-30')
)
SELECT CAST(strftime('%Y%m%d', d) AS INTEGER) AS datekey, d AS date FROM dates;
```

Verified output:

| datekey | date |
|---|---|
| 20260625 | 2026-06-25 |
| 20260626 | 2026-06-26 |
| 20260627 | 2026-06-27 |
| 20260628 | 2026-06-28 |
| 20260629 | 2026-06-29 |
| 20260630 | 2026-06-30 |

Confirm against the real table:

```sql
SELECT datekey, date FROM bronze_calendar WHERE date BETWEEN '2026-06-25' AND '2026-06-30';
```

Produces identical rows — the recursive CTE mechanism reproduces exactly
what built the table in the first place.

</details>

---

### 5. Prove the leap year is handled correctly

`bronze_calendar` was built by a recursive CTE stepping `+1 day` at a
time, never hardcoding month/year lengths. Confirm this handled 2024 (a
leap year) correctly by counting how many rows exist for `date LIKE
'2024%'` — it should be 366, not 365.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_calendar WHERE date LIKE '2024%';
```

Verified output: **366** — confirming 2024's leap day (2024-02-29) is
present. Because the recursive CTE always adds exactly one calendar day
via SQLite's `date(d, '+1 day')` (which itself correctly understands leap
years), there's no manual "is this a leap year" logic anywhere in
`calendar_recursive_cte.sql` — the date spine gets leap-year correctness
for free from SQLite's own date arithmetic.

</details>

---

<!-- nav -->
Curriculum: [5. Recursive CTEs](../../curriculum/03-advanced/05-recursive-ctes.md). Previous: [4. LEAD, LAG, and Period-over-Period Comparisons](04-lead-lag-period-over-period.md). Next: [6. Time Intelligence](06-time-intelligence.md).
<!-- /nav -->
