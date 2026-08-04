# Exercises: Time Intelligence

<!-- nav -->
Curriculum: [6. Time Intelligence](../../curriculum/03-advanced/06-time-intelligence.md). Previous: [5. Recursive CTEs](05-recursive-ctes.md). Next: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Compute quarter without `dim_date`

Without joining to `dim_date`, compute the calendar quarter for each of
the first 5 non-null `order_date` rows in `fact_sales`, using
`strftime()` and the `((month - 1) / 3) + 1` formula.

<details>
<summary>Show solution</summary>

```sql
SELECT order_id, order_date,
       ((CAST(strftime('%m', order_date) AS INTEGER) - 1) / 3) + 1 AS quarter
FROM fact_sales
WHERE order_date IS NOT NULL
LIMIT 5;
```

Verified output:

| order_id | order_date | quarter |
|---|---|---|
| 1 | 2024-03-05 | 1 |
| 1 | 2024-03-05 | 1 |
| 2 | 2021-11-04 | 4 |
| 2 | 2021-11-04 | 4 |
| 3 | 2023-01-13 | 1 |

</details>

---

### 2. Weekend signups

Count how many `silver_customers` rows have a `signup_date` that fell on
a Saturday or Sunday (`strftime('%w', ...)` in `(0, 6)`).

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS weekend_signups
FROM silver_customers
WHERE signup_date IS NOT NULL
  AND CAST(strftime('%w', signup_date) AS INTEGER) IN (0, 6);
```

Verified output: **168** weekend signups.

</details>

---

### 3. Average days to ship

Using `julianday()`, compute the average number of days between
`order_date` and `ship_date` across all of `silver_sales` (where both are
non-null).

<details>
<summary>Show solution</summary>

```sql
SELECT ROUND(AVG(julianday(ship_date) - julianday(order_date)), 2) AS avg_days_to_ship
FROM silver_sales
WHERE ship_date IS NOT NULL AND order_date IS NOT NULL;
```

Verified output: **4.89** days average. (This average is pulled down
slightly by the ~1.8% of orders where `ship_date` is chronologically
*before* `order_date` — the intentional bad-data rows discussed in the
curriculum module — since those contribute negative values to the
average.)

</details>

---

### 4. Employee tenure in years

For every employee with a non-null `hire_date`, compute their tenure in
years: from `hire_date` to `termination_date` if they've left, or to
2026-06-30 (Oakhaven's snapshot date) if `termination_date` is `NULL`
(still employed). Use `julianday()` and divide by 365.25 to account for
leap years. Show the 5 longest-tenured employees.

<details>
<summary>Show solution</summary>

```sql
SELECT employee_id, first_name, last_name, hire_date, termination_date,
       ROUND((julianday(COALESCE(termination_date, '2026-06-30')) - julianday(hire_date)) / 365.25, 1)
           AS tenure_years
FROM silver_employees
WHERE hire_date IS NOT NULL
ORDER BY tenure_years DESC
LIMIT 5;
```

Verified output:

| employee_id | first_name | last_name | hire_date | termination_date | tenure_years |
|---|---|---|---|---|---|
| 2 | Sandra | Thompson | 2018-05-25 | *(null)* | 8.1 |
| 19 | Keith | Hunt | 2018-07-14 | *(null)* | 8.0 |
| 21 | Ashlee | Hall | 2018-09-16 | *(null)* | 7.8 |
| 32 | Matthew | Payne | 2018-09-02 | *(null)* | 7.8 |
| 22 | Robert | Anderson | 2018-11-20 | *(null)* | 7.6 |

The `COALESCE(termination_date, '2026-06-30')` trick is the key idea here:
it treats "still employed" the same as "employed through the snapshot
date" for the purposes of a tenure calculation, without needing a separate
`CASE` branch.

</details>

---

### 5. Find the bad-data ship dates yourself

Using `julianday()`, write a query that finds every `silver_sales` row
where `ship_date` is chronologically before `order_date` (the intentional
bad-data pattern documented in the data dictionary). Confirm your count
matches the facts sheet's documented figure of 216.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS bad_ship_date_rows
FROM silver_sales
WHERE ship_date IS NOT NULL AND order_date IS NOT NULL
  AND julianday(ship_date) < julianday(order_date);
```

Verified output: **216** — matches the facts sheet exactly.

</details>

---

<!-- nav -->
Curriculum: [6. Time Intelligence](../../curriculum/03-advanced/06-time-intelligence.md). Previous: [5. Recursive CTEs](05-recursive-ctes.md). Next: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md).
<!-- /nav -->
