# The Reference Matrix

The big translation table. Find your task on the left, read across for the exact
spelling in each engine. Dialects are always in the same order: **Oracle ·
Databricks · MySQL · Postgres**.

> Targets: Oracle 19c+ · Databricks SQL (Spark SQL/Photon) · MySQL 8.0+ ·
> PostgreSQL 14+. Where a feature is version-gated *within* a dialect, the row
> says so.

Jump to: [Limiting rows](#limiting-rows) · [Strings](#strings) ·
[NULL handling](#null-handling) · [Conditional logic](#conditional-logic) ·
[Dates & time](#dates--time) · [Casting](#casting--conversion) ·
[Aggregation extras](#aggregation-extras) · [Upsert / merge](#upsert--merge) ·
[Identity / auto-increment](#identity--auto-increment) ·
[Data types](#data-types) · [JSON](#json) · [Regex](#regular-expressions) ·
[QUALIFY & windows](#qualify--window-niceties) · [Misc & gotchas](#misc--syntax-quirks)

---

## Limiting rows

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Top **N** rows | `SELECT ... FETCH FIRST 10 ROWS ONLY` (12c+); or `WHERE ROWNUM <= 10` | `SELECT ... LIMIT 10` | `SELECT ... LIMIT 10` | `SELECT ... LIMIT 10`; also `FETCH FIRST 10 ROWS ONLY` |
| Top N **with ties** | `FETCH FIRST 10 ROWS WITH TIES` (needs `ORDER BY`) | not supported — use `RANK()` window | not supported — use window | `FETCH FIRST 10 ROWS WITH TIES` |
| Pagination (skip 20, take 10) | `OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY` | `LIMIT 10 OFFSET 20` | `LIMIT 10 OFFSET 20` (or `LIMIT 20, 10`) | `LIMIT 10 OFFSET 20` |
| Percent of rows | `FETCH FIRST 10 PERCENT ROWS ONLY` | not native — use `percent_rank()` | not native | not native — use `percent_rank()` |

> **Gotcha:** `ROWNUM` is assigned *before* `ORDER BY`, so `WHERE ROWNUM <= 10
> ORDER BY x` does **not** give you the top 10 by `x` — it grabs 10 arbitrary
> rows and *then* sorts them. Use `FETCH FIRST ... ONLY`, or order in a
> subquery first. `LIMIT` does not exist in Oracle before 23ai.

---

## Strings

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Concatenate | `a \|\| b` or `CONCAT(a,b)` | `a \|\| b` or `concat(a,b)` | `CONCAT(a,b)` (`\|\|` is **OR**!) | `a \|\| b` or `CONCAT(a,b)` |
| Concat with separator | `a\|\|','\|\|b` | `concat_ws(',',a,b)` | `CONCAT_WS(',',a,b)` | `concat_ws(',',a,b)` |
| Substring | `SUBSTR(s, 2, 3)` | `substring(s,2,3)` / `substr` | `SUBSTRING(s,2,3)` / `SUBSTR` | `SUBSTRING(s,2,3)` / `substr` |
| Length (chars) | `LENGTH(s)` | `length(s)` / `char_length` | `CHAR_LENGTH(s)` (`LENGTH`=bytes) | `LENGTH(s)` / `char_length` |
| Upper / lower | `UPPER(s)` / `LOWER(s)` | `upper` / `lower` | `UPPER` / `LOWER` | `UPPER` / `LOWER` |
| Trim both sides | `TRIM(s)` | `trim(s)` | `TRIM(s)` | `TRIM(s)` |
| Replace text | `REPLACE(s,'a','b')` | `replace(s,'a','b')` | `REPLACE(s,'a','b')` | `REPLACE(s,'a','b')` |
| Position of substr | `INSTR(s,'x')` | `instr(s,'x')` / `locate` | `INSTR(s,'x')` / `LOCATE` | `POSITION('x' IN s)` / `strpos` |
| Left / right pad | `LPAD(s,5,'0')` / `RPAD` | `lpad` / `rpad` | `LPAD` / `RPAD` | `lpad` / `rpad` |
| Get the Nth split piece | `REGEXP_SUBSTR(s,'[^,]+',1,2)` | `split(s,',')[1]` (0-based) | `SUBSTRING_INDEX(SUBSTRING_INDEX(s,',',2),',',-1)` | `split_part(s,',',2)` |
| Split into array | no array type — use `REGEXP_SUBSTR` loop | `split(s,',')` → array | no array type — `JSON_TABLE` workaround | `string_to_array(s,',')` |

> **Gotcha:** In MySQL, `\|\|` is the logical **OR** operator by default, *not*
> concatenation — `'a' \|\| 'b'` evaluates to `0`. Use `CONCAT()`, or set
> `sql_mode = 'PIPES_AS_CONCAT'` to opt into `\|\|`-as-concat.

> **Gotcha:** Databricks/Spark `split` returns a **0-indexed** array, so the
> first piece is `[0]`. Oracle and Postgres positional split helpers are
> **1-indexed**.

---

## NULL handling

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| First non-NULL (portable) | `COALESCE(a,b,c)` | `coalesce(a,b,c)` | `COALESCE(a,b,c)` | `COALESCE(a,b,c)` |
| Two-arg "if null then" | `NVL(a,b)` | `nvl(a,b)` or `coalesce` | `IFNULL(a,b)` | use `COALESCE(a,b)` |
| If/else on null | `NVL2(a, ifNotNull, ifNull)` | `nvl2(a,x,y)` | use `IF(a IS NULL,...)` | use `CASE` |
| NULL if equal | `NULLIF(a,b)` | `nullif(a,b)` | `NULLIF(a,b)` | `NULLIF(a,b)` |
| Null-safe equality | `a = b` + `IS NULL` checks, or `DECODE` | `a <=> b` | `a <=> b` | `a IS NOT DISTINCT FROM b` |

> **Gotcha:** In Oracle, an **empty string `''` is stored as `NULL`**. So
> `WHERE name = ''` never matches, and `LENGTH('')` is `NULL`. The other three
> treat `''` as a real zero-length string distinct from `NULL`.

---

## Conditional logic

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Searched conditional (portable) | `CASE WHEN ... THEN ... ELSE ... END` | same | same | same |
| Simple value mapping | `CASE x WHEN 1 THEN 'a' END` or `DECODE(x,1,'a',...)` | `CASE x WHEN ...` | `CASE x WHEN ...` | `CASE x WHEN ...` |
| Ternary `if(cond,a,b)` | use `CASE` (no `IF` in SQL) | `if(cond,a,b)` | `IF(cond,a,b)` | use `CASE` (no `IF`) |

> **Tip:** `CASE` works in all four and is the portable choice. `DECODE` is
> Oracle-only; `IF()` is MySQL/Databricks-only and does **not** exist in Postgres
> SQL (Postgres `IF` is PL/pgSQL only).

---

## Dates & time

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Current date | `TRUNC(SYSDATE)` / `CURRENT_DATE` | `current_date()` | `CURDATE()` / `CURRENT_DATE` | `CURRENT_DATE` |
| Current timestamp | `SYSTIMESTAMP` / `CURRENT_TIMESTAMP` | `current_timestamp()` | `NOW()` / `CURRENT_TIMESTAMP` | `now()` / `CURRENT_TIMESTAMP` |
| Add N days | `d + 7` or `d + INTERVAL '7' DAY` | `date_add(d, 7)` | `DATE_ADD(d, INTERVAL 7 DAY)` | `d + INTERVAL '7 days'` |
| Add N months | `ADD_MONTHS(d, 3)` | `add_months(d, 3)` | `DATE_ADD(d, INTERVAL 3 MONTH)` | `d + INTERVAL '3 months'` |
| Difference in days | `d1 - d2` (number) | `datediff(d1, d2)` | `DATEDIFF(d1, d2)` | `d1 - d2` (integer) |
| Difference in months | `MONTHS_BETWEEN(d1,d2)` | `months_between(d1,d2)` | `TIMESTAMPDIFF(MONTH,d2,d1)` | `(extract(year ...) ... )` — compute manually |
| Truncate to month start | `TRUNC(d,'MM')` | `date_trunc('month', d)` | `DATE_FORMAT(d,'%Y-%m-01')` (returns string) | `date_trunc('month', d)` |
| Extract a part | `EXTRACT(YEAR FROM d)` | `extract(YEAR FROM d)` / `year(d)` | `EXTRACT(YEAR FROM d)` / `YEAR(d)` | `EXTRACT(YEAR FROM d)` / `date_part('year',d)` |
| Format date → string | `TO_CHAR(d,'YYYY-MM-DD')` | `date_format(d,'yyyy-MM-dd')` | `DATE_FORMAT(d,'%Y-%m-%d')` | `to_char(d,'YYYY-MM-DD')` |
| Parse string → date | `TO_DATE('2026-06-17','YYYY-MM-DD')` | `to_date('2026-06-17','yyyy-MM-dd')` | `STR_TO_DATE('2026-06-17','%Y-%m-%d')` | `to_date('2026-06-17','YYYY-MM-DD')` |

> **Gotcha:** Format-pattern alphabets differ. Oracle/Postgres use `YYYY-MM-DD`
> (capital). Databricks/Spark use Java patterns — `yyyy-MM-dd` (lowercase year,
> capital month). MySQL uses `%`-codes — `%Y-%m-%d`. Copying a format string
> across engines silently produces garbage.

> **Gotcha:** MySQL has no `DATE_TRUNC`. The common `DATE_FORMAT(d,'%Y-%m-01')`
> idiom returns a **string**, not a date — wrap in `STR_TO_DATE` / `CAST` if you
> need a date back.

---

## Casting / conversion

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Generic cast (portable) | `CAST(x AS NUMBER)` | `cast(x AS INT)` | `CAST(x AS DECIMAL)` | `CAST(x AS numeric)` |
| Shorthand cast | — | `x::int` (also supported) | — | `x::numeric` |
| String → number | `TO_NUMBER('123')` | `cast('123' AS int)` | `CAST('123' AS SIGNED)` | `'123'::int` |
| String → date | `TO_DATE(...)` | `to_date(...)` | `STR_TO_DATE(...)` | `to_date(...)` / `'2026-06-17'::date` |
| Number/date → string | `TO_CHAR(...)` | `cast(... AS string)` / `date_format` | `CAST(... AS CHAR)` / `DATE_FORMAT` | `to_char(...)` / `x::text` |
| `CONVERT` style | `CAST` (Oracle `CONVERT` is for charsets!) | — | `CONVERT(x, SIGNED)` / `CAST` | — |

> **Gotcha:** Oracle's `CONVERT(s, dest_charset, src_charset)` converts
> **character sets**, not data types. To change type in Oracle use `CAST`,
> `TO_NUMBER`, `TO_DATE`, or `TO_CHAR`. MySQL's `CONVERT(x, type)` *is* a type
> cast. Same keyword, different jobs.

---

## Aggregation extras

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Concatenate rows into one string | `LISTAGG(name, ',') WITHIN GROUP (ORDER BY name)` | `array_join(collect_list(name), ',')` or `concat_ws(',', collect_list(name))` | `GROUP_CONCAT(name ORDER BY name SEPARATOR ',')` | `STRING_AGG(name, ',' ORDER BY name)` |
| Collect into array | nested table types (rare) | `collect_list(x)` / `collect_set(x)` | no array type | `array_agg(x)` |
| Conditional aggregate (`FILTER`) | not supported — use `SUM(CASE WHEN ... )` | not supported — use `sum(case when ...)` | not supported — use `SUM(CASE ...)` | `COUNT(*) FILTER (WHERE cond)` ✅ |

> **Gotcha:** `FILTER (WHERE ...)` is ANSI but **only Postgres** (of these four)
> implements it. Everywhere else, fall back to `SUM(CASE WHEN cond THEN 1 ELSE 0
> END)` / `COUNT(CASE WHEN cond THEN 1 END)`.

> **Gotcha:** MySQL `GROUP_CONCAT` silently truncates at
> `group_concat_max_len` (default 1024 bytes). Raise the session variable for
> long lists.

---

## Upsert / merge

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Merge / upsert | `MERGE INTO t USING src ON (...) WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ...` | `MERGE INTO t USING src ON ... WHEN MATCHED THEN UPDATE SET * WHEN NOT MATCHED THEN INSERT *` (Delta tables) | `INSERT INTO t (...) VALUES (...) ON DUPLICATE KEY UPDATE col = VALUES(col)` | `INSERT INTO t (...) VALUES (...) ON CONFLICT (key) DO UPDATE SET col = EXCLUDED.col` |
| Insert-or-ignore | `MERGE ... WHEN NOT MATCHED THEN INSERT` | `MERGE ... WHEN NOT MATCHED THEN INSERT` | `INSERT IGNORE INTO t ...` | `INSERT ... ON CONFLICT DO NOTHING` |

> **Gotcha:** MySQL keys upserts off **any** unique/primary key that collides —
> you don't name the conflict column. Postgres `ON CONFLICT` requires you to
> name the target column(s) or constraint. In Postgres, reference the proposed
> row via `EXCLUDED.col`; in MySQL 8.0.19+, prefer the row alias
> (`... AS new ... UPDATE col = new.col`) over the deprecated `VALUES(col)`.

---

## Identity / auto-increment

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Auto-incrementing PK | `id NUMBER GENERATED ALWAYS AS IDENTITY` (12c+); or `SEQUENCE` + trigger | `id BIGINT GENERATED ALWAYS AS IDENTITY` (Delta) | `id INT AUTO_INCREMENT PRIMARY KEY` | `id INT GENERATED ALWAYS AS IDENTITY` (preferred) or `id SERIAL` |
| Standalone sequence | `CREATE SEQUENCE s; s.NEXTVAL` | not supported (use IDENTITY) | not supported (use AUTO_INCREMENT) | `CREATE SEQUENCE s; nextval('s')` |
| Last inserted id | `RETURNING id INTO :v` | — (query the table) | `LAST_INSERT_ID()` | `INSERT ... RETURNING id` |

> **Gotcha:** Databricks/Delta IDENTITY values are **guaranteed unique and
> increasing but not necessarily consecutive** (gaps are normal due to parallel
> writes). Don't treat them as a gapless counter. The same caution applies to
> Postgres sequences and Oracle identities.

---

## Data types

| Concept | Oracle | Databricks | MySQL | Postgres |
|---------|--------|------------|-------|----------|
| Integer | `NUMBER(10)` / `INTEGER` | `INT` / `BIGINT` | `INT` / `BIGINT` | `INTEGER` / `BIGINT` |
| Exact decimal | `NUMBER(p,s)` | `DECIMAL(p,s)` | `DECIMAL(p,s)` | `NUMERIC(p,s)` |
| Floating point | `BINARY_DOUBLE` / `NUMBER` | `DOUBLE` / `FLOAT` | `DOUBLE` / `FLOAT` | `DOUBLE PRECISION` / `REAL` |
| Variable string | `VARCHAR2(n)` | `STRING` (no length) | `VARCHAR(n)` | `VARCHAR(n)` / `TEXT` |
| Large text | `CLOB` | `STRING` | `TEXT` | `TEXT` |
| Boolean | **none pre-23ai** — use `NUMBER(1)` or `CHAR(1)` | `BOOLEAN` | `BOOLEAN` (alias for `TINYINT(1)`) | `BOOLEAN` |
| Date only | `DATE` (Oracle `DATE` includes time!) | `DATE` | `DATE` | `DATE` |
| Date + time | `TIMESTAMP` (or `DATE`) | `TIMESTAMP` | `DATETIME` / `TIMESTAMP` | `TIMESTAMP` / `TIMESTAMPTZ` |

> **Gotcha:** Oracle `DATE` **always carries a time component** (down to the
> second) — it is not a pure calendar date. Use `TRUNC(d)` to zero the time, and
> `TIMESTAMP` when you need sub-second precision.

> **Gotcha:** Pre-23ai Oracle has **no boolean type** in SQL (PL/SQL has one,
> tables don't). The convention is `NUMBER(1)` with a `CHECK (flag IN (0,1))` or
> `CHAR(1)` with `'Y'`/`'N'`. Oracle Database 23ai finally adds a SQL `BOOLEAN`.

---

## JSON

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Extract scalar field | `JSON_VALUE(doc, '$.name')` | `doc:name` or `get_json_object(doc,'$.name')` | `JSON_VALUE(doc,'$.name')` (8.0.21+) or `doc->>'$.name'` | `doc->>'name'` (jsonb) |
| Extract sub-object | `JSON_QUERY(doc, '$.addr')` | `doc:addr` | `JSON_EXTRACT(doc,'$.addr')` or `doc->'$.addr'` | `doc->'addr'` |
| Deep path | `JSON_VALUE(doc,'$.a.b[0]')` | `doc:a.b[0]` | `doc->>'$.a.b[0]'` | `doc#>>'{a,b,0}'` |
| Build JSON | `JSON_OBJECT('k' VALUE v)` | `to_json(named_struct(...))` | `JSON_OBJECT('k', v)` | `jsonb_build_object('k', v)` |
| Typical column type | `JSON` (21c+) / `CLOB` + check | `STRING` (parse on read) | `JSON` | `jsonb` (preferred) / `json` |

> **Gotcha:** In MySQL and Postgres, `->` returns **JSON**, while `->>` returns
> **text**. Mixing them up gives you quoted strings (`"value"`) where you wanted
> plain text. In Databricks the colon operator `doc:field` returns a string and
> is the idiomatic, concise form.

---

## Regular expressions

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Match (boolean) | `REGEXP_LIKE(s, '^a.*z$')` | `s rlike '^a.*z$'` / `regexp(s, ...)` | `s REGEXP '^a.*z$'` / `RLIKE` | `s ~ '^a.*z$'` (`~*` = case-insensitive) |
| Not match | `NOT REGEXP_LIKE(...)` | `NOT (s rlike ...)` | `s NOT REGEXP ...` | `s !~ '...'` |
| Replace | `REGEXP_REPLACE(s,'\d','#')` | `regexp_replace(s,'\\d','#')` | `REGEXP_REPLACE(s,'[0-9]','#')` (8.0+) | `regexp_replace(s,'\d','#','g')` |
| Extract match | `REGEXP_SUBSTR(s,'\d+')` | `regexp_extract(s,'(\\d+)',1)` | `REGEXP_SUBSTR(s,'[0-9]+')` (8.0+) | `(regexp_match(s,'\d+'))[1]` |

> **Gotcha:** Postgres `regexp_replace` replaces **only the first match** unless
> you pass the `'g'` (global) flag. Oracle's `REGEXP_REPLACE` is global by
> default. MySQL gained regex *functions* (`REGEXP_REPLACE`/`_SUBSTR`/`_INSTR`)
> only in 8.0 — the `REGEXP`/`RLIKE` operators existed earlier.

> **Gotcha:** In Databricks/Spark string literals, the backslash must be escaped
> (`'\\d'`), or use a raw `r'\d'` string.

---

## QUALIFY & window niceties

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Filter on a window function (`QUALIFY`) | `QUALIFY` (23ai+); else wrap in subquery | `QUALIFY row_number() OVER (...) = 1` ✅ | not supported — subquery | not supported — subquery |
| Window function basics | `OVER (PARTITION BY ... ORDER BY ...)` | same | same (8.0+) | same |

The portable workaround for `QUALIFY` (use this for MySQL/Postgres, and Oracle
pre-23ai):

```sql
SELECT *
FROM (
  SELECT t.*,
         ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn
  FROM employees t
) ranked
WHERE rn = 1;
```

> **Gotcha:** Window functions arrived in **MySQL 8.0** — they do not exist in
> 5.7. If you're on an older MySQL, the subquery-with-self-join emulations are
> your only option.

---

## Misc & syntax quirks

| Task | Oracle | Databricks | MySQL | Postgres |
|------|--------|------------|-------|----------|
| Select without a table | `SELECT 1 FROM dual` | `SELECT 1` (no FROM) | `SELECT 1` (no FROM) | `SELECT 1` (no FROM) |
| Boolean literal | use `1`/`0` or `'Y'`/`'N'` (no `TRUE` pre-23ai) | `true` / `false` | `TRUE` / `FALSE` (= 1/0) | `TRUE` / `FALSE` |
| String literal | single quotes `'...'`; escape `''` | single quotes `'...'` | single quotes (double quotes allowed by default) | single quotes only |
| Quoted identifier | `"My Col"` (then case-sensitive) | `` `My Col` `` (backticks) | `` `My Col` `` (backticks) | `"My Col"` (then case-sensitive) |
| Unquoted identifier case | folded to **UPPER** | case-insensitive, stored lower | depends on OS for tables; case-insensitive for columns | folded to **lower** |
| Comment | `-- line` / `/* block */` | same | `-- ` (needs trailing space), `#`, `/* */` | `-- ` / `/* */` |

> **Gotcha:** Oracle and Postgres both fold *unquoted* identifiers — but in
> **opposite directions**. Oracle uppercases (`my_col` → `MY_COL`), Postgres
> lowercases (`MyCol` → `mycol`). If you ever quote a mixed-case name on
> creation (`"MyCol"`), you must quote it identically forever after. Easiest
> rule: never quote identifiers, and use `snake_case`.

> **Gotcha:** MySQL uses **backticks** for identifiers and allows double quotes
> as string literals by default. Postgres is the opposite: double quotes are
> *always* identifiers, never strings. Don't write `WHERE name = "x"` in
> Postgres — it looks for a **column** named `x`.

---

## See also

- Per-dialect cheat sheets: [Oracle](oracle.md) · [Databricks](databricks.md) ·
  [MySQL](mysql.md) · [Postgres](postgres.md)
- [How the Decoder works](README.md)
- Learn the concepts first in the [curriculum](../curriculum/).
