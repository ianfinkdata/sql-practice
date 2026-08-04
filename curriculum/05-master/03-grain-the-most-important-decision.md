# 3. Grain: The Most Important Decision in Star Schema Design


<!-- nav -->
Previous: [2. Dimensions and Facts: Core Vocabulary](02-dimensions-and-facts-core-vocabulary.md). Next: [4. Designing a Dimension](04-designing-a-dimension.md).
<!-- /nav -->

## The idea

**Grain** is the precise, one-sentence answer to: "what does a single
row in this fact table represent?" Not "sales data" — that's not a
grain, that's a subject area. A grain is specific enough that anyone
reading it could look at a random row and know exactly what real-world
event it corresponds to: "one row per order line," "one row per daily
account balance snapshot," "one row per web page view."

Grain gets its own lesson because it isn't just *a* decision among
many in star schema design — it's the decision everything else
depends on. Before you know the grain, you don't know:

- **Which foreign keys the fact table needs.** A "one row per order
  line" fact needs `product_id`; a "one row per order" fact doesn't
  (an order can have several products, so product wouldn't fit at that
  grain without losing information).
- **What counts as a measure vs. what has to be derived.** At order-line
  grain, `quantity` is a simple column. At order grain, "quantity" only
  makes sense as `SUM(quantity)` across the order's lines — it's a
  derived aggregate, not a stored value.
- **How to count things correctly.** `COUNT(*)` means something
  completely different depending on the grain — see Example 2.

Declare the grain *first*, in words, before writing a single `CREATE
VIEW`. If you can't state it in one clear sentence, you don't
understand your own design yet — and changing grain after a warehouse
is built and queries depend on it is one of the most expensive mistakes
in data modeling, because every downstream aggregate query has to be
rewritten and re-validated.

## Worked example: `fact_sales`'s actual grain

The `fact_sales` view's own header comment states the grain directly:
*"one row per order line."* Don't take a comment's word for it —
verify it the way you'd verify any grain claim: check that the
declared grain keys are actually unique.

### Verifying the grain

```sql
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id || '-' || order_line_id) AS distinct_order_lines
FROM fact_sales;
```

| total_rows | distinct_order_lines |
|---|---|
| 12000 | 12000 |

Every row's `(order_id, order_line_id)` pair is unique — 12,000 rows,
12,000 distinct combinations. That confirms the grain. As a second
check, confirm the *composite* key is truly required — `order_id`
alone is **not** unique:

```sql
SELECT order_id, order_line_id, COUNT(*)
FROM fact_sales
GROUP BY order_id, order_line_id
HAVING COUNT(*) > 1;
```

This returns zero rows — no duplicate `(order_id, order_line_id)`
pairs exist. And:

```sql
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_orders
FROM fact_sales;
```

| total_rows | distinct_orders |
|---|---|
| 12000 | 7199 |

12,000 rows but only 7,199 distinct `order_id` values — proof that
`order_id` alone under-identifies a row. You need both columns. This
is exactly why the grain statement is "one row per order line," not
"one row per order": the finer-grained key is the one that's actually
unique.

## What breaks if you assume the wrong grain

A very common real-world bug: an analyst assumes a fact table is at
order grain (one row per order) when it's actually at order-line
grain, and uses `COUNT(*)` to count orders.

```sql
SELECT COUNT(*) AS lines_miscounted_as_orders
FROM fact_sales;
```

| lines_miscounted_as_orders |
|---|---|
| 12000 |

That's **12,000**, not the true order count of **7,199** — a 67%
overcount, silently wrong, no error thrown. The fix requires knowing
the grain and counting the *dimension of interest* explicitly:

```sql
SELECT COUNT(DISTINCT order_id) AS true_order_count
FROM fact_sales;
```

| true_order_count |
|---|---|
| 7199 |

This is the single most common grain-related bug in practice: `COUNT(*)`
always counts *rows at the fact table's grain*, never automatically
"orders" or "customers" or whatever business entity you have in mind.

## What would change if the grain were "one row per order" instead

