# Anti-Patterns: The Mistakes That Look Reasonable

> A catalog of habits that feel fine in the moment and quietly cost you later — and how to undo each one.

## The idea

An anti-pattern isn't an obvious error — the database won't reject it. It's a choice that *works*, returns the right answer, and seems perfectly sensible, while quietly planting a cost you pay later: in speed, in correctness as data grows, or in the sanity of whoever maintains it next.

A master recognizes these on sight, the way an experienced editor spots a clumsy sentence. Below is a field guide: the anti-pattern, why it bites, and the refactor.

## The catalog

**`SELECT *` in production code.** Convenient when exploring, costly when shipped. It drags every column across the network even when you need three, breaks the moment someone adds or reorders a column, and defeats *covering indexes* (an index that could have answered the whole query from itself now can't, because you demanded columns it doesn't hold). *Refactor:* name the columns you actually need. Save `*` for interactive poking around.

**Implicit type conversions.** Comparing a `VARCHAR` column to a number, or a `DATE` to a string literal, forces the engine to convert one side row by row. Worse, converting the *column* side usually makes the filter non-sargable (see below) and throws away your index. *Refactor:* match types deliberately — compare dates to dates, numbers to numbers — and cast the *literal*, never the column.

**Scalar subqueries in a loop (the N+1 pattern).** A subquery in the `SELECT` list that re-runs once per row — "for each sale, go look up the rep's name" — turns one query into a million tiny ones. The set-based engine you're sitting on is built to do this as a single join. *Refactor:* replace the per-row lookup with a `JOIN`. Let the engine do it in one pass.

```sql
-- Anti-pattern: a correlated lookup that fires per row
SELECT s.sale_id,
       (SELECT r.rep_name FROM sales_rep r WHERE r.rep_id = s.rep_id) AS rep
FROM sales s;

-- Refactor: one join, one pass
SELECT s.sale_id, r.rep_name
FROM sales s
JOIN sales_rep r ON r.rep_id = s.rep_id;
```

**Over-indexing.** Indexes speed reads but *tax every write* — each `INSERT`, `UPDATE`, and `DELETE` must update every index on the table. A table with fifteen indexes spends more effort maintaining them than doing useful work, and the planner wades through redundant choices. *Refactor:* index for the queries you actually run; drop indexes nothing uses. Fewer, well-chosen indexes beat a pile of hopeful ones.

**EAV abuse (Entity-Attribute-Value).** The "infinitely flexible" table: `entity_id, attribute_name, attribute_value`, where every fact becomes a row like `(12, 'region', 'West')`. It feels future-proof, but you've thrown away types, constraints, and readable queries — reconstructing one logical record means pivoting dozens of rows, and nothing stops `'region'` from holding a phone number. *Refactor:* model real columns. Reserve EAV for genuinely open-ended, sparse attributes (like user-defined custom fields), never for your core entities.

**God-tables.** One enormous table with eighty columns trying to be customers *and* orders *and* products *and* settings all at once. Most columns are `NULL` for most rows, every query reads bloat it doesn't need, and the meaning of a row depends on which columns happen to be filled. *Refactor:* split it into focused tables along the lines of the entities you found during data modeling. One table, one kind of thing.

**`NULL` misuse.** `NULL` means "unknown," and it behaves unlike any value — `NULL = NULL` is *not* true, `WHERE x = NULL` matches nothing, and `NULL` quietly vanishes from `COUNT(column)` and slips to the end (or front) of sorts. Trouble comes from using `NULL` to mean "zero" or "none" or "not applicable" — three different things smashed into one ambiguous marker. *Refactor:* use `NULL` only for genuinely unknown values; use real defaults (`0`, `''`, a status code) for the rest, and reach for `IS NULL` / `COALESCE` deliberately.

**Non-sargable filters.** "Sargable" = "Search ARGument ABLE" = a filter the engine can satisfy with an index. Wrap a column in a function and you destroy sargability: `WHERE UPPER(email) = 'A@X.COM'` or `WHERE YEAR(sale_date) = 2026` forces a full scan, because the index is on the *raw* column, not on the function's output. *Refactor:* rewrite so the column stands alone:

```sql
-- Non-sargable: function on the column blinds the index
WHERE YEAR(sale_date) = 2026

-- Sargable: a plain range the index (and partition pruning) can use
WHERE sale_date >= DATE '2026-01-01'
  AND sale_date <  DATE '2027-01-01'
```

This one ties together the whole tier: the *same* habit that keeps filters sargable is the habit that enables partition pruning and predicate pushdown. Leave the column bare, and the engine can help you everywhere at once.

> **Dialect note:** function names (`UPPER`, `YEAR`, `EXTRACT`) and index types differ by engine, but the sargability principle is universal — see the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **"It returns the right answer" is not "it's correct."** Most anti-patterns are functionally fine and quietly expensive.
- **They scale worse than they start.** The N+1 query that's fine at 100 rows melts at 10 million.
- **`SELECT *` and non-sargable filters are the two you'll see most** — train your eye for them first.
- **Flexibility has a price.** EAV and god-tables sell flexibility and bill you in correctness and clarity.
- **Don't fix what isn't measured.** Confirm an anti-pattern is actually your bottleneck before rewriting; not every `SELECT *` is worth a code change.

## Practice

1. You inherit a query with a correlated scalar subquery looking up `region` per sale. Rewrite it as a join and explain the performance difference in plain English.
2. Find the non-sargable filter and rewrite it: `WHERE LOWER(customer_name) LIKE 'a%'`. What index would make your version fast?
3. A table stores customer preferences as EAV rows. Describe two concrete problems this causes, and sketch the column-based table you'd replace it with.
4. Audit a table with twelve indexes where writes have gotten slow. Describe how you'd decide which indexes to keep and which to drop.

---
**Prev:** [Performance at Scale](./06-performance-at-scale.md) · **Next:** [Dialect Mastery](./08-dialect-mastery.md)
