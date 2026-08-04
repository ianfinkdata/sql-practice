# Exercises: 5. Slowly Changing Dimensions: Type 1 and Type 2

<!-- nav -->
Curriculum: [5. Slowly Changing Dimensions: Type 1 and Type 2](../../curriculum/05-master/05-slowly-changing-dimensions-scd-1-and-2.md). Previous: [4. Designing a Dimension](04-designing-a-dimension.md). Next: [6. Designing the Date Dimension](06-designing-the-date-dimension.md).
<!-- /nav -->

Work against `project/oakhaven.db`. Read-only — every query below is a
`SELECT`. None of these persist a new table or view; they're all
demonstrations of the SCD Type 2 shape, run directly as queries.

---

### 1. Verify the termination rate yourself

Confirm how many of Oakhaven's 35 employees have a populated
`termination_date`, and what percentage that is.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS total_employees,
       SUM(CASE WHEN termination_date IS NOT NULL THEN 1 ELSE 0 END) AS terminated,
       ROUND(100.0 * SUM(CASE WHEN termination_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_terminated
FROM dim_employee;
```

| total_employees | terminated | pct_terminated |
|---|---|---|
| 35 | 8 | 22.9 |

8 of 35 employees (22.9%) have left the company as of the snapshot
date — this is the real, seed-specific number to cite (the data
dictionary's "~15%" is a generation *target*, not the realized count).

</details>

---

### 2. Compare tenure length: active vs. terminated employees

For each employment status (`active` = `termination_date IS NULL`,
`terminated` = otherwise), compute the average tenure in days —
`hire_date` to either `termination_date` or the snapshot date
(`2026-06-30`) for still-active employees.

<details>
<summary>Show solution</summary>

```sql
SELECT
    CASE WHEN termination_date IS NULL THEN 'active' ELSE 'terminated' END AS status,
    COUNT(*) AS n,
    ROUND(AVG(julianday(COALESCE(termination_date, '2026-06-30')) - julianday(hire_date)), 1) AS avg_tenure_days
FROM dim_employee
GROUP BY status;
```

| status | n | avg_tenure_days |
|---|---|---|
| active | 27 | 1650.9 |
| terminated | 8 | 689.3 |

Active employees average about 4.5 years of tenure so far (and
counting — their "current" span is still open); terminated employees
averaged about 1.9 years before leaving. This is a direct payoff of
treating `hire_date`/`termination_date` as an effective/expiry pair,
rather than just checking `termination_date IS NULL` as a flat
boolean: you get a genuine duration measure out of it, computed the
same way SCD Type 2 tooling would compute "how long was this version
of the row valid."

</details>

---

### 3. Build the full SCD Type 2 shaping query

Reshape all 35 rows of `dim_employee` into the standard SCD Type 2
column vocabulary: `effective_date`, `expiry_date` (using `9999-12-31`
as the sentinel for currently-active employees), and `is_current`.
Order by `employee_id`.

<details>
<summary>Show solution</summary>

```sql
SELECT
    employee_id,
    full_name,
    department,
    hire_date AS effective_date,
    COALESCE(termination_date, '9999-12-31') AS expiry_date,
    CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END AS is_current
FROM dim_employee
ORDER BY employee_id
LIMIT 6;
```

| employee_id | full_name | department | effective_date | expiry_date | is_current |
|---|---|---|---|---|---|
| 1 | Alexa Garcia | Management | 2024-04-09 | 9999-12-31 | 1 |
| 2 | Sandra Thompson | Warehouse | 2018-05-25 | 9999-12-31 | 1 |
| 3 | Alexandria Cunningham | Management | 2018-12-07 | 2021-05-01 | 0 |
| 4 | Laura Williams | Support | 2020-05-28 | 9999-12-31 | 1 |
| 5 | Stephanie Reid | Warehouse | 2023-08-10 | 9999-12-31 | 1 |
| 6 | Christy Lee | Sales | 2021-10-04 | 2024-01-09 | 0 |

This is the pattern any real SCD Type 2 dimension follows, applied
here to the one attribute Oakhaven's data actually supports historizing:
employment status. `is_current = 1` marks the version valid right now;
`expiry_date` marks when a version stopped (or would stop) being
valid.

</details>

---

### 4. Naive equality join vs. a point-in-time-correct join

Join `fact_sales` to `dim_employee` two ways: (a) the naive way, on
`employee_id` alone, and (b) the point-in-time-correct way, additionally
requiring `f.order_date` to fall between the employee's `hire_date`
and `termination_date` (or `9999-12-31` if still active). Compare the
row counts.

<details>
<summary>Show solution</summary>

```sql
-- (a) naive: employee_id equality only
SELECT COUNT(*) AS naive_join_lines
FROM fact_sales f
JOIN dim_employee e ON f.employee_id = e.employee_id;
```

| naive_join_lines |
|---|
| 10757 |

```sql
-- (b) point-in-time-correct: order_date must fall within the employee's tenure
SELECT COUNT(*) AS point_in_time_valid_lines
FROM fact_sales f
JOIN dim_employee e ON f.employee_id = e.employee_id
WHERE f.order_date >= e.hire_date
  AND f.order_date <= COALESCE(e.termination_date, '9999-12-31');
```

| point_in_time_valid_lines |
|---|
| 6379 |

Only 6,379 of the 10,757 naively-joined order lines (about 59%) are
actually attributed to an employee during a period when that employee
was genuinely employed at Oakhaven. The other ~41% are order lines
where `employee_id` matches, but the order happened either before the
employee was hired or after they left — invisible in a plain equality
join, and only surfaced by treating `hire_date`/`termination_date` as
the effective/expiry window they actually represent.

</details>

---

### 5. Find the worst offenders

For each terminated employee, compute what percentage of their
attributed `fact_sales` order lines fall *after* their
`termination_date`. Show the 5 employees with the highest percentage.

<details>
<summary>Show solution</summary>

```sql
SELECT e.employee_id, e.full_name, e.termination_date,
       COUNT(*) AS total_lines,
       SUM(CASE WHEN f.order_date > e.termination_date THEN 1 ELSE 0 END) AS lines_after_term,
       ROUND(100.0 * SUM(CASE WHEN f.order_date > e.termination_date THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_after_term
FROM fact_sales f
JOIN dim_employee e ON f.employee_id = e.employee_id
WHERE e.termination_date IS NOT NULL AND f.order_date IS NOT NULL
GROUP BY e.employee_id
ORDER BY pct_after_term DESC
LIMIT 5;
```

| employee_id | full_name | termination_date | total_lines | lines_after_term | pct_after_term |
|---|---|---|---|---|---|
| 27 | Jack Cross | 2020-09-22 | 283 | 283 | 100.0 |
| 3 | Alexandria Cunningham | 2021-05-01 | 300 | 278 | 92.7 |
| 8 | Wendy Scott | 2023-03-15 | 291 | 190 | 65.3 |
| 25 | Brian Ray | 2023-02-02 | 268 | 170 | 63.4 |
| 6 | Christy Lee | 2024-01-09 | 315 | 142 | 45.1 |

Jack Cross is the extreme case: **100%** of the 283 order lines
attributed to `employee_id = 27` occurred after his recorded
termination date of 2020-09-22 — meaning a naive current-state join
would credit an ex-employee with every single one of his sales, with
no signal anything is wrong, because the equality join on `employee_id`
succeeds regardless of dates. This is precisely the failure mode SCD
Type 2 modeling exists to prevent: a fact should join to the dimension
row (or, informally here, the dimension *state*) that was valid at the
time the fact happened, not whichever row currently shares the natural
key.

</details>

---

<!-- nav -->
Curriculum: [5. Slowly Changing Dimensions: Type 1 and Type 2](../../curriculum/05-master/05-slowly-changing-dimensions-scd-1-and-2.md). Previous: [4. Designing a Dimension](04-designing-a-dimension.md). Next: [6. Designing the Date Dimension](06-designing-the-date-dimension.md).
<!-- /nav -->
