# 5. Recursive CTEs

## The idea

Every CTE so far (Module 1) has been non-recursive: define it once,
reference it once. A **recursive CTE** references *itself*, letting you
generate rows iteratively — one step building on the last — until some
stopping condition is met. It's SQL's answer to a loop.

The classic use case, and the one Oakhaven actually uses: generating a
**sequence of consecutive dates** with no gaps. There's no `SELECT
date('2018-01-01') THROUGH date('2038-12-31')` shortcut in SQL — you have
to either generate every date in application code (a Python loop, say) or
generate it inside SQL with a recursive CTE. Oakhaven does the latter.

## Syntax

```sql
WITH RECURSIVE cte_name(column) AS (
    -- "anchor" member: the starting row(s)
    SELECT starting_value

    UNION ALL

    -- "recursive" member: references cte_name itself
    SELECT next_value_expression
    FROM cte_name
    WHERE stopping_condition
)
SELECT * FROM cte_name;
```

Three parts, always:

1. **Anchor member** — a plain `SELECT` with no self-reference. Runs once,
   produces the starting row(s).
2. **Recursive member** — a `SELECT` that references `cte_name` itself,
   combined with the anchor via `UNION ALL`. SQLite re-runs this
   repeatedly: each pass reads the *previous* pass's output as `cte_name`
   and produces the *next* set of rows.
3. **Stopping condition** — a `WHERE` clause in the recursive member. Once
   it produces zero rows, the recursion stops. Omit this and you get an
   infinite loop (SQLite will eventually give up with an error, but don't
   rely on that — always include a stopping condition).

A tiny warm-up before the real thing:

```sql
WITH RECURSIVE nums(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 10
)
SELECT * FROM nums;
```

Verified output: `n` = 1 through 10, one row each. Trace it by hand: the
anchor produces `n = 1`. Pass 1 of the recursive member reads that single
row, computes `n + 1 = 2`, checks `1 < 10` (true), emits `2`. Pass 2 reads
`{2}`, computes `3`, checks `2 < 10` (true), emits `3`. This repeats until
a pass reads `{10}`, computes `11`, checks `10 < 10` (false) — that pass
emits nothing, and the recursion stops. Final result: everything the
anchor and every recursive pass ever emitted, unioned together.

## Worked example: dissecting `bronze/calendar_recursive_cte.sql`

This is the real file that built `bronze_calendar` — not a toy. Full
contents:

```sql
DROP TABLE IF EXISTS bronze_calendar;
CREATE TABLE bronze_calendar (
    datekey INTEGER,
    date    TEXT
);

INSERT INTO bronze_calendar (datekey, date)
WITH RECURSIVE dates(d) AS (
    SELECT date('2018-01-01')
    UNION ALL
    SELECT date(d, '+1 day')
    FROM dates
    WHERE d < date('2038-12-31')
)
SELECT
    CAST(strftime('%Y%m%d', d) AS INTEGER) AS datekey,
    d AS date
