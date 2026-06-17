# Joins: Advanced

> The rest of the join family — RIGHT, FULL, CROSS, SELF, and the clever anti-join.

## The idea

You've met INNER and LEFT. A few more join styles round out the toolkit. Each one answers a slightly different question about how two sets of rows should be combined.

- **RIGHT JOIN** — the mirror image of LEFT. Keep every row from the *right* table, matched where possible. In practice it's just a LEFT JOIN flipped around, and most people prefer to write LEFT.
- **FULL OUTER JOIN** — keep *everything* from both sides. Matched rows line up; unmatched rows from either table appear with NULLs filling the gaps. It's "show me the complete picture, including the lonely rows on both ends."
- **CROSS JOIN** — pair *every* row on the left with *every* row on the right, no matching condition at all. If one table has 10 rows and the other 5, you get 50. It's a deliberate combination machine.
- **SELF JOIN** — a table joined to *itself*. Useful when rows in one table relate to other rows in the same table.
- **Anti-join** — not a keyword, but a pattern: find rows in one table that have *no* match in another. "Which customers have never bought anything?"

A handy mental image: INNER is the overlap of two circles. LEFT and RIGHT add one circle's leftovers. FULL adds both circles' leftovers. CROSS ignores circles entirely and multiplies. The anti-join keeps *only* the leftovers — the part with no overlap.

## Why it matters

The interesting business questions often live in the gaps. Who *hasn't* ordered? Which reps have *no* sales? What products were *never* sold? These are anti-join questions, and they're easy to get wrong without the pattern. FULL OUTER reconciles two lists. CROSS builds every combination, like a price grid. SELF join handles hierarchies. Knowing these means fewer questions stump you.

## See it

**FULL OUTER JOIN** — every customer and every sale, matched where they line up, NULLs where they don't:

```sql
SELECT c.customer_name, s.amount
FROM customers AS c
FULL OUTER JOIN sales AS s
  ON c.customer_id = s.customer_id;
```

> **Dialect note:** MySQL has no FULL OUTER JOIN; you emulate it by UNION-ing a LEFT JOIN with a RIGHT JOIN. See the [Dialect Decoder](../../dialect-decoder/).

**CROSS JOIN** — pair every region with every product category, e.g. to build a blank planning grid:

```sql
SELECT c.region, p.category
FROM customers AS c
CROSS JOIN products AS p;
```

No ON clause — that's the giveaway that it's a cross join.

**SELF JOIN** — suppose `sales_rep` had a `manager_id` pointing at another rep. To list each rep beside their manager's name, join the table to itself with two aliases:

```sql
SELECT
  emp.rep_name   AS rep,
  mgr.rep_name   AS manager
FROM sales_rep AS emp
LEFT JOIN sales_rep AS mgr
  ON emp.manager_id = mgr.rep_id;
```

The aliases `emp` and `mgr` let SQL treat one physical table as two logical roles.

**Anti-join** — customers who have *never* made a sale. Start with a LEFT JOIN, then keep only the rows where the right side came back empty:

```sql
SELECT c.customer_name
FROM customers AS c
LEFT JOIN sales AS s
  ON c.customer_id = s.customer_id
WHERE s.customer_id IS NULL;
```

Read it as: line up every customer with their sales; a NULL on the sales side means "no sale exists," so those are exactly the customers we want. This `LEFT JOIN ... WHERE right_key IS NULL` shape is the classic anti-join.

## Watch out

- **CROSS JOIN explodes row counts.** Two modest tables can produce millions of rows. Use it intentionally, never by accident (a missing ON often *becomes* a cross join).
- **The anti-join filter must be in WHERE, on a right-side key that's never NULL in its own table** (like the join key). Test `IS NULL` on the matched column, and make sure it isn't a column that's naturally NULL.
- **Don't filter the right table in WHERE on a LEFT JOIN** unless you want it to behave like an INNER JOIN. A condition like `WHERE s.amount > 100` quietly drops the unmatched (NULL) rows, undoing the LEFT. Put such conditions in the ON clause if you want to keep unmatched rows.
- **RIGHT JOIN is rarely necessary.** Rewriting as LEFT (by swapping table order) is usually clearer.
- **SELF joins need two aliases**, always — otherwise SQL can't tell the two copies apart.

## Practice

1. List every product category paired with every region, producing a complete grid of combinations.
2. Find all sales reps who have never been assigned a single sale (an anti-join).
3. Using a FULL OUTER JOIN (or its emulation in your database), reconcile customers and sales so that customers with no sales *and* sales with no customer both appear.
4. Assuming `sales_rep` has a `manager_id`, list each rep next to the name of their manager.

---
**Prev:** [Joins: Inner & Left](./04-joins-inner-left.md) · **Next:** [Set Operations](./06-set-operations.md)
