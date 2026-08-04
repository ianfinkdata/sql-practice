# Exercises: DDL Basics and Type Affinity

Exercises 1 and 4–5 are read-only (query the shared `project/oakhaven.db`
directly). Exercises 2, 3, and 6 create/modify tables — work against
your own scratch copy for those:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Read the real schema

Using `PRAGMA table_info`, list every column name and declared type
for `bronze_employees`. Which columns store dates, and what declared
type are they — `DATE`, or something else? What does that tell you
about how SQLite represents dates?

<details>
<summary>Show solution</summary>

```sql
PRAGMA table_info(bronze_employees);
```

```
0|employee_id|INTEGER|0||0
1|first_name|TEXT|0||0
2|last_name|TEXT|0||0
3|department|TEXT|0||0
4|region|TEXT|0||0
5|hire_date|TEXT|0||0
6|termination_date|TEXT|0||0
7|is_manager|TEXT|0||0
8|email|TEXT|0||0
```

`hire_date` and `termination_date` are both `TEXT`, not `DATE` —
SQLite has no native date/datetime storage class. Dates are just
strings, interpreted as dates only when a date function like
`strftime()` or `date()` is applied to them. This is also *why*
bronze can get away with storing dates in three different formats
(`YYYY-MM-DD`, `MM/DD/YYYY`, `YYYY-MM-DD HH:MM:SS`) — nothing at the
storage layer distinguishes a valid date string from any other text.

</details>

---

### 2. Watch affinity coerce values on insert

On your scratch copy, create a table with one column of each of three
declared types — `INTEGER`, `TEXT`, and `VARCHAR(10)` — then insert a
single row where each value's *actual* type doesn't match its
column's declared type (a numeric string into the `INTEGER` column, a
number into the `TEXT` column, a number into `VARCHAR(10)`). Use
`typeof()` to see what actually got stored in each column.

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_affinity (a INTEGER, b TEXT, c VARCHAR(10));
INSERT INTO ex_affinity VALUES ('42', 99, 100);
SELECT a, typeof(a), b, typeof(b), c, typeof(c) FROM ex_affinity;
```

```
a   typeof(a)  b   typeof(b)  c    typeof(c)
--  ---------  --  ---------  ---  ---------
42  integer    99  text       100  text
```

- Column `a` (`INTEGER` affinity) received the *string* `'42'`, and
  converted it to a real integer — `typeof(a)` reports `integer`.
- Column `b` (`TEXT` affinity) received the *number* `99`, and
  converted it to the string `'99'` — `typeof(b)` reports `text`.
- Column `c` (`VARCHAR(10)` — note this still gets `TEXT` affinity,
  since SQLite's affinity rules only look for the substrings `CHAR`,
  `CLOB`, or `TEXT` anywhere in the declared type, and `VARCHAR`
  contains `CHAR`) behaves identically to `b`: the number `100`
  became the string `'100'`.

</details>

---

### 3. Break `NUMERIC` affinity on purpose

`NUMERIC` affinity tries to convert text to a number, but only when
the text is losslessly convertible. On your scratch copy, create a
table with one `NUMERIC` column and insert two rows: one with a value
that converts cleanly (e.g. `'7'`), and one with a value that can't be
converted losslessly (e.g. `'7 apples'`). What does `typeof()` report
for each?

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_numeric (val NUMERIC);
INSERT INTO ex_numeric VALUES ('7'), ('7 apples');
SELECT val, typeof(val) FROM ex_numeric;
```

```
val       typeof(val)
--------  -----------
7         integer
7 apples  text
```

`'7'` converts cleanly to the integer `7`. `'7 apples'` cannot be
losslessly converted back to the exact same text from a number, so
`NUMERIC` affinity leaves it stored as `TEXT`, unchanged — no error,
no rejection, just a silent fallback to storing it as-is.

</details>

---

### 4. Why is `bronze_products.weight_kg` `TEXT`, not `REAL`?

