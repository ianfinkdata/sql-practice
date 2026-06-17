# ORDER BY and LIMIT: Sorting and Trimming Results

> After this module you'll be able to sort your results in any order and keep just the top few rows.

## The idea

By default, a database hands back rows in no guaranteed order — like dealing a deck of cards face-up in whatever order they happen to sit. Often you want them sorted: biggest sales first, customers by signup date, products alphabetically. That's what **ORDER BY** does.

You give `ORDER BY` a column to sort on, and it arranges the rows by that column's values. By default it sorts **ascending** — smallest to largest, A to Z, earliest to latest. The keyword for that is **ASC**, though it's the default so you rarely write it. To flip it — largest to smallest, Z to A, newest first — you add **DESC**, short for "descending."

You can sort by more than one column. Think of how a phone book sorts by last name, then by first name to break ties. You list columns in priority order: the first column is the main sort, the next one only matters when the first column ties.

Once your rows are sorted, you often want just the top few — the 5 biggest sales, the 10 newest customers. **LIMIT** caps how many rows come back. `LIMIT 5` means "give me at most 5 rows." It's almost always paired with `ORDER BY`, because "top 5" only means something once the rows are sorted.

## Why it matters

"Top sellers," "most recent signups," "highest-value customers" — these everyday questions are all *sort, then take the top N*. Sorting also just makes results readable. And `LIMIT` keeps you from accidentally pulling a million rows when you only wanted a peek at the first handful.

## See it

Sort sales from largest amount to smallest:

```sql
SELECT sale_id, amount
FROM sales
ORDER BY amount DESC;
```

Sort customers by region, and within each region by signup date (newest first):

```sql
SELECT customer_name, region, signup_date
FROM customers
ORDER BY region ASC, signup_date DESC;
```

Get just the five biggest sales:

```sql
SELECT sale_id, amount
FROM sales
ORDER BY amount DESC
LIMIT 5;
```

Notice the order of the clauses: `FROM`, then `WHERE` (if you have one), then `ORDER BY`, then `LIMIT`. The database filters, then sorts, then trims.

> **Dialect note:** `LIMIT` is used by PostgreSQL, MySQL, and SQLite. SQL Server uses `SELECT TOP 5 ...` instead. Oracle uses `FETCH FIRST 5 ROWS ONLY` (or older code uses `ROWNUM`). The idea is identical — only the spelling differs. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Without `ORDER BY`, row order isn't guaranteed.** Don't assume rows come back "in the order they were added" — they might not.
- **`LIMIT` without `ORDER BY` gives arbitrary rows.** "Give me 5 rows" with no sort means 5 *random-ish* rows, not the top 5 of anything.
- **`DESC` applies to one column at a time.** In `ORDER BY a, b DESC`, only `b` is descending; `a` is still ascending. Add `DESC` to each column you want reversed.
- **`ORDER BY` comes before `LIMIT`.** Sort first, trim second — both in the query and in your thinking.

## Practice

1. List all products sorted by `unit_price` from cheapest to most expensive.
2. Show all customers sorted by `signup_date` with the most recent first.
3. Return the three most expensive products. (Sort, then limit.)
4. Sort `sales_rep` by `commission_rate` highest-first, breaking ties by `rep_name` alphabetically.

---
**Prev:** [WHERE: Filtering Rows](03-where.md) · **Next:** [DISTINCT and Expressions](05-distinct-expressions.md)
