# Oracle SQL Cheat Sheet

> Target: **Oracle Database 19c+** (notes call out 23ai where it changes things).

Oracle is the enterprise OLTP heavyweight: decades of features, rock-solid
transactions, and a deep procedural language (**PL/SQL**) wrapped around the SQL
engine. If you're working in a bank, a telco, or a large ERP, you're probably on
Oracle. It is also the most "different" of the four dialects in small ways — the
ones below are what trip people up.

← Back to the [reference matrix](reference-matrix.md) ·
[Decoder home](README.md)

---

## Identity & quoting quirks

- **Unquoted identifiers fold to UPPERCASE.** `select id from emp` and `EMP` and
  `"EMP"` all hit the same table; `"emp"` (quoted lowercase) does **not**.
  Easiest life: never quote, use `snake_case`.
- **No `LIMIT`** before 23ai. Use `FETCH FIRST n ROWS ONLY` (12c+) or `ROWNUM`.
- **The `dual` table.** Every value-only `SELECT` needs a `FROM`, so Oracle ships
  a one-row dummy table: `SELECT SYSDATE FROM dual;`.
- **Empty string is NULL.** `'' IS NULL` is true. This is unique to Oracle among
  the four and quietly breaks comparisons.

---

## Signature functions

| Function | What it does |
|----------|--------------|
| `NVL(a,b)` | Two-arg null fallback (`COALESCE` also works and is portable). |
| `NVL2(a, x, y)` | `x` if `a` is not null, else `y`. |
| `DECODE(x, v1, r1, v2, r2, default)` | Compact value mapping; predates `CASE`. |
| `LISTAGG(col, sep) WITHIN GROUP (ORDER BY ...)` | Concatenate grouped rows into one string. |
| `ADD_MONTHS(d, n)` / `MONTHS_BETWEEN(a,b)` | Month-accurate date math. |
| `TO_CHAR` / `TO_DATE` / `TO_NUMBER` | Explicit conversion with format masks. |
| `INSTR` / `SUBSTR` | Position and substring. |
| `REGEXP_LIKE` / `REGEXP_SUBSTR` / `REGEXP_REPLACE` | Regex. |
| `ROWNUM` / `ROWID` | Pseudo-columns: sequence of returned rows; physical address. |
| sequences (`s.NEXTVAL`, `s.CURRVAL`) | Standalone number generators. |

---

## Limiting rows

```sql
-- Top 10 (12c+, preferred)
SELECT * FROM orders ORDER BY amount DESC FETCH FIRST 10 ROWS ONLY;

-- Pagination
SELECT * FROM orders ORDER BY id OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY;

-- Old-school (pre-12c): rank in a subquery, THEN filter ROWNUM
SELECT * FROM (
  SELECT o.*, ROWNUM rn FROM (SELECT * FROM orders ORDER BY amount DESC) o
) WHERE rn <= 10;
```

> `WHERE ROWNUM <= 10 ORDER BY amount` is a classic bug — `ROWNUM` is assigned
> *before* the sort. Always sort in a subquery first.

---

## Strings

```sql
SELECT first_name || ' ' || last_name AS full_name,   -- || is concat
       UPPER(email),
       SUBSTR(phone, 1, 3),
       LENGTH(name),
       INSTR(email, '@'),
       REPLACE(code, '-', ''),
       REGEXP_SUBSTR(csv, '[^,]+', 1, 2)               -- 2nd CSV field
FROM   customers;
```

No native string-split into a collection; reach for `REGEXP_SUBSTR` or a
hierarchical `CONNECT BY` trick.

---

## Dates

Oracle `DATE` **includes a time component** (to the second). Use `TIMESTAMP` for
fractional seconds and `TRUNC` to drop the time.

```sql
SELECT SYSDATE,                              -- now (DATE, with time)
       SYSTIMESTAMP,                         -- now with fractional sec + TZ
       TRUNC(SYSDATE)              AS today,
       hire_date + 7               AS plus_week,
       ADD_MONTHS(hire_date, 3)    AS plus_quarter,
       TRUNC(hire_date, 'MM')      AS month_start,
       MONTHS_BETWEEN(SYSDATE, hire_date) AS tenure_months,
       TO_CHAR(hire_date, 'YYYY-MM-DD')   AS iso,
       TO_DATE('2026-06-17', 'YYYY-MM-DD') AS parsed
FROM   employees;
```

Format masks are **capitalized** (`YYYY-MM-DD HH24:MI:SS`).

---

## NULL & conditional

```sql
SELECT NVL(commission, 0),
       NVL2(manager_id, 'has boss', 'top'),
       COALESCE(nickname, first_name, 'unknown'),    -- portable, preferred
       DECODE(status, 'A', 'Active', 'I', 'Inactive', 'Other'),
       CASE WHEN salary > 100000 THEN 'high' ELSE 'normal' END
FROM   employees;
```

There is **no `IF()` function** in Oracle SQL — use `CASE` or `DECODE`.

---

## Upsert (MERGE)

```sql
MERGE INTO target t
USING source s ON (t.id = s.id)
WHEN MATCHED THEN
  UPDATE SET t.val = s.val
WHEN NOT MATCHED THEN
  INSERT (id, val) VALUES (s.id, s.val);
```

---

## JSON

```sql
SELECT JSON_VALUE(doc, '$.customer.name')  AS name,    -- scalar
       JSON_QUERY(doc, '$.items')          AS items    -- sub-object/array
FROM   orders;
```

Native `JSON` type from 21c; before that JSON lived in `VARCHAR2`/`CLOB` with an
`IS JSON` check constraint.

---

## Data types

| Use | Type |
|-----|------|
| Integer | `NUMBER(10)` or `INTEGER` (alias for `NUMBER(38)`) |
| Decimal | `NUMBER(p, s)` |
| Float | `BINARY_DOUBLE` / `BINARY_FLOAT` |
| Variable string | `VARCHAR2(n)` (use this, not `VARCHAR`) |
| Large text | `CLOB` |
| Boolean | **none pre-23ai** — `NUMBER(1)` + `CHECK (flag IN (0,1))`, or `CHAR(1)` `'Y'/'N'` |
| Date | `DATE` (carries time!) |
| Timestamp | `TIMESTAMP` / `TIMESTAMP WITH TIME ZONE` |

> Prefer `VARCHAR2` over `VARCHAR`. Oracle reserves `VARCHAR` for possible future
> semantics changes and currently treats it as `VARCHAR2`.

---

## Identity / sequences

```sql
-- 12c+ identity column
CREATE TABLE t (id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, val VARCHAR2(50));

-- Classic sequence
CREATE SEQUENCE t_seq START WITH 1 INCREMENT BY 1;
INSERT INTO t (id, val) VALUES (t_seq.NEXTVAL, 'x');
```

---

## Things that surprise people coming from other dialects

- **`''` is `NULL`.** Comparisons to empty string never match.
- **`DATE` has a time part.** "Equal dates" can differ by hours.
- **No `LIMIT`, no `IF()`, no native boolean** (pre-23ai).
- **`CONVERT` changes character sets**, not data types — use `CAST`/`TO_*`.
- **Identifiers upcase** unless quoted; once quoted, forever quoted.
- **`SELECT` needs a `FROM`** — use `dual` for constant expressions.
- **`FETCH FIRST ... WITH TIES`** exists (handy and standard) — many forget it.

See the full cross-dialect view in the [reference matrix](reference-matrix.md).
