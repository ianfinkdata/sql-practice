# MySQL Cheat Sheet

> Target: **MySQL 8.0+** (several features below — window functions, CTEs,
> `REGEXP_REPLACE` — arrived in 8.0 and do not exist in 5.7).

MySQL is the most widely deployed open-source database in the world — the "M" in
LAMP, the default behind countless web apps. It's a fast, approachable **OLTP**
engine (usually on the InnoDB storage engine). MySQL 8.0 closed most of the
historical gaps with Postgres: it added window functions, CTEs, recursive CTEs,
and real JSON. The quirks below are mostly about its older, looser defaults.

← Back to the [reference matrix](reference-matrix.md) ·
[Decoder home](README.md)

---

## Identity & quoting quirks

- **Backtick identifiers:** `` `select` ``, `` `My Col` ``.
- **Double quotes are strings by default** (unless `ANSI_QUOTES` sql_mode is on).
  So `"x"` is the string `x`, not an identifier.
- **`||` means logical OR**, not concatenation — use `CONCAT()`.
- **Table-name case sensitivity depends on the OS** (case-sensitive on Linux,
  insensitive on Windows/macOS); column and function names are case-insensitive.
- **No `dual` needed** — `SELECT 1` works (though `FROM dual` is *accepted* for
  Oracle compatibility).
- **`sql_mode` matters a lot.** Modern installs default to strict mode; older
  data may have been loaded with loose mode (zero dates, silent truncation).

---

## Signature functions

| Function | What it does |
|----------|--------------|
| `CONCAT(...)` / `CONCAT_WS(sep, ...)` | Concatenate (use these, not `\|\|`). |
| `IFNULL(a, b)` | Two-arg null fallback. |
| `IF(cond, a, b)` | Inline ternary. |
| `GROUP_CONCAT(col ORDER BY ... SEPARATOR ',')` | Concatenate grouped rows. |
| `SUBSTRING_INDEX(s, delim, n)` | Pull the first/last `n` delimited pieces. |
| `DATE_ADD(d, INTERVAL n UNIT)` / `DATEDIFF` | Date math. |
| `DATE_FORMAT(d, '%Y-%m-%d')` / `STR_TO_DATE` | Format/parse with `%`-codes. |
| `LAST_INSERT_ID()` | The auto-increment value just generated. |
| `JSON_EXTRACT(doc, '$.f')` / `->` / `->>` | JSON access. |

---

## Limiting rows

```sql
SELECT * FROM orders ORDER BY amount DESC LIMIT 10;
SELECT * FROM orders ORDER BY id LIMIT 10 OFFSET 20;  -- or LIMIT 20, 10
```

No `WITH TIES`; for top-N-per-group, use a windowed subquery (no `QUALIFY`):

```sql
SELECT * FROM (
  SELECT t.*, ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) rn
  FROM orders t
) x WHERE rn = 1;
```

---

## Strings

```sql
SELECT CONCAT(first_name, ' ', last_name)  AS full_name,   -- NOT first||last
       CONCAT_WS(' ', first_name, last_name),
       UPPER(email),
       SUBSTRING(phone, 1, 3),
       CHAR_LENGTH(name)                    AS chars,        -- LENGTH = bytes!
       INSTR(email, '@'),
       REPLACE(code, '-', ''),
       SUBSTRING_INDEX(SUBSTRING_INDEX(csv, ',', 2), ',', -1) AS second_field
FROM   customers;
```

> `LENGTH()` returns **bytes**; for character count use `CHAR_LENGTH()`. Matters
> for multibyte (UTF-8) text.

---

## Dates

```sql
SELECT CURDATE(), NOW(),
       DATE_ADD(order_date, INTERVAL 7 DAY)    AS plus_week,
       DATE_ADD(order_date, INTERVAL 3 MONTH)  AS plus_quarter,
       DATEDIFF(end_date, start_date)          AS days,
       TIMESTAMPDIFF(MONTH, start_date, end_date) AS months,
       DATE_FORMAT(order_date, '%Y-%m-01')     AS month_start_str,  -- string!
       DATE_FORMAT(order_date, '%Y-%m-%d')     AS iso,
       STR_TO_DATE('2026-06-17', '%Y-%m-%d')   AS parsed
FROM   orders;
```

