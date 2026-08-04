# 10. Capstone — Combining CTEs and Window Functions


<!-- nav -->
Previous: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md). Next: [Tier 4 — Expert](../04-expert/README.md).
<!-- /nav -->

## The idea

This module doesn't introduce new syntax. It's a deliberate synthesis
exercise: every technique from Modules 1–9 (CTEs, `ROW_NUMBER`/`RANK`,
running totals, `LAG`/`LEAD`, recursive CTEs, time intelligence, the date
spine, silver-layer cleaning, correlated subqueries) is a tool. Real
analytical questions usually need *several* of these tools chained
together, not just one in isolation. This is what that actually looks
like.

The pattern you'll see over and over: **aggregate first, rank second.**
Compute a plain summary in one CTE (revenue per group, counts, totals),
then apply a window function to that summary in a second CTE, then filter
the final result. Trying to do the aggregation and the ranking in the same
`SELECT` doesn't work — window functions run after `GROUP BY`, so you'd be
ranking pre-aggregation rows, not the aggregated result you actually want
to rank.

## Worked example: top product per category by revenue

*Question: for each product category, which single product generated the
most net revenue?* This needs: (1) revenue per product, (2) that revenue
ranked within each product's category, (3) keep only rank 1.

```sql
WITH product_revenue AS (
    SELECT p.category, p.product_id, p.product_name,
           ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT category, product_id, product_name, total_revenue,
           RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS category_rank
    FROM product_revenue
)
SELECT category, product_name, total_revenue
FROM ranked
WHERE category_rank = 1
ORDER BY total_revenue DESC;
```

Verified output — one row per category, all 8 of Oakhaven's canonical
categories represented:

| category | product_name | total_revenue |
|---|---|---|
| Camping & Hiking | Highline Backpacks | 172340.61 |
| Nutrition & Hydration | Foothill Electrolyte Mixes | 154322.60 |
| Water Sports | Ridge Paddles | 138646.07 |
| Climbing | Meridian Chalk Bags | 134818.34 |
| Apparel | Highline Rain Shells | 132236.97 |
| Footwear | Canyon Hiking Boots | 127464.80 |
| Winter Sports | Alpine Snowboards | 117472.48 |
| Accessories | Granite Sunglasse | 100832.83 |

Trace the shape: `product_revenue` is a plain `GROUP BY` — nothing new.
`ranked` takes that *already-aggregated* result and ranks it — this only
works because `product_revenue` already collapsed `fact_sales` down to one
row per product; ranking `fact_sales` order lines directly would rank
individual sales, not products. The final `SELECT` is just a filter.
Three CTEs' (well, two, plus the final query) worth of clarity for a
question that would be genuinely painful to express as nested subqueries.

## Extending it: top 3 per category, with each one's share of the category

Swap `RANK()` for `ROW_NUMBER()` (to get an exact top-N without tie
expansion) and add a second window function — an unordered
`SUM(...) OVER (PARTITION BY category)`, which computes the *whole*
category's total without collapsing rows, letting you compute each
product's percentage contribution in the same pass:

```sql
WITH product_revenue AS (
    SELECT p.category, p.product_id, p.product_name,
           ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT category, product_name, total_revenue,
           SUM(total_revenue) OVER (PARTITION BY category) AS category_total,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rn
    FROM product_revenue
)
SELECT category, product_name, total_revenue,
       ROUND(100.0 * total_revenue / category_total, 1) AS pct_of_category
FROM ranked
WHERE rn <= 3 AND category = 'Climbing'
ORDER BY total_revenue DESC;
```

Verified output:

| category | product_name | total_revenue | pct_of_category |
|---|---|---|---|
| Climbing | Meridian Chalk Bags | 134818.34 | 9.7 |
| Climbing | Alpine Harnesse | 134520.27 | 9.7 |
| Climbing | Highline Harnesse | 132416.20 | 9.5 |

Two different window functions over the *same* partition (`category`) in
the same CTE: one with an `ORDER BY` (`ROW_NUMBER`, for ranking) and one
without (`SUM`, for a partition-wide total that every row in the partition
shares equally). This is a genuinely common combination — "rank within a
group, and also show each row's share of the group's total" — and it only
takes one extra line once you're comfortable with the mechanism.

## Common mistakes

- **Trying to rank and aggregate in a single `SELECT`.** `SELECT category,
  RANK() OVER (...) FROM fact_sales JOIN dim_product ... GROUP BY
  category` doesn't do what you want — window functions see the grouped
  rows, but you'd need the aggregate (`SUM(net_amount)`) computed *before*
  ranking, which is exactly why the aggregation belongs in its own CTE
  first.
- **Forgetting `PARTITION BY` on the second window function in a chained
  example.** An unpartitioned `SUM(total_revenue) OVER ()` computes the
  *grand* total across every category, not each category's own total —
  silently wrong percentages that don't sum to 100% within a group.
- **Using `RANK()` when you specifically want exactly N rows per group.**
  `RANK()` can return more than N rows if there's a tie at the Nth
  position (e.g. `WHERE category_rank <= 3` could return 4 rows if two
  products tie for 3rd). Use `ROW_NUMBER()` instead when the exact count
  matters more than tie-fairness.
- **Not verifying the CTE chain's first step in isolation.** When a
  multi-CTE query produces a suspicious result, run the *first* CTE's
  `SELECT` standalone before assuming the bug is in the window function —
  a wrong join or a duplicated `GROUP BY` key upstream will look like a
  ranking bug downstream.

## Key takeaways

- The recurring capstone pattern: aggregate in one CTE, rank/window that
  aggregate in the next CTE, filter in the final `SELECT` — never try to
  aggregate and window in the same `SELECT`.
- Multiple window functions can share the same `PARTITION BY` in the same
  query to answer compound questions ("rank within group" + "share of
  group total") in one pass.
- `RANK()` can return more rows than expected at a tie boundary;
  `ROW_NUMBER()` guarantees an exact count when ties don't matter to you.
- Every tool from this tier — CTEs, window functions, recursive CTEs, date
  intelligence, the date spine, silver-layer cleaning, correlated
  subqueries — composes with the others. Real analytical SQL is rarely one
  technique in isolation; it's several, chained clearly.

---

<!-- nav -->
Previous: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md). Next: [Tier 4 — Expert](../04-expert/README.md).
<!-- /nav -->
