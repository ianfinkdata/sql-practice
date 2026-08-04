# 10. Capstone: Design a Novel Gold View

## The idea

Every gold object dissected so far in this tier already exists in
`project/gold/`. This module is different: it asks you to design a
gold-style view that **isn't** in this repo — one you invent, grain and
all, to answer a real business question — and then verify it the same
way this whole curriculum has verified everything: run it, look at
real output, sanity-check the numbers.

This is the actual point of the tier. `fact_sales`, `dim_customer`, the
`agg_*` rollups — those are worked examples. The skill being taught is
*designing* a new one from scratch: pick a grain, decide what measures
matter, decide how to join, and defend the result with real numbers.
That's the job, on any dataset, in any warehouse, for the rest of your
career.

## The brief

You'll build a **customer order-frequency segmentation view**: for
each customer, bucket them into a frequency tier based on how many
distinct orders they've placed, then roll that up by `customer_segment`
to see how order frequency distributes across Retail/Wholesale/VIP.
This is a genuinely novel gold-style object — nothing in
`project/gold/` buckets customers by activity level, and it's exactly
the kind of view a real BI team would build to feed a "customer
engagement" dashboard.

**Grain:** one row per `(customer_segment, frequency_tier)` pair.

**Tiers**, based on distinct `order_id` count in `fact_sales`:
- `No Orders` — 0 orders
- `Light (1-8 orders)` — 1 to 8 orders
- `Regular (9-14 orders)` — 9 to 14 orders
- `Frequent (15+ orders)` — 15 or more orders

**Measures:** count of customers in each `(segment, tier)` bucket, and
their average order count.

Start from `dim_customer` (not `fact_sales`) and `LEFT JOIN` order
counts on — the same "start from the dimension so zero-activity rows
still appear" pattern `agg_customer_ltv` and `agg_daily_sales` both use
elsewhere in this repo. Customers with a NULL `customer_segment`
should appear under a literal `'Unknown'` bucket rather than vanishing
from the `GROUP BY`.

Write this as a plain runnable `SELECT` (a CTE chain is fine) — it does
not need to be a persisted `CREATE VIEW`.

## Solve it yourself first

Try building the query before reading further. When you're ready, here
is a verified solution and its real output, run against
`project/oakhaven.db`:

```sql
WITH orders_per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
    FROM fact_sales
    GROUP BY customer_id
),
tiered AS (
    SELECT
        c.customer_id,
        COALESCE(c.customer_segment, 'Unknown') AS customer_segment,
        COALESCE(o.order_count, 0) AS order_count,
        CASE
            WHEN COALESCE(o.order_count, 0) = 0 THEN 'No Orders'
            WHEN o.order_count <= 8 THEN 'Light (1-8 orders)'
            WHEN o.order_count <= 14 THEN 'Regular (9-14 orders)'
            ELSE 'Frequent (15+ orders)'
        END AS frequency_tier
    FROM dim_customer c
    LEFT JOIN orders_per_customer o ON o.customer_id = c.customer_id
)
SELECT
    customer_segment,
    frequency_tier,
    COUNT(*) AS num_customers,
    ROUND(AVG(order_count), 2) AS avg_orders
FROM tiered
GROUP BY customer_segment, frequency_tier
ORDER BY customer_segment,
    CASE frequency_tier
        WHEN 'No Orders' THEN 0
        WHEN 'Light (1-8 orders)' THEN 1
        WHEN 'Regular (9-14 orders)' THEN 2
        ELSE 3
    END;
```

**Expected result (real, verified output — 12 rows):**

| customer_segment | frequency_tier | num_customers | avg_orders |
|---|---|---|---|
| Retail | Light (1-8 orders) | 30 | 6.73 |
| Retail | Regular (9-14 orders) | 105 | 11.6 |
| Retail | Frequent (15+ orders) | 38 | 17.05 |
| Unknown | Light (1-8 orders) | 2 | 6.0 |
| Unknown | Regular (9-14 orders) | 9 | 11.78 |
| Unknown | Frequent (15+ orders) | 3 | 15.33 |
| VIP | Light (1-8 orders) | 31 | 7.06 |
| VIP | Regular (9-14 orders) | 130 | 11.42 |
| VIP | Frequent (15+ orders) | 46 | 17.11 |
| Wholesale | Light (1-8 orders) | 31 | 6.87 |
| Wholesale | Regular (9-14 orders) | 133 | 11.34 |
| Wholesale | Frequent (15+ orders) | 42 | 16.52 |

Notice there's no `No Orders` row at all — every one of the 600
customers in `dim_customer` has placed at least 3 orders (you can
verify this yourself: `MIN(order_count)` across real, non-orphan
customers is 3). That's a genuine, interesting finding this view
surfaces: Oakhaven's customer base, as generated, has no dormant
customers — worth knowing before you build a "win back inactive
customers" dashboard on top of this data and find it empty. This is
exactly the kind of thing you only discover by actually running the
query against real data, not by reasoning about the schema in the
abstract — the entire reason this curriculum insists on verified,
real output at every step.

**Row-count check** (grade yourself against this if the row-by-row
result above doesn't match exactly): the full result has **12 rows**,
and `SUM(num_customers)` across all of them equals **600** — matching
`dim_customer`'s exact row count from the facts sheet.

## The exercise file has more

`exercises/05-master/10-capstone-build-a-novel-gold-view.md` grades you
against the exact table above, plus two more novel-view prompts (cohort
activation rate, and cross-category purchase breadth) each with their
own real, verified solutions for you to check your work against.

## Common mistakes

- **Starting from `fact_sales` instead of `dim_customer`.** Starting
  from the fact table and `GROUP BY customer_id` silently drops every
  customer with zero orders — which happens not to matter for *this*
  particular dataset (there are none), but would silently produce a
  wrong answer on a dataset that does have dormant customers. Always
  start from the dimension when the question is "how do all entities
  in this dimension behave," including the ones with no activity.
- **Forgetting `COALESCE` on `customer_segment`.** `GROUP BY
  customer_segment` alone would put every customer with a NULL segment
  into their own ungrouped-looking `NULL` bucket instead of a visible,
  named `'Unknown'` category — technically correct, but easy to miss
  when eyeballing results.
- **Hardcoding tier boundaries without checking the actual
  distribution first.** The 8/14 breakpoints used here were chosen
  after looking at the real `MIN`/`MAX`/`AVG` order-count distribution
  (3 to 25, averaging ~10.9) — arbitrary boundaries picked without
  looking at the data tend to produce one enormous bucket and several
  empty ones.
- **Skipping verification because "the SQL looks right."** SQL that
  parses and runs without error is not the same as SQL that answers the
  question correctly. Always check the output against a sanity check
  you can compute independently — here, that `SUM(num_customers) = 600`
  and matches `dim_customer`'s known row count.

## Key takeaways

- Designing a novel gold view is the same three-step process as any
  fact/dimension design: pick the grain, decide the measures, decide
  the join strategy (and specifically, whether you're joining to keep
  zero-activity rows or to drop them).
- Verify against a real, independently-checkable number whenever
  possible — here, `SUM(num_customers) = 600` ties back to a fact
  already established in the facts sheet, which makes an accidental
  bug (a dropped customer, a double-counted one) immediately visible.
- A verified query can surprise you — "no dormant customers in this
  dataset" is a finding, not an assumption, and it only shows up once
  you actually run the query against real data.
- This is the whole point of the tier: the specific view above is
  disposable, but the process — grain, measures, join strategy, verify
  against something independently known — is the reusable skill.
