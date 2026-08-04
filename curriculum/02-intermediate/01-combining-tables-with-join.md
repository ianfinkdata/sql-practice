# Combining Tables with JOIN


<!-- nav -->
Previous: [Tier 1 — Beginner](../01-beginner/README.md). Next: [LEFT JOIN and Missing Data](02-left-join-and-missing-data.md).
<!-- /nav -->

## The idea

So far every query you've written has looked at one table at a time.
Real questions rarely stay inside one table. "What did Lisa Phelps
buy?" needs `bronze_customers` (who Lisa is) *and* `bronze_sales`
(what got sold) *and* `bronze_products` (what the product was called).
A `JOIN` is how you glue rows from two tables together, matched on a
shared value — usually an id column that appears in both.

`INNER JOIN` (often just written `JOIN`) keeps only the rows where a
match was found on **both** sides. If a row on either side has no
partner, it's silently dropped from the result. That word
"silently" is the whole lesson for today — it's convenient until it
isn't.

## Why it matters

Oakhaven's `bronze_sales` table stores `customer_id` and `product_id`
as bare integers — there's no name, no product title, nothing
readable. To answer "which customer bought which product," you have
to join `bronze_sales` to `bronze_customers` and to `bronze_products`
using those id columns.

But here's the catch, straight from `bronze_sales`'s design: about 1%
of rows carry a `customer_id` or `product_id` that doesn't exist in
the matching table (an intentional "orphan" foreign key, simulating
bad upstream data — see `project/docs/data_dictionary.md`). An
`INNER JOIN` will quietly drop every one of those rows from your
result with no warning. Your `COUNT(*)` will just be a little smaller
than you expected, and unless you go looking, you'll never know why.
We'll measure exactly how many rows disappear below, and Module 2
(`LEFT JOIN`) shows you how to catch them instead of losing them.

## Syntax

```sql
SELECT columns
FROM table_a AS a
JOIN table_b AS b
  ON a.shared_column = b.shared_column;
```

- `JOIN` and `INNER JOIN` are the same thing in SQLite; either is fine.
- The `ON` clause says which columns must be equal for two rows to be
  considered a match.
- Table aliases (`AS a`, `AS b`, or just `a`, `b`) let you write short
  prefixes (`a.column`) instead of repeating the full table name —
  essential once a query touches 2+ tables with overlapping column
  names like `customer_id`.
- You can chain multiple `JOIN`s in one query to pull in a third,
  fourth, etc. table.

## Try it

**1. Join sales to customers to get readable names**

```sql
SELECT s.order_id, s.order_line_id, c.first_name, c.last_name,
       s.quantity, s.unit_price
FROM bronze_sales s
JOIN bronze_customers c ON s.customer_id = c.customer_id
LIMIT 5;
```

| order_id | order_line_id | first_name | last_name | quantity | unit_price |
|---|---|---|---|---|---|
| 1 | 1 | Lisa | Phelps | 4 | 306.83 |
| 1 | 2 | Lisa | Phelps | 5 | 241.65 |
| 2 | 1 | Jessica | simpson | 1 | 325.89 |
| 2 | 2 | Jessica | simpson | 2 | 216.68 |
| 3 | 1 | robin | Spencer | 1 | 106.14 |

(Notice `simpson` and `robin` are lowercase — `bronze_customers` names
are messy too. That's Module 6's problem, not today's.)

**2. Chain a second JOIN to add product names**

```sql
SELECT s.order_id, c.first_name || ' ' || c.last_name AS customer,
       p.product_name, s.quantity, s.unit_price
FROM bronze_sales s
JOIN bronze_customers c ON s.customer_id = c.customer_id
JOIN bronze_products p ON s.product_id = p.product_id
LIMIT 5;
```

| order_id | customer | product_name | quantity | unit_price |
|---|---|---|---|---|
| 1 | Lisa Phelps | Trailhead Trekking Pole | 4 | 306.83 |
| 1 | Lisa Phelps | Alpine Water Filters | 5 | 241.65 |
| 2 | Jessica simpson | Switchback Trail Running Shoes | 1 | 325.89 |
| 2 | Jessica simpson | Ironpeak Fleece | 2 | 216.68 |
| 3 | robin Spencer | Canyon Backpack | 1 | 106.14 |

**3. Watch rows disappear — the orphan problem, measured**

```sql
SELECT COUNT(*) FROM bronze_sales;
```

| COUNT(*) |
|---|
| 12000 |

```sql
SELECT COUNT(*) FROM bronze_sales s
JOIN bronze_customers c ON s.customer_id = c.customer_id;
```

| COUNT(*) |
|---|
| 11897 |

12000 − 11897 = **103 rows vanished**, exactly matching the "~1%
orphan `customer_id`" note in the data dictionary. Do the same join
against `bronze_products` instead:

```sql
SELECT COUNT(*) FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id;
```

| COUNT(*) |
|---|
| 11878 |

Another 122 rows gone (12000 − 11878), this time from orphan
`product_id` values. Join to *both* tables in the same query and both
kinds of loss stack up — you'd be down to roughly 11,780-ish rows
without ever writing a `WHERE` clause that meant to exclude anything.

**4. Filter after joining, same as any other query**

Once tables are joined, `WHERE`, `ORDER BY`, and `LIMIT` all work
exactly as before — they just see the combined, wider row.

```sql
SELECT s.order_id, p.product_name, p.category, s.quantity
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
WHERE p.category = 'Climbing'
ORDER BY s.order_id
LIMIT 5;
```

## Common mistakes

- **Forgetting the `ON` clause (or writing `JOIN` with a comma and no
  `ON`).** SQLite will happily compute the *cross join* — every row of
  table A paired with every row of table B. On `bronze_sales`
  (12,000 rows) × `bronze_customers` (600 rows) that's 7.2 million
  rows. If a join result looks enormous, this is almost always why.
- **Joining on the wrong pair of columns**, e.g.
  `ON s.customer_id = c.employee_id`. SQLite won't error — it'll just
  return zero or nonsense rows, because the values don't line up
  semantically even if the types match.
- **Assuming `INNER JOIN` returns "all the data."** As shown above, it
  returns only the *matched* data. If you need to know what didn't
  match, `INNER JOIN` is the wrong tool — that's Module 2.
- **Not aliasing tables once you have two or more.** `customer_id`
  exists in both `bronze_sales` and `bronze_customers`; write
  `s.customer_id` or `c.customer_id`, not a bare `customer_id`, once
  there's any ambiguity.

## Key takeaways

- `JOIN` (= `INNER JOIN`) combines rows from two tables where the `ON`
  condition matches on both sides.
- Unmatched rows on *either* side are dropped silently — no error, no
  warning.
- In Oakhaven, joining `bronze_sales` to `bronze_customers` drops 103
  rows (orphan `customer_id`); joining to `bronze_products` drops 122
  rows (orphan `product_id`) — both exactly the "~1%" documented in
  `project/docs/data_dictionary.md`.
- Always alias your tables once a query touches more than one.
- If you need to see what an `INNER JOIN` would hide, keep reading —
  that's exactly what `LEFT JOIN` (Module 2) is for.

---

<!-- nav -->
Previous: [Tier 1 — Beginner](../01-beginner/README.md). Next: [LEFT JOIN and Missing Data](02-left-join-and-missing-data.md).
<!-- /nav -->
