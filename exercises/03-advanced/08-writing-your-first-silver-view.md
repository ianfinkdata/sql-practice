# Exercises: Writing Your First Silver View

<!-- nav -->
Curriculum: [8. Writing Your First Silver View](../../curriculum/03-advanced/08-writing-your-first-silver-view.md). Previous: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md). Next: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run these as plain
`SELECT` statements — **never** run `CREATE VIEW`, `DROP`, or any DDL
against the shared `oakhaven.db`. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

---

### 1. Normalize `bronze_employees.department`

Write a `SELECT` that shows every distinct raw `department` value from
`bronze_employees` alongside its normalized canonical form (`Sales`,
`Support`, `Warehouse`, `Management`), using the
`LOWER(TRIM(...))`-key-then-`CASE` pattern from `silver_customers.sql`'s
`customer_segment` cleaning.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT department AS raw_department,
       CASE LOWER(TRIM(department))
           WHEN 'sales' THEN 'Sales'
           WHEN 'support' THEN 'Support'
           WHEN 'warehouse' THEN 'Warehouse'
           WHEN 'management' THEN 'Management'
           ELSE NULL
       END AS clean_department
FROM bronze_employees
ORDER BY raw_department;
```

Verified output (11 distinct raw variants, all correctly mapped):

| raw_department | clean_department |
|---|---|
| MANAGEMENT | Management |
| Management | Management |
| SUPPORT | Support |
| Sales | Sales |
| Support | Support |
| WAREHOUSE | Warehouse |
| Warehouse | Warehouse |
| management | Management |
| sales | Sales |
| support | Support |
| warehouse | Warehouse |

</details>

---

### 2. Normalize `bronze_employees.region`

Same idea, for `region` (canonical forms: `West`, `East`, `Central`,
`South`, `Northeast`).

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT region AS raw_region,
       CASE LOWER(TRIM(region))
           WHEN 'west' THEN 'West'
           WHEN 'east' THEN 'East'
           WHEN 'central' THEN 'Central'
           WHEN 'south' THEN 'South'
           WHEN 'northeast' THEN 'Northeast'
           ELSE NULL
       END AS clean_region
FROM bronze_employees
ORDER BY raw_region;
```

Verified output (14 distinct raw variants):

| raw_region | clean_region |
|---|---|
| CENTRAL | Central |
| Central | Central |
| EAST | East |
| East | East |
| NORTHEAST | Northeast |
| Northeast | Northeast |
| SOUTH | South |
| South | South |
| WEST | West |
| West | West |
| central | Central |
| east | East |
| south | South |
| west | West |

</details>

---

### 3. Combine both, prove full coverage

Write one `SELECT` over `bronze_employees` (all 35 rows) that produces
both `clean_department` and `clean_region` side by side, then a second
query that counts how many rows end up with a `NULL` `clean_department`
(there should be zero — every raw value should be covered by your
`CASE`).

<details>
<summary>Show solution</summary>

```sql
SELECT e.employee_id,
       e.department AS raw_department,
       CASE LOWER(TRIM(e.department))
           WHEN 'sales' THEN 'Sales' WHEN 'support' THEN 'Support'
           WHEN 'warehouse' THEN 'Warehouse' WHEN 'management' THEN 'Management'
           ELSE NULL
       END AS clean_department,
       e.region AS raw_region,
       CASE LOWER(TRIM(e.region))
           WHEN 'west' THEN 'West' WHEN 'east' THEN 'East'
           WHEN 'central' THEN 'Central' WHEN 'south' THEN 'South'
           WHEN 'northeast' THEN 'Northeast'
           ELSE NULL
       END AS clean_region
FROM bronze_employees e
ORDER BY e.employee_id
LIMIT 8;
```

Verified output (first 8 rows):

| employee_id | raw_department | clean_department | raw_region | clean_region |
|---|---|---|---|---|
| 1 | Management | Management | West | West |
| 2 | WAREHOUSE | Warehouse | NORTHEAST | Northeast |
| 3 | management | Management | East | East |
| 4 | Support | Support | EAST | East |
| 5 | Warehouse | Warehouse | CENTRAL | Central |
| 6 | Sales | Sales | West | West |
| 7 | Management | Management | South | South |
| 8 | Sales | Sales | EAST | East |

Coverage check:

```sql
SELECT COUNT(*) AS unmapped
FROM bronze_employees e
WHERE CASE LOWER(TRIM(e.department))
           WHEN 'sales' THEN 'Sales' WHEN 'support' THEN 'Support'
           WHEN 'warehouse' THEN 'Warehouse' WHEN 'management' THEN 'Management'
           ELSE NULL END IS NULL;
```

Verified output: **0** — every one of the 35 employees' `department`
values is covered by the `CASE`.

</details>

---

### 4. Clean a dirty-TEXT-to-REAL column

`bronze_products.weight_kg` has the same problem as
`bronze_customers.phone` conceptually (a `TEXT` column masking a real
underlying value) but a different shape: values like `"1.2"`, `"1.2 kg"`,
or `NULL`. Write a `SELECT` that parses it to a clean `REAL` — strip a
trailing `" kg"` suffix if present, then `CAST` to `REAL`. Show 5 rows
where the raw value had the `" kg"` suffix, to prove the stripping worked.

<details>
<summary>Show solution</summary>

```sql
SELECT product_id, weight_kg AS raw_weight,
       CASE
           WHEN weight_kg IS NULL THEN NULL
           WHEN weight_kg LIKE '% kg' THEN CAST(TRIM(REPLACE(weight_kg, ' kg', '')) AS REAL)
           ELSE CAST(weight_kg AS REAL)
       END AS clean_weight_kg
FROM bronze_products
WHERE weight_kg LIKE '% kg'
LIMIT 5;
```

Verified output:

| product_id | raw_weight | clean_weight_kg |
|---|---|---|
| 1 | 24.7 kg | 24.7 |
| 3 | 3.43 kg | 3.43 |
| 4 | 18.5 kg | 18.5 |
| 8 | 7.4 kg | 7.4 |
| 18 | 19.7 kg | 19.7 |

(This is, not coincidentally, exactly the technique `silver_products.sql`
actually uses for this column — write it yourself first, then compare.)

</details>

---

### 5. Design question — why not delete the unmapped rows?

Suppose your `CASE` in Exercise 1 or 2 *did* produce a `NULL` for some
unanticipated raw value (say a typo `"Slaes"` slipped into the data).
Would it be acceptable for your cleaning query to silently `WHERE
clean_department IS NOT NULL` and drop that row? Write 2–3 sentences
explaining your answer in terms of the silver-layer contract described in
this module's curriculum lesson.

<details>
<summary>Show solution</summary>

No — dropping the row would violate silver's core contract: clean and
standardize, but never delete rows or silently hide problems you can't
resolve. A silver view should still return that row, with
`clean_department = NULL` and `raw_department` (or the original column)
still visible, so a downstream consumer can see there's an unmapped value
and decide how to handle it — flag it for review, fix the mapping, or
escalate to whoever owns the source data. `silver_customers.sql`
demonstrates exactly this discipline with its `is_active` cleaning: an
unrecognized value falls through to `ELSE NULL`, not a default guess and
not a dropped row.

</details>

---

<!-- nav -->
Curriculum: [8. Writing Your First Silver View](../../curriculum/03-advanced/08-writing-your-first-silver-view.md). Previous: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md). Next: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md).
<!-- /nav -->
