-- =============================================================================
-- PATTERN: Slowly Changing Dimension Type 2 (history tracking)
-- =============================================================================
-- PROBLEM
--   Sometimes overwriting a dimension attribute in place (Type 1) loses
--   information the business actually needs: "what was this employee's
--   department when the March order was placed?" can't be answered if
--   department was overwritten to its current value with no history. SCD
--   Type 2 solves this by inserting a NEW row for every version of an
--   entity, each with a validity window (valid_from/valid_to) and a
--   current-row flag, instead of updating the existing row in place. Fact
--   tables at the time of the historical event join to the dimension
--   version that was valid THEN, not the version that's valid now.
--
-- WHEN TO REACH FOR IT
--   - Attributes where "what was true at the time" matters for correct
--     historical reporting: an employee's department/region at the time
--     of a sale (for commission attribution), a product's price/category
--     at the time it was ordered, a customer's address at the time of
--     shipment.
--   - Specifically NOT for every attribute of a dimension -- SCD Type 2
--     roughly doubles (or more) the row count and adds real query
--     complexity (every fact join needs a date-range condition, not just
--     an equality). Apply it selectively to the columns that actually
--     need history, or accept it repo-wide only if the business
--     genuinely needs point-in-time accuracy everywhere.
--
-- HOW IT WORKS
--   Each entity gets one row per distinct version of its tracked
--   attributes, with:
--     - a surrogate key unique per ROW (not per entity -- this is exactly
--       why SCD Type 2 requires the surrogate-key pattern in
--       surrogate-key-generation.sql; the natural key alone can't be the
--       primary key anymore since it repeats across versions)
--     - valid_from / valid_to marking the date range that version was
--       accurate
--     - an is_current flag (1 for the live version, 0 for historical) as
--       a fast filter, so "give me the current dimension" doesn't need a
--       date-range scan
--   A fact table then joins on natural_key AND event_date BETWEEN
--   valid_from AND valid_to, to pick up the dimension version that was
--   true at the time of the fact event.
--
-- REAL EXAMPLE (Oakhaven)
--   This repo's dim_employee is currently Type 1 (one row per employee,
--   current state only) -- but bronze_employees.termination_date is
--   explicitly documented and seeded as "the SCD Type 2 hook for a later
--   lesson": ~15%-ish of employees (8 of 35 in this actual build) have a
--   termination_date strictly after hire_date, which is exactly the shape
--   of data SCD Type 2 exists to model -- an employment record with a
--   known start and (for some) a known end. The query below is a worked
--   conceptual SCD Type 2 shape built directly from silver_employees'
--   hire_date/termination_date, showing how you'd frame those two columns
--   as a validity window with an is_current flag, without altering the
--   real dim_employee.sql (which portfolio/ must not touch).
--
--   Verified against project/oakhaven.db:
--     8 of 35 employees have a non-NULL termination_date in this build.
--
-- SAMPLE OUTPUT (real data)
--   employee_id  hire_date   termination_date  is_current  valid_from  valid_to
--   3            2018-12-07  2021-05-01        0           2018-12-07  2021-05-01
--   6            2021-10-04  2024-01-09        0           2021-10-04  2024-01-09
--   8            2021-02-11  2023-03-15        0           2021-02-11  2023-03-15
--
-- PORTABILITY
--   The SELECT/CASE shape below (valid_from/valid_to/is_current as plain
--   derived columns) is standard SQL, identical everywhere. Where engines
--   differ is in how you'd implement the INSERT-a-new-version-on-change
--   step for a physically materialized SCD Type 2 table:
--     - SQLite / Postgres: typically two statements -- an UPDATE to close
--       out the previous current row (`SET valid_to = new_change_date,
--       is_current = 0 WHERE natural_key = ... AND is_current = 1`)
--       followed by an INSERT of the new version row. No native
--       "conditional insert-or-expire" primitive.
--     - Snowflake / Databricks (Delta Lake) / BigQuery: all three support
--       MERGE with multiple WHEN MATCHED / WHEN NOT MATCHED clauses,
--       which can express "close out the old row AND insert the new one"
--       more compactly, though it typically still takes two MERGE
--       statements or a MERGE + INSERT pair in practice for true SCD2 (a
--       single MERGE can't both UPDATE an existing row and INSERT a new
--       row for the same logical key in one pass on most engines).
--       Databricks' Delta Lake docs describe this exact two-step MERGE
--       pattern as the standard SCD Type 2 recipe.
--   The querying side (joining a fact to the dimension version valid at
--   the fact's event date) uses a BETWEEN or >= / < range comparison --
--   pure ANSI SQL, identical across all five engines.
-- =============================================================================

-- Worked conceptual SCD Type 2 shape, built from silver_employees'
-- hire_date/termination_date (NOT a change to the real dim_employee.sql,
-- which stays Type 1 -- this shows how you WOULD reframe it).
SELECT
    employee_id,
    hire_date,
    termination_date,
    CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END AS is_current,
    hire_date AS valid_from,
    COALESCE(termination_date, '9999-12-31') AS valid_to   -- open-ended sentinel for the current version
FROM silver_employees
WHERE employee_id IN (3, 6, 8, 12, 23)
ORDER BY employee_id;

-- How many employee "versions" (in this simplified single-attribute
-- sense -- employed vs. terminated) actually exist in this build:
SELECT
    SUM(CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END) AS current_employees,
    SUM(CASE WHEN termination_date IS NOT NULL THEN 1 ELSE 0 END) AS historical_terminated_employees
FROM silver_employees;
-- -> 27 current, 8 historical (this build)

-- Illustrative only (not executed against the shared oakhaven.db): the
-- fact-table join pattern that makes SCD Type 2 pay off -- picking the
-- dimension version valid AT THE TIME of the fact event, not the current
-- version. If dim_employee were extended to full SCD Type 2 with
-- (employee_sk, employee_id, department, valid_from, valid_to,
-- is_current) columns, a sale's commission attribution would join like:
--
-- SELECT f.order_id, f.net_amount, e.department AS department_at_time_of_sale
-- FROM fact_sales f
-- JOIN dim_employee_scd2 e
--   ON e.employee_id = f.employee_id
--  AND f.order_date >= e.valid_from
--  AND f.order_date <  e.valid_to
-- -- NOT: JOIN dim_employee e ON e.employee_id = f.employee_id
-- -- (that Type-1-style equality join would silently attribute every
-- -- historical sale to the employee's CURRENT department, which is
-- -- wrong the moment an employee has ever changed department.)
