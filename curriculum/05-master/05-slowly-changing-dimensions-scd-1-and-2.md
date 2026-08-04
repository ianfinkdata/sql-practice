# 5. Slowly Changing Dimensions: Type 1 and Type 2


<!-- nav -->
Previous: [4. Designing a Dimension](04-designing-a-dimension.md). Next: [6. Designing the Date Dimension](06-designing-the-date-dimension.md).
<!-- /nav -->

## The idea

Dimensions don't stay still. A customer moves states. A product gets
re-categorized. An employee changes department, gets promoted, or
leaves the company. The question a **Slowly Changing Dimension (SCD)**
strategy answers is: *when a dimension row's attribute changes, what
happens to the history?*

There are two dominant strategies, and picking between them is a real
business decision, not a technical one:

**Type 1 — overwrite.** The dimension row is updated in place. The old
value is simply gone. If you re-run the query tomorrow, you'll never
know what the value used to be. This is the *default* behavior of any
dimension built as a plain `SELECT` over current source data — which
is exactly what all of Oakhaven's `dim_*` views currently do. Ask
`dim_employee` for an employee's department, and you get whatever
their *current* department is, with no way to recover what it was a
year ago through that view.

**Type 2 — historize.** Instead of overwriting, you *add a new row*
each time a tracked attribute changes, and keep the old row intact.
Each version of the dimension row gets an `effective_date`, an
`expiry_date` (or `NULL`/a far-future sentinel for the current
version), and usually an `is_current` flag. A fact table can then join
to the dimension row that was valid *at the time the fact happened*,
not just whatever's current today. This is strictly more powerful than
Type 1, at the cost of a bigger dimension table and more complex joins
(and it requires a surrogate key — module 2 — since the natural key,
like `employee_id`, now maps to *multiple* rows).

Type 1 is the right choice when history genuinely doesn't matter (a
corrected typo in a customer's phone number). Type 2 is the right
choice when history is the point (was this employee actually employed
here when this sale happened?).

## The real data hook: `bronze_employees.hire_date` / `termination_date`

Oakhaven doesn't have a dataset that tracks department changes over
time — `bronze_employees` only stores each employee's *current*
department, one value, no history. So you can't actually reconstruct
"Alexandria Cunningham was in Sales before she was in Management" from
this data; that's a real limitation worth stating plainly rather than
faking.

What Oakhaven *does* have, natively, is a genuinely Type-2-shaped
attribute: **employment status**. `hire_date` is an effective start
date, and `termination_date` is an effective end date (`NULL` meaning
"still current as of the snapshot date"). This isn't a hypothetical —
it's real data with a real effective/expiry structure already baked
in.

```sql
SELECT COUNT(*) AS total_employees,
       SUM(CASE WHEN termination_date IS NOT NULL THEN 1 ELSE 0 END) AS terminated,
       ROUND(100.0 * SUM(CASE WHEN termination_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_terminated
FROM dim_employee;
```

| total_employees | terminated | pct_terminated |
|---|---|---|
| 35 | 8 | 22.9 |

8 of Oakhaven's 35 employees (22.9%) have a populated
`termination_date` in this build. (`project/docs/data_dictionary.md`
describes the generation target as "~15%" — the actual count realized
by this specific random seed is 8/35, and that's the number to cite,
not the design target.)

```sql
SELECT employee_id, full_name, department, region, hire_date, termination_date
FROM dim_employee
WHERE termination_date IS NOT NULL
ORDER BY employee_id
LIMIT 5;
```

| employee_id | full_name | department | region | hire_date | termination_date |
|---|---|---|---|---|---|
| 3 | Alexandria Cunningham | Management | East | 2018-12-07 | 2021-05-01 |
| 6 | Christy Lee | Sales | West | 2021-10-04 | 2024-01-09 |
| 8 | Wendy Scott | Sales | East | 2021-02-11 | 2023-03-15 |
| 12 | Elaine Jones | Warehouse | East | 2022-07-07 | 2025-03-18 |
| 23 | Nicholas Campos | Management | West | 2024-10-19 | 2025-04-10 |

## Shaping an SCD Type 2 view of employment status (conceptual, verified — not persisted)

This is a `SELECT` that reshapes `dim_employee` into the standard SCD
Type 2 column vocabulary (`effective_date`, `expiry_date`,
`is_current`). It's a demonstration of the pattern, run directly
against the real view, not a new gold object added to `project/gold/`:

```sql
SELECT
    employee_id,
    full_name,
    department,
    region,
    hire_date  AS effective_date,
    COALESCE(termination_date, '9999-12-31') AS expiry_date,
    CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END AS is_current
FROM dim_employee
ORDER BY employee_id
LIMIT 6;
```

| employee_id | full_name | department | region | effective_date | expiry_date | is_current |
|---|---|---|---|---|---|---|
| 1 | Alexa Garcia | Management | West | 2024-04-09 | 9999-12-31 | 1 |
| 2 | Sandra Thompson | Warehouse | Northeast | 2018-05-25 | 9999-12-31 | 1 |
| 3 | Alexandria Cunningham | Management | East | 2018-12-07 | 2021-05-01 | 0 |
| 4 | Laura Williams | Support | East | 2020-05-28 | 9999-12-31 | 1 |
| 5 | Stephanie Reid | Warehouse | Central | 2023-08-10 | 9999-12-31 | 1 |
| 6 | Christy Lee | Sales | West | 2021-10-04 | 2024-01-09 | 0 |