FROM dates;
```

Line by line:

- **`DROP TABLE IF EXISTS` / `CREATE TABLE`** — this file is self-contained
  and runnable on its own (per its header comment), so it rebuilds
  `bronze_calendar` from scratch rather than assuming it already exists.
- **`INSERT INTO bronze_calendar (datekey, date) WITH RECURSIVE ...`** — the
  recursive CTE is the *source* of an `INSERT`, not a standalone `SELECT`.
  This is a common and important pattern: recursive CTEs aren't just for
  reading data, they can generate rows that then get written.
- **`dates(d) AS (SELECT date('2018-01-01') ...)`** — the anchor. `d`
  starts as the SQLite date value for 2018-01-01 (this is the *entire*
  starting point — one row).
- **`UNION ALL SELECT date(d, '+1 day') FROM dates WHERE d < date('2038-12-31')`**
  — the recursive member. Each pass takes the previous pass's `d`, adds one
  day with SQLite's `date(..., '+1 day')` modifier, and only continues if
  that previous `d` was still before 2038-12-31. This is what makes the
  spine advance one calendar day at a time with no possibility of gaps —
  each new date is mechanically derived from the last, not independently
  computed.
- **Stopping condition: `WHERE d < date('2038-12-31')`.** The pass that
  reads `d = '2038-12-31'` fails this check and emits nothing — so
  2038-12-31 itself *is* included (it was emitted by the pass before that
  one), but 2039-01-01 never gets generated. Off-by-one reasoning like this
  is exactly what to check first whenever a recursive CTE's row count looks
  wrong by exactly one.
- **Final `SELECT ... FROM dates`** — outside the CTE definition, this
  turns each generated date `d` into the two output columns:
  `datekey` (an `INTEGER` in `YYYYMMDD` form, via `strftime('%Y%m%d', d)`
  cast to `INTEGER`) and `date` (the ISO text form, `d` itself).

Verified: `bronze_calendar` has exactly 7,670 rows, spanning 2018-01-01
through 2038-12-31 inclusive — confirmed directly against the live
database:

```sql
SELECT MIN(date), MAX(date), COUNT(*) FROM bronze_calendar;
```

| MIN(date) | MAX(date) | COUNT(*) |
|---|---|---|
| 2018-01-01 | 2038-12-31 | 7670 |

You can verify the mechanism itself — independent of the `INSERT` — by
running just the recursive CTE's `SELECT` over a short range and comparing
it to what's already in the table:

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

Verified output — 6 rows, 2026-06-25 through 2026-06-30 inclusive:

| datekey | date |
|---|---|
| 20260625 | 2026-06-25 |
| 20260626 | 2026-06-26 |
| 20260627 | 2026-06-27 |
| 20260628 | 2026-06-28 |
| 20260629 | 2026-06-29 |
| 20260630 | 2026-06-30 |

(This lesson only *reads* from the live `oakhaven.db` — it never runs the
`DROP TABLE`/`CREATE TABLE`/`INSERT` statements against the shared file.
Never run destructive statements against a database you're sharing with
other people or processes; that's true here and in production alike.)

## Common mistakes

- **Missing `RECURSIVE`.** `WITH cte AS (...)` and `WITH RECURSIVE cte AS
  (...)` are different keywords — plain `WITH` cannot self-reference at
  all, and you'll get an error, not silent wrong behavior.
- **No stopping condition, or a condition that's never false.** This
  produces an infinite (or near-infinite) loop. Always double check the
  recursive member's `WHERE` clause will eventually be false.
- **Off-by-one boundaries.** `WHERE d < date('2038-12-31')` includes
  2038-12-31 in the output (see above); `WHERE d <= date('2038-12-31')`
  would generate one extra day past it. Always trace the last one or two
  iterations by hand.
- **Forgetting `UNION ALL` must be exactly that** — `UNION` (which
  deduplicates) also works syntactically, but forces SQLite to compare
  every generated row against every previous one for duplicates, which is
  needless overhead for something like a date spine where duplicates are
  structurally impossible anyway.
- **Not testing the recursive member's logic on a tiny range first.**
  Generating 7,670 rows and eyeballing them for correctness is much harder
  than generating 6 and checking those by hand, as done above.

## Key takeaways

- `WITH RECURSIVE name(cols) AS (anchor UNION ALL recursive_member)` has
  three required parts: an anchor, a self-referencing recursive member,
  and a stopping condition inside that member's `WHERE`.
- `bronze_calendar` (7,670 rows, 2018-01-01 through 2038-12-31) is built
  entirely by a recursive CTE feeding an `INSERT` — no Python loop — in
  `project/bronze/calendar_recursive_cte.sql`.
- A recursive CTE can be the source of an `INSERT`, not just a
  standalone `SELECT` — a common pattern for generating spine/reference
  data directly in SQL.
- When a recursive CTE's output looks off by one row, check the stopping
  condition's comparison operator (`<` vs `<=`) first.
