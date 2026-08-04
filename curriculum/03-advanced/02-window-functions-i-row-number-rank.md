# 2. Window Functions I — ROW_NUMBER, RANK, DENSE_RANK


<!-- nav -->
Previous: [1. Common Table Expressions (CTEs)](01-common-table-expressions.md). Next: [3. Window Functions II — Running Totals & Moving Aggregates](03-window-functions-ii-running-totals.md).
<!-- /nav -->

## The idea

Every window function you'll meet in Tier 3 does the same basic trick:
it lets a query look *across a group of related rows* to compute something
— a rank, a running total, a comparison to a neighboring row — **without
collapsing those rows down into one**, the way `GROUP BY` would.

That's the core distinction to hold onto:

- `GROUP BY` takes many rows and produces *fewer* rows (one per group).
- A window function takes many rows and returns the *same number of rows*
  — it just adds a new column computed by looking at a "window" of related
  rows for each one.

`ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` are the simplest window
functions: they each assign a rank/position number to rows, based on some
ordering, optionally restarting within groups.

## Syntax

```sql
ROW_NUMBER() OVER (
    PARTITION BY grouping_column   -- optional: restart numbering per group
    ORDER BY sort_column [DESC]    -- required: what defines "first", "second", ...
)
```

- **`PARTITION BY`** splits the rows into independent groups — like
  `GROUP BY`, but without collapsing rows. Ranking restarts at 1 for each
  partition. Omit it and the whole result set is one partition.
- **`ORDER BY`** (inside the `OVER (...)`) defines the ranking order. This
  is completely independent of any `ORDER BY` at the end of the query.

The three functions differ only in how they handle **ties**:

| Function | Ties | Next value after a tie |
|---|---|---|
| `ROW_NUMBER()` | Never ties — arbitrarily breaks ties by row order | Always increments by 1 |
| `RANK()` | Ties share the same rank | Skips ranks (leaves a gap) |
| `DENSE_RANK()` | Ties share the same rank | Never skips — no gaps |

## Example 1: ranking with real ties

`agg_customer_ltv.order_count` is a plain integer, so ties happen. Ranking
Retail customers by `order_count` within their segment shows all three
functions side by side:

```sql
SELECT customer_id, full_name, customer_segment, order_count,
       ROW_NUMBER() OVER (PARTITION BY customer_segment ORDER BY order_count DESC) AS row_num,
       RANK()       OVER (PARTITION BY customer_segment ORDER BY order_count DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY customer_segment ORDER BY order_count DESC) AS dense_rnk
FROM agg_customer_ltv
WHERE customer_segment = 'Retail'
ORDER BY order_count DESC
LIMIT 8;
```

Verified output:

| customer_id | full_name | order_count | row_num | rnk | dense_rnk |
|---|---|---|---|---|---|
| 41 | Shannon Strong | 22 | 1 | 1 | 1 |
| 67 | Derek Roberts | 21 | 2 | 2 | 2 |
| 195 | Elizabeth Casey | 21 | 3 | 2 | 2 |
| 197 | Mary Miller | 20 | 4 | 4 | 3 |
| 59 | Jasmine Ball | 19 | 5 | 5 | 4 |
| 158 | Dylan Powell | 19 | 6 | 5 | 4 |
| 340 | Shannon Haynes | 19 | 7 | 5 | 4 |
| 80 | Tiffany Taylor | 18 | 8 | 8 | 5 |

Read the tie at `order_count = 21` closely: `ROW_NUMBER()` breaks it
arbitrarily (2 and 3), `RANK()` gives both rank 2 and then *skips* to rank
4, `DENSE_RANK()` gives both rank 2 and continues at 3 with no gap. This
is the entire lesson in one table — memorize this example over memorizing
the definitions.

## Example 2: the "top N per group" pattern

The single most common use of `ROW_NUMBER()` is finding the top (or most
recent) row per group. Wrap it in a CTE and filter on `rn = 1`:

```sql
WITH ranked_orders AS (
    SELECT customer_id, order_id, order_date,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
    FROM (SELECT DISTINCT customer_id, order_id, order_date FROM fact_sales WHERE order_date IS NOT NULL)
)
SELECT customer_id, order_id, order_date
FROM ranked_orders
WHERE rn = 1 AND customer_id IN (41, 343, 67)
ORDER BY customer_id;
```

Verified output — each customer's single most recent order:

