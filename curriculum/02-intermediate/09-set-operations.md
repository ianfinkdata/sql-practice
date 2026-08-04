# Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT

## The idea

Every clause you've used so far — `JOIN`, `GROUP BY`, `WHERE` —
combines or filters *columns*. Set operations work differently: they
combine the **row results of two separate `SELECT` statements**,
stacked or compared like mathematical sets.

- **`UNION`** — rows from either query, duplicates removed.
- **`UNION ALL`** — rows from either query, duplicates kept (and
  faster, since it skips the dedup work).
- **`INTERSECT`** — only rows that appear in *both* query results.
- **`EXCEPT`** — rows from the first query that do *not* appear in the
  second.

All four require both `SELECT`s to return the **same number of
columns**, in compatible types. Column names come from the first
`SELECT`.

## Why it matters

"What are all the distinct text values used across `payment_method`
and `channel`?" — stack two single-column queries with `UNION`. "Which
customers are both VIP *and* have bought Climbing gear?" — that's two
independent lists of `customer_id`, combined with `INTERSECT`. "Which
raw `category` strings in `bronze_products` are *not* one of the 8
exact canonical spellings?" — `EXCEPT` answers that in one query,
which is a genuinely useful way to audit exactly how messy a column
is, tying directly back to Module 3 and Module 6.

## Syntax

```sql
SELECT col FROM table_a
UNION            -- or UNION ALL, INTERSECT, EXCEPT
SELECT col FROM table_b;
```

- Both `SELECT`s must return the same number of columns.
- Column names in the result come from the first `SELECT`.
- `ORDER BY` goes once, at the very end, and applies to the combined
  result — not to either `SELECT` individually.
- `UNION`/`INTERSECT`/`EXCEPT` all deduplicate their result by
  default; only `UNION ALL` keeps duplicates.
- Mixing operators in one statement evaluates left to right unless you
  use parentheses to force a specific grouping — parenthesize a
  sub-part if you're combining more than two of these.

## Try it

**1. UNION ALL vs UNION — see the duplicate-removal cost directly**

`bronze_sales.payment_method` and `bronze_sales.channel` are two
different messy text columns, each 12,000 rows long:

```sql
SELECT COUNT(*) FROM (
  SELECT payment_method FROM bronze_sales
  UNION ALL
  SELECT channel FROM bronze_sales
);
```

| COUNT(*) |
|---|
| 24000 |

`UNION ALL` just stacks both — 12,000 + 12,000 = 24,000 rows, no
dedup, nothing surprising.

```sql
SELECT COUNT(*) FROM (
  SELECT payment_method FROM bronze_sales
  UNION
  SELECT channel FROM bronze_sales
);
```

| COUNT(*) |
|---|
| 14 |

`UNION` collapses those 24,000 rows down to the **14 distinct raw
text values** that appear across both columns combined:

```sql
SELECT payment_method AS value FROM bronze_sales
UNION
SELECT channel FROM bronze_sales
ORDER BY value;
```

| value |
|---|
| CC |
| Cash |
| Credit Card |
| Debit Card |
| Gift Card |
| In-Store |
| Online |
| PayPal |
| cash  |
| credit card |
| debit card |
| in store |
| online |
| paypal |

**2. INTERSECT — customers who are both VIP and bought Climbing gear**

```sql
SELECT COUNT(*) FROM bronze_customers WHERE customer_segment = 'VIP';
```

| COUNT(*) |
|---|
| 110 |

```sql
SELECT customer_id FROM bronze_customers WHERE customer_segment = 'VIP'
INTERSECT
SELECT customer_id FROM bronze_sales
  WHERE product_id IN (SELECT product_id FROM bronze_products WHERE category = 'Climbing')
ORDER BY customer_id
LIMIT 10;
```

| customer_id |
|---|
| 11 |
| 16 |
| 20 |
| 22 |
| 25 |
| 29 |
| 32 |
| 40 |
| 44 |
| 46 |

```sql
SELECT COUNT(*) FROM (
  SELECT customer_id FROM bronze_customers WHERE customer_segment = 'VIP'
  INTERSECT
  SELECT customer_id FROM bronze_sales
    WHERE product_id IN (SELECT product_id FROM bronze_products WHERE category = 'Climbing')
);
```

| COUNT(*) |
|---|
| 74 |

