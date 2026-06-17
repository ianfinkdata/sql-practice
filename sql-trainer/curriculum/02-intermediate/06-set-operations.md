# Set Operations

> Stack and compare whole result sets — combine, overlap, and subtract them.

## The idea

A join combines tables *side by side*, adding columns. Set operations do something different: they stack result sets *on top of each other*, working with whole rows.

Imagine two guest lists for two parties. You might want to:

- **Merge** both lists into one — that's **UNION**.
- Find people who are on **both** lists — that's **INTERSECT**.
- Find people on the first list but **not** the second — that's **EXCEPT** (called **MINUS** in Oracle).

The mental model is plain set theory. Each query produces a set of rows; set operations combine those sets the way you'd combine groups of items.

One more crucial distinction inside UNION:

- **UNION** removes duplicate rows — each result appears once.
- **UNION ALL** keeps every row, duplicates and all.

UNION does extra work to find and drop duplicates. UNION ALL just stacks. If you know there are no overlaps, or you *want* the duplicates, UNION ALL is faster.

## Why it matters

Set operations shine when you have two similarly-shaped lists to reconcile. Combine this year's customers with last year's archived customers into one roster. Find email addresses that appear in both your newsletter list and your customer list. Identify customers who exist in your records but are missing from the mailing list. These "compare two lists" tasks are awkward with joins but natural as set operations.

## See it

Merge customers from two regions into a single deduplicated list:

```sql
SELECT customer_name, region FROM customers WHERE region = 'West'
UNION
SELECT customer_name, region FROM customers WHERE region = 'East';
```

Switch `UNION` to `UNION ALL` and any customer-name/region pair appearing in both halves would show up twice instead of once.

Find values present in **both** results with INTERSECT — say, customer IDs that appear in *both* the sales table and the customers table:

```sql
SELECT customer_id FROM customers
INTERSECT
SELECT customer_id FROM sales;
```

Find values in the first result but **not** the second with EXCEPT — customers who have never made a sale, expressed as a subtraction:

```sql
SELECT customer_id FROM customers
EXCEPT
SELECT customer_id FROM sales;
```

> **Dialect note:** Oracle spells EXCEPT as **MINUS**. MySQL historically lacked INTERSECT and EXCEPT (added in version 8.0.31). When in doubt, see the [Dialect Decoder](../../dialect-decoder/).

### Column compatibility rules

Because you're stacking rows, the two queries must "line up." The rules:

1. **Same number of columns** in each query.
2. **Compatible data types**, column by column, in the same order. Column 1 of the top matches column 1 of the bottom, and so on.
3. **Column names come from the first query.** The bottom query's names are ignored for labeling.
4. Position matters, not name. `SELECT a, b` then `SELECT b, a` will line up `a` with `b` — usually a bug.

## Watch out

- **Mismatched columns** — different counts or incompatible types — cause an immediate error. Line them up in count, type, and order.
- **UNION silently deduplicates.** If you expected every row and some vanished, you probably wanted UNION ALL.
- **UNION ALL is cheaper.** Don't pay for duplicate-removal you don't need.
- **Order matters in EXCEPT/MINUS.** `A EXCEPT B` is not the same as `B EXCEPT A`. Subtraction isn't symmetric.
- **ORDER BY goes at the very end**, applied once to the whole combined result — not inside each individual query.
- **Sets compare entire rows.** Two rows are "the same" only if *every* column matches, so include only the columns you actually want compared.

## Practice

1. Build a single combined list of customer names from the 'West' and 'North' regions, with no duplicates.
2. Produce the same combined list but keeping duplicates, and notice the difference.
3. Find the customer IDs that appear in both the `customers` and `sales` tables.
4. Using a set operation, list the customers who have never made a sale.

---
**Prev:** [Joins: Advanced](./05-joins-advanced.md) · **Next:** [Subqueries](./07-subqueries.md)