`9999-12-31` is a common SCD Type 2 convention: a far-future sentinel
expiry date for the currently-active version, which makes "is this row
valid as of date X" a single uniform range check
(`effective_date <= X AND X < expiry_date`) instead of needing special
`NULL`-handling logic at query time.

## Why point-in-time matters: what a naive join gets wrong

Here's the payoff for thinking in Type 2 terms, even without a fully
built Type 2 dimension: it tells you when a *current-state* join is
misleading you. `fact_sales.employee_id` records which employee is
credited with a sale — but nothing about how `fact_sales` was built
checks whether that employee was actually employed on `order_date`.
Check directly:

```sql
SELECT f.order_id, f.order_date, f.employee_id, e.full_name, e.termination_date
FROM fact_sales f
JOIN dim_employee e ON f.employee_id = e.employee_id
WHERE e.termination_date IS NOT NULL
  AND f.order_date IS NOT NULL
  AND f.order_date > e.termination_date
ORDER BY f.order_date
LIMIT 5;
```

| order_id | order_date | employee_id | full_name | termination_date |
|---|---|---|---|---|
| 2228 | 2021-01-16 | 27 | Jack Cross | 2020-09-22 |
| 2228 | 2021-01-16 | 27 | Jack Cross | 2020-09-22 |
| 5503 | 2021-01-22 | 27 | Jack Cross | 2020-09-22 |
| 312 | 2021-01-31 | 27 | Jack Cross | 2020-09-22 |
| 312 | 2021-01-31 | 27 | Jack Cross | 2020-09-22 |

```sql
SELECT COUNT(*) AS orders_after_termination
FROM fact_sales f
JOIN dim_employee e ON f.employee_id = e.employee_id
WHERE e.termination_date IS NOT NULL
  AND f.order_date IS NOT NULL
  AND f.order_date > e.termination_date;
```

| orders_after_termination |
|---|---|
| 1214 |

1,214 order lines in `fact_sales` are attributed to an employee whose
`termination_date` (in the *current* dimension) is earlier than the
order's date. This isn't a documented, intentional data-quality flag
like `is_customer_orphan` — it's just what falls out of `employee_id`
being assigned to orders with no temporal correlation to hire/term
dates, which is itself realistic (plenty of real OLTP systems don't
enforce that kind of cross-table consistency either). The teaching
point is what it demonstrates: a plain `fact JOIN dim_employee ON
employee_id` always shows you the employee's **current** record,
regardless of whether that record was even valid on the date the fact
occurred. A true SCD Type 2 `dim_employee`, joined on a
`BETWEEN effective_date AND expiry_date` condition against
`order_date` instead of a bare `employee_id` equality join, is what
protects you from this exact class of mistake.

## Common mistakes

- **Calling something "Type 2" when it still just overwrites.** Adding
  an `effective_date` column to a table that still gets updated in
  place isn't Type 2 — the old row must be preserved, not touched.
- **Forgetting to point historical facts at the version valid at the
  time.** Joining a fact table to "whichever dimension row currently
  has this natural key" instead of "whichever dimension row was valid
  on this fact's date" silently reintroduces Type 1 behavior even on
  top of a properly built Type 2 table.
- **Using `NULL` for "currently active" expiry dates and forgetting to
  handle it.** A range check like `effective_date <= X AND X <
  expiry_date` silently fails for `NULL` expiry in most SQL engines
  (`X < NULL` is never true) — either use a sentinel far-future date or
  explicitly `OR expiry_date IS NULL` everywhere.
- **Building a Type 2 dimension for an attribute you don't have change
  history for.** You cannot retroactively reconstruct department
  history for Oakhaven's employees — the source data only ever
  recorded the current value. Type 2 requires either a system that
  already captures changes, or an audit/event log to build it from.
  Don't invent history a dataset doesn't have.

## Key takeaways

- **Type 1** overwrites in place — no history. It's what every
  `dim_*` view in Oakhaven's gold layer currently does implicitly,
  since each is a plain `SELECT` over the current source state.
- **Type 2** preserves history via new rows per change, tracked with
  `effective_date` / `expiry_date` / `is_current`, and requires a
  surrogate key because the natural key now maps to multiple rows.
- `bronze_employees.hire_date` / `termination_date` is real,
  already-Type-2-shaped data for the "employment status" attribute — 8
  of 35 employees (22.9%) have a populated `termination_date` in this
  build.
- A naive `fact JOIN dim_employee` shows the employee's *current*
  state regardless of whether it was valid at the fact's date — proven
  by 1,214 order lines in Oakhaven attributed to employees whose
  current record shows a termination date before the order.
- You can't fabricate Type 2 history for attributes your source system
  never tracked changes for (like department) — be honest about what
  a dataset can and can't support.

---

<!-- nav -->
Previous: [4. Designing a Dimension](04-designing-a-dimension.md). Next: [6. Designing the Date Dimension](06-designing-the-date-dimension.md).
<!-- /nav -->