Suppose you decided `fact_sales` should be at order grain rather than
order-line grain. Here's what that forces:

```sql
SELECT order_id, COUNT(*) AS line_count, SUM(net_amount) AS order_net_amount
FROM fact_sales
GROUP BY order_id
ORDER BY line_count DESC
LIMIT 5;
```

| order_id | line_count | order_net_amount |
|---|---|---|
| 7197 | 3 | 715.55 |
| 7191 | 3 | 3456.21 |
| 7184 | 3 | 221.12 |
| 7183 | 3 | -183.87 |
| 7179 | 3 | 3587.43 |

Distribution of lines per order across the whole table:

```sql
SELECT line_count, COUNT(*) AS num_orders
FROM (SELECT order_id, COUNT(*) AS line_count FROM fact_sales GROUP BY order_id)
GROUP BY line_count
ORDER BY line_count;
```

| line_count | num_orders |
|---|---|
| 1 | 3589 |
| 2 | 2419 |
| 3 | 1191 |

At order grain, you'd gain a table that's 40% smaller (7,199 rows
instead of 12,000) and trivially answers "how many orders." But you'd
lose the ability to answer *any* product-level question: `product_id`,
`quantity`, and per-line `unit_price`/`discount_pct` can't fit at
order grain without collapsing information (an order with 3 different
products can't have a single `product_id` column). You'd have to
either drop that analysis entirely, or pre-aggregate it into
derived columns (e.g., `distinct_product_count`,
`SUM(quantity) AS total_units`) — which is strictly *less* information
than the line-grain table preserves. This is the general trade-off of
grain: coarser grain means smaller, simpler, faster-to-query tables,
at the cost of detail you can never get back without rebuilding from
source. Oakhaven's designers chose order-line grain specifically
because product-level analysis ("what sells," "category performance")
is a core use case — see `agg_monthly_sales_by_category` in the gold
layer, which depends on that per-line `product_id`.

## Common mistakes

- **Not stating the grain in words before building the table.** If you
  can't finish the sentence "one row per ___," you don't have a design
  yet, you have a pile of columns.
- **Mixing grains in one fact table.** A table with some rows at
  order-line grain and others aggregated to order grain (e.g., adding
  a "summary" row per order) breaks every `SUM`/`COUNT` downstream,
  because a naive aggregate double-counts the summary alongside the
  detail rows.
- **Using `COUNT(*)` as a stand-in for "count of business entity X"**
  without checking whether the fact table's grain actually matches
  entity X. Always ask "what does one row mean here?" before writing
  `COUNT(*)`.
- **Letting a `JOIN` silently change the effective grain.** Joining a
  fact table to a dimension where the join key isn't actually unique
  in the dimension causes row fan-out — the fact table's *effective*
  grain in the query result becomes finer than its stored grain, and
  `SUM`s inflate. (This is precisely why grain verification — Example
  1 above — matters for dimensions too, not just facts.)

## Key takeaways

- Grain is the first design decision in any star schema, and everything
  else — foreign keys, measures vs. derived aggregates, correct
  counting — follows from it.
- Always verify a claimed grain empirically: check that the declared
  grain key(s) produce zero duplicates via `GROUP BY ... HAVING
  COUNT(*) > 1`, or compare `COUNT(*)` to `COUNT(DISTINCT <key>)`.
- `fact_sales`'s verified grain is **one row per order line**
  — `(order_id, order_line_id)` is unique across all 12,000 rows, while
  `order_id` alone repeats (7,199 distinct values across 12,000 rows).
- `COUNT(*)` counts rows at the fact table's grain, not any particular
  business entity — conflating the two is the most common grain bug in
  practice.
- Coarser grain (e.g., order instead of order line) trades away detail
  you can't recover later; this is a real, permanent cost, not a free
  simplification.

---

<!-- nav -->
Previous: [2. Dimensions and Facts: Core Vocabulary](02-dimensions-and-facts-core-vocabulary.md). Next: [4. Designing a Dimension](04-designing-a-dimension.md).
<!-- /nav -->