| customer_id | order_id | order_date |
|---|---|---|
| 41 | 529 | 2026-03-17 |
| 67 | 6287 | 2026-06-05 |
| 343 | 3898 | 2026-06-25 |

You cannot filter on a window function result directly in `WHERE`
(`WHERE rn = 1` in the same query as the `ROW_NUMBER()` call is a SQL
error — window functions are evaluated *after* `WHERE`). That's exactly
why this pattern always needs a CTE or subquery wrapper: compute the rank
inside, filter on it outside.

## Example 3: the near-duplicate customer dedup pattern

This is Oakhaven's signature `ROW_NUMBER()` use case. Recall from the data
dictionary: `bronze_customers` has 600 rows, but `customer_id` 571–600 (30
rows) are intentional near-duplicates of 30 of the base 1–570 rows — the
same person, signed up "twice," with the email as the one field that
survives normalization intact (`LOWER(TRIM(email))` matches even when
casing/whitespace differs).

The standard dedup pattern: partition by the normalized email, order by
`customer_id`, and keep only `rn = 1` (the earliest/canonical row):

```sql
WITH ranked AS (
    SELECT customer_id, first_name, last_name, email,
           ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY customer_id) AS rn
    FROM bronze_customers
    WHERE email IS NOT NULL AND TRIM(email) != ''
)
SELECT rn, COUNT(*) FROM ranked GROUP BY rn;
```

Verified output:

| rn | COUNT(*) |
|---|---|
| 1 | 536 |
| 2 | 29 |

**Stop and check this against the data dictionary before moving on.** The
data dictionary says there are 30 intentional near-duplicate pairs — but
this query only catches **29** rows at `rn = 2`. That one-row gap is a real
finding, not a mistake in this lesson, and it's worth chasing down because
it teaches something the tidy definition doesn't: dedup heuristics have
edge cases.

Digging in: `customer_id = 572` (`CINDY.ROBINSON@ICLOUD.COM`) has no email
match anywhere in `customer_id` 1–570. Its actual base counterpart turns
out to be `customer_id = 14` ("Cindy ROBINSON") — but that row's `email` is
an **empty string**, one of the ~2% empty-string emails documented in the
data dictionary. The `WHERE email IS NOT NULL AND TRIM(email) != ''` filter
correctly excludes it (you can't dedup on a blank key), which means this
one near-duplicate pair is invisible to an email-only dedup strategy. A
name-based or name+state secondary pass would be needed to catch it — a
good illustration of why real dedup logic is rarely a single clean rule.

## Common mistakes

- **Using `ROW_NUMBER()` when you want to keep ties.** If two rows
  genuinely tie for first place and you only want `rn = 1`, `ROW_NUMBER()`
  will arbitrarily keep one and drop the other. Use `RANK()` (or
  `DENSE_RANK()`) and filter on `rnk = 1` instead if ties should all count.
- **Forgetting `PARTITION BY` entirely** when you meant to rank within
  groups — without it, the whole result set is one partition, and rank 1
  appears only once, not once per group.
- **Filtering on the window function in the same `SELECT`'s `WHERE`
  clause.** `SELECT ..., ROW_NUMBER() OVER (...) AS rn FROM t WHERE rn = 1`
  fails — window functions run after `WHERE`. Wrap in a CTE/subquery and
  filter in the outer query.
- **Trusting a dedup query's row count blindly.** As shown above, the
  "obviously correct" pattern caught 29 of 30 known duplicates. Always
  check derived counts against ground truth when you have it.

## Key takeaways

- Window functions add a column computed over a *window* of related rows,
  without collapsing the row count — the opposite of `GROUP BY`.
- `ROW_NUMBER()` always increments uniquely; `RANK()` ties and skips;
  `DENSE_RANK()` ties and doesn't skip.
- The "top N per group" pattern — `ROW_NUMBER() OVER (PARTITION BY ...
  ORDER BY ...)` wrapped in a CTE, filtered on `rn <= N` — is one of the
  most common patterns in real SQL.
- `ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY
  customer_id)` is the standard email-based dedup pattern — but verify its
  output against known ground truth; it can miss cases (like a blank key)
  that a human reviewer would catch.

---

<!-- nav -->
Previous: [1. Common Table Expressions (CTEs)](01-common-table-expressions.md). Next: [3. Window Functions II — Running Totals & Moving Aggregates](03-window-functions-ii-running-totals.md).
<!-- /nav -->