74 of the 110 VIP customers bought at least one product from the
exact-cased `'Climbing'` variant. (Same caveat as Module 8's example:
this only catches the one exact spelling of "Climbing" — a fully
correct version would clean `category` first, per Module 6.)

**3. EXCEPT — auditing exactly how messy `category` is**

```sql
SELECT DISTINCT category FROM bronze_products
EXCEPT
SELECT * FROM (
  SELECT 'Footwear' AS category
  UNION ALL SELECT 'Apparel'
  UNION ALL SELECT 'Camping & Hiking'
  UNION ALL SELECT 'Climbing'
  UNION ALL SELECT 'Water Sports'
  UNION ALL SELECT 'Winter Sports'
  UNION ALL SELECT 'Accessories'
  UNION ALL SELECT 'Nutrition & Hydration'
)
ORDER BY category
LIMIT 10;
```

| category |
|---|
| ACCESSORIES |
| ACCESSORIES  |
| APPAREL |
| APPAREL  |
| CAMPING & HIKING |
| CAMPING & HIKING  |
| CAMPING AND HIKING  |
| CLIMBING |
| CLIMBING  |
| Camping and Hiking |

```sql
SELECT COUNT(*) FROM (
  SELECT DISTINCT category FROM bronze_products
  EXCEPT
  SELECT * FROM (
    SELECT 'Footwear' AS category
    UNION ALL SELECT 'Apparel'
    UNION ALL SELECT 'Camping & Hiking'
    UNION ALL SELECT 'Climbing'
    UNION ALL SELECT 'Water Sports'
    UNION ALL SELECT 'Winter Sports'
    UNION ALL SELECT 'Accessories'
    UNION ALL SELECT 'Nutrition & Hydration'
  )
);
```

| COUNT(*) |
|---|
| 32 |

40 total distinct raw `category` strings, minus the 8 that exactly
match a canonical name, leaves 32 "wrong" spellings — `EXCEPT` counted
them in one query, no manual comparison needed. (Notice `ACCESSORIES`
appears to repeat in the sample above — those two rows are byte-different:
one has a trailing space and one doesn't, invisible in a rendered
table but very real to `EXCEPT`'s exact-match comparison. A good
reminder that `TRIM` from Module 6 matters here too.)

**4. Same pattern, `UNION` version — which categories exist that shouldn't**

```sql
SELECT COUNT(*) FROM (
  SELECT DISTINCT category FROM bronze_products
  UNION
  SELECT * FROM (
    SELECT 'Footwear' AS category UNION ALL SELECT 'Apparel'
  )
);
```

Combining `UNION`'s "all distinct values from either side" with a
small reference list is a quick way to sanity-check whether a known
value is even present in your data — if the combined count doesn't
grow versus the raw distinct count, the reference value was already
there.

## Common mistakes

- **Mismatched column counts.** `SELECT a, b FROM t1 UNION SELECT c
  FROM t2` errors immediately — both sides need the same number of
  columns.
- **Reaching for `UNION` when `UNION ALL` is what you meant.** `UNION`
  does a full dedup pass across potentially large result sets — if you
  know there are no duplicates (or don't care), `UNION ALL` is faster
  and clearer about intent.
- **Forgetting set operations deduplicate on the *combined* row, not
  per input query.** `UNION` between two queries that individually
  have no internal duplicates can still produce fewer rows than
  `count(query1) + count(query2)` if the same row appears in both.
- **Putting `ORDER BY` on the first `SELECT` instead of at the very
  end.** `ORDER BY` belongs once, after the last `SELECT` in the
  chain, and sorts the whole combined result — attaching it earlier is
  usually a syntax error or silently ignored depending on the
  database.

## Key takeaways

- `UNION`/`UNION ALL` stack two result sets vertically; `INTERSECT`
  keeps only rows in both; `EXCEPT` keeps rows in the first but not
  the second.
- `UNION` and friends deduplicate; `UNION ALL` doesn't (and is
  cheaper when you don't need dedup).
- Both `SELECT`s need matching column counts/types; the result's
  column names come from the first `SELECT`.
- `EXCEPT` against a small canonical list is a fast, precise way to
  audit exactly which raw values in a messy column don't match what
  you expect — 32 of `bronze_products.category`'s 40 raw variants
  aren't one of the 8 canonical spellings.
- `ORDER BY` goes once, at the end, applying to the whole combined
  result.