Query `bronze_products` for a handful of distinct `weight_kg` values
that include the literal `" kg"` suffix. Explain, in one or two
sentences, why declaring this column `REAL` at generation time
wouldn't have worked for these particular values.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT weight_kg
FROM bronze_products
WHERE weight_kg LIKE '% kg'
LIMIT 5;
```

```
24.7 kg
3.43 kg
18.5 kg
7.4 kg
19.7 kg
```

Values like `"24.7 kg"` are not valid numeric literals — they're a
number followed by a unit suffix. A `REAL`-affinity column would try
to coerce this text to a float and, since it can't be losslessly
converted (see Exercise 3's `NUMERIC` behavior — `REAL` affinity works
the same way), it would be stored unchanged as `TEXT` anyway — or, in
engines with rigid typing, rejected outright at insert time. Declaring
the column `TEXT` from the start is honest about the fact that the raw
data isn't uniformly numeric; `silver_products.sql`'s `CASE` expression
is what actually strips the `" kg"` suffix and produces a clean `REAL`.

</details>

---

### 5. `CAST` doesn't fail the way you might expect

Run `SELECT CAST('1.2 kg' AS REAL);` directly (read-only, no writes
needed). What value comes back? Is this a rejection, a `NULL`, or
something else — and what does that tell you about relying on `CAST`
to validate data rather than to convert it?

<details>
<summary>Show solution</summary>

```sql
SELECT CAST('1.2 kg' AS REAL) AS cast_result, typeof(CAST('1.2 kg' AS REAL));
```

```
cast_result  typeof(...)
-----------  -----------
1.2          real
```

`CAST` doesn't fail or return `NULL` here — it silently parses as much
of a valid numeric prefix as it can (`"1.2"`) and discards the rest
(`" kg"`), returning `1.2` as a real `REAL`. This is exactly why
`silver_products.sql` doesn't rely on a bare `CAST(weight_kg_raw AS
REAL)` for every row — it explicitly checks `LIKE '% kg'` first and
strips the suffix, rather than trusting `CAST`'s permissive
best-effort parsing to always do the right thing. `CAST` is a
conversion tool, not a validation tool — it will very often give you
*a* number back even from input that shouldn't be considered valid.

</details>

---

### 6. Design a "properly typed" products table, then find where it would still lie to you

On your scratch copy, create a `demo_products` table with `unit_cost`
and `unit_price` declared `REAL`, and `weight_kg` declared `REAL` too
(unlike bronze's `TEXT`). Insert one row using a real `bronze_products`
row's `unit_cost` (pick any negative one — the facts sheet says ~1.3%
of products have a negative `unit_cost`, a deliberate data-entry
error). Does the `REAL` affinity column stop you from inserting a
negative cost? What kind of constraint (from Module 7) would be needed
to actually prevent it?

<details>
<summary>Show solution</summary>

```sql
SELECT product_id, unit_cost FROM bronze_products WHERE unit_cost < 0;
```

```
product_id  unit_cost
----------  ---------
19          -4.19
30          -131.94
```

Matches the facts sheet exactly: 2 rows with negative `unit_cost`.

```sql
CREATE TABLE demo_products (unit_cost REAL, unit_price REAL, weight_kg REAL);
INSERT INTO demo_products (unit_cost, unit_price, weight_kg) VALUES (-4.19, 24.99, 1.2);
SELECT * FROM demo_products;
```

```
unit_cost  unit_price  weight_kg
---------  ----------  ---------
-4.19      24.99       1.2
```

The insert succeeds without complaint — `REAL` affinity only cares
that the value *is* a number, not whether it's a *sensible* number.
Nothing about declaring a column `REAL` (or any other type) stops a
negative cost from being stored. Preventing this requires a `CHECK`
constraint, e.g. `unit_cost REAL CHECK (unit_cost >= 0 OR unit_cost IS
NULL)` — see Module 7 for exactly this kind of business-rule
enforcement, demonstrated against the real orphan-FK problem in
`bronze_sales`.

</details>
