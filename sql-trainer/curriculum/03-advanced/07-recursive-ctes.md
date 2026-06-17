# Recursive CTEs

> A query that calls itself — to walk hierarchies and generate sequences.

## The idea

Most SQL works one "level" at a time. But some data is *nested to an unknown depth*. An org chart: an employee reports to a manager, who reports to a director, who reports to a VP — and you don't know in advance how many rungs the ladder has. A category tree, a folder structure, a chain of replies. Ordinary joins can't follow a path of unknown length.

A **recursive CTE** can. It's a query that **refers to itself**, walking down a chain one step at a time until there's nothing left to walk.

The shape is always two halves joined by `UNION ALL`:

- The **anchor member** — the starting point. The top of the org chart. The first number in a sequence. This runs once and seeds the process.
- The **recursive member** — the rule for taking *one step further*. "Find everyone who reports to the people I found last round." This runs over and over, each pass building on the rows the previous pass produced.

Picture climbing down a ladder. The anchor places you on the top rung. The recursive member is the instruction "step down one rung." SQL repeats that instruction automatically, gathering each rung, and stops on its own when there are no more rungs — when the recursive member returns no new rows.

The same machine that walks a hierarchy can also **generate** data: start at 1, "add 1 to the last number," stop at 100 — and you've built a sequence with no source table at all. That's the trick behind generating calendars and number lists.

## Why it matters

Hierarchies are everywhere and notoriously awkward in SQL: org charts, product categories, bill-of-materials, threaded comments, geographic regions nested inside regions. Without recursion you'd have to guess the depth and write one join per level — fragile and ugly. A recursive CTE handles any depth with a single, fixed query.

Sequence generation is the unsung hero of analytics. Want a report with a row for *every* day in a range, even days with zero sales? You can't pull missing days from the sales table — they aren't there. You generate a calendar and `LEFT JOIN` your data onto it. Recursion builds that calendar.

## See it

Walk an org chart. (Imagine `sales_rep` has a `manager_id` pointing to another rep.) Start at the top and descend, tracking depth:

```sql
WITH RECURSIVE org AS (
  -- Anchor: the top boss, who has no manager
  SELECT rep_id, rep_name, manager_id, 1 AS level
  FROM sales_rep
  WHERE manager_id IS NULL

  UNION ALL

  -- Recursive: people who report to someone already found
  SELECT r.rep_id, r.rep_name, r.manager_id, o.level + 1
  FROM sales_rep r
  JOIN org o ON r.manager_id = o.rep_id
)
SELECT rep_id, rep_name, level
FROM org
ORDER BY level;
```

Each pass finds the next layer down; `level` records how deep. SQL stops when a pass finds nobody new.

Generate a sequence of numbers 1 through 10 from nothing:

```sql
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 10
)
SELECT n FROM numbers;
```

Build a calendar — one row per day across a month — perfect for filling in gaps:

```sql
WITH RECURSIVE calendar AS (
  SELECT DATE '2026-01-01' AS day
  UNION ALL
  SELECT day + INTERVAL '1 day'
  FROM calendar
  WHERE day < DATE '2026-01-31'
)
SELECT day FROM calendar;
```

> **Dialect note:** Standard SQL and most engines require the `RECURSIVE` keyword; SQL Server omits it (just `WITH`). Date arithmetic like `+ INTERVAL '1 day'` varies widely — SQL Server uses `DATEADD`. Some engines also offer `GENERATE_SERIES` as a shortcut for sequences. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Always include a stopping condition.** A recursive member with no `WHERE` to halt it (or a hierarchy with a cycle) will loop forever — many engines cap iterations and error out to protect you.
- **`UNION ALL`, not `UNION`.** `UNION` deduplicates on every step, which is slow and can mask the stopping logic. Use `UNION ALL`.
- **Anchor and recursive parts must have matching columns** — same count, same types, in the same order, like any set operation.
- **Cycles in the data bite.** If A reports to B and B reports to A (a data error), recursion never terminates. Some engines support `CYCLE` detection; otherwise guard your data.
- **SQL Server drops `RECURSIVE`.** It's just `WITH` there, even though the query recurses. Don't let the missing keyword confuse you.

## Practice

1. In plain English, describe the roles of the anchor member and the recursive member.
2. Explain why a recursive CTE is better than writing one join per hierarchy level.
3. Write a recursive CTE that generates the numbers 1 through 20.
4. Build a recursive calendar of every day in a given month, then describe how you'd `LEFT JOIN` sales onto it to surface days with zero sales.

---
**Prev:** [Common Table Expressions (CTEs)](./06-ctes.md) · **Next:** [Date & Time Intelligence](./08-date-time-intelligence.md)