> MySQL has **no `DATE_TRUNC`**. `DATE_FORMAT(d, '%Y-%m-01')` is the common
> month-start idiom but returns a **string** — wrap in `STR_TO_DATE`/`CAST` if
> you need a date. Format codes are `%`-style (`%Y %m %d %H %i %s`).

---

## NULL & conditional

```sql
SELECT IFNULL(commission, 0),
       COALESCE(nickname, first_name, 'unknown'),   -- portable
       IF(salary > 100000, 'high', 'normal'),
       CASE WHEN status = 'A' THEN 'Active' ELSE 'Other' END,
       a <=> b   AS null_safe_equal                  -- NULL-safe <=>
FROM   employees;
```

---

## Upsert (ON DUPLICATE KEY UPDATE)

```sql
-- 8.0.19+ row alias form (preferred)
INSERT INTO t (id, val) VALUES (1, 'x') AS new
ON DUPLICATE KEY UPDATE val = new.val;

-- Older VALUES() form (deprecated but common)
INSERT INTO t (id, val) VALUES (1, 'x')
ON DUPLICATE KEY UPDATE val = VALUES(val);

-- Insert-or-ignore
INSERT IGNORE INTO t (id, val) VALUES (1, 'x');
```

> The upsert fires on a collision with **any** unique or primary key — you don't
> name the conflict column (unlike Postgres `ON CONFLICT`).

---

## JSON

```sql
SELECT doc->'$.items'         AS items_json,   -- returns JSON
       doc->>'$.customer.name' AS name,         -- returns text (unquoted)
       JSON_EXTRACT(doc, '$.total') AS total,
       JSON_VALUE(doc, '$.total')   AS total2   -- 8.0.21+
FROM   orders;
```

> `->` returns JSON (quoted), `->>` returns unquoted text. Column type is `JSON`.

---

## Data types

| Use | Type |
|-----|------|
| Integer | `INT` / `BIGINT` (`UNSIGNED` available) |
| Decimal | `DECIMAL(p, s)` |
| Float | `DOUBLE` / `FLOAT` |
| Variable string | `VARCHAR(n)` |
| Large text | `TEXT` / `MEDIUMTEXT` / `LONGTEXT` |
| Boolean | `BOOLEAN` — an alias for `TINYINT(1)`; `TRUE`/`FALSE` are `1`/`0` |
| Date | `DATE` |
| Date + time | `DATETIME` (no TZ math) / `TIMESTAMP` (UTC-converted, narrower range) |

> `BOOLEAN` is not a real type — it's `TINYINT(1)`, so a column can hold any
> tiny integer, and `TRUE`/`FALSE` are literally `1`/`0`.

---

## Identity (AUTO_INCREMENT)

```sql
CREATE TABLE t (
  id  INT AUTO_INCREMENT PRIMARY KEY,
  val VARCHAR(50)
);
INSERT INTO t (val) VALUES ('x');
SELECT LAST_INSERT_ID();
```

There are no standalone sequence objects (until you emulate them) — auto-increment
is tied to the table.

---

## Things that surprise people coming from other dialects

- **`||` is OR, not concat.** Use `CONCAT()` (or enable `PIPES_AS_CONCAT`).
- **`"double quotes"` are strings**, not identifiers — use backticks for names.
- **`LENGTH` is bytes**, `CHAR_LENGTH` is characters.
- **No `DATE_TRUNC`** and date "truncation" idioms return strings.
- **No `QUALIFY`**, no `FILTER (WHERE ...)`, no `FETCH FIRST` — use `LIMIT` and
  subqueries.
- **`BOOLEAN` is `TINYINT(1)`** — not a true boolean.
- **Window functions and CTEs are 8.0+** — absent in 5.7.
- **`sql_mode` changes behavior**, including whether `||` concatenates and how
  invalid data is handled.

See the full cross-dialect view in the [reference matrix](reference-matrix.md).
