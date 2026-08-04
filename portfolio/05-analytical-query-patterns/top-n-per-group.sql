-- =============================================================================
-- PATTERN: Top N per group with ROW_NUMBER()
-- =============================================================================
-- PROBLEM
--   You need the top N rows WITHIN EACH group (top 2 products per
--   category by revenue, top 3 customers per segment, best-selling item
--   per region) -- not the overall top N across the whole table. A plain
--   `ORDER BY revenue DESC LIMIT N` gives you the global top N, which
--   might all come from a single group and say nothing about the other
--   groups.
--
-- WHEN TO REACH FOR IT
--   - Any "best/worst N per category" report: top products per category,
--     bottom performers per region, most active customers per segment.
--   - Leaderboard-style output where every group needs representation,
--     not just the globally biggest rows.
--
-- HOW IT WORKS
--   1. Aggregate to the grain you want to rank (e.g. one row per
--      product, summed across all its order lines).
--   2. ROW_NUMBER() OVER (PARTITION BY group_col ORDER BY metric DESC)
--      assigns a 1..N rank independently within each group -- the
--      partition resets the numbering at each group boundary.
--   3. Filter to rn <= N in an outer query (a window function's result
--      can't be filtered in the same SELECT's WHERE clause on most
--      engines, SQLite included, since WHERE is evaluated before window
--      functions -- hence the wrapping subquery/CTE).
--   Use RANK() or DENSE_RANK() instead of ROW_NUMBER() if ties should
--   share a rank (RANK() leaves gaps after ties, e.g. 1,2,2,4;
--   DENSE_RANK() doesn't, e.g. 1,2,2,3) -- ROW_NUMBER() always breaks ties
--   arbitrarily-but-deterministically by whatever the ORDER BY resolves
--   to, which is usually what you want for a strict "exactly N rows per
--   group" output.
--
-- REAL EXAMPLE (Oakhaven)
--   fact_sales joined to dim_product gives revenue per product; grouping
--   by category + product and ranking by total revenue within each
--   category surfaces each category's top sellers -- exactly the kind of
--   "best performer per segment" report a merchandising team would ask
--   for.
--
-- SAMPLE OUTPUT (real data -- top 2 products per category, first 5 categories)
--   category           product_name            total_revenue  rn
--   Accessories        Granite Sunglasse       100832.83      1
--   Accessories        Switchback Multi-Tools  92560.50       2
--   Apparel            Highline Rain Shells    132236.97      1
--   Apparel            Wayfinder Jacket        116059.12      2
--   Camping & Hiking   Highline Backpacks      172340.61      1
--   Camping & Hiking   Canyon Backpacks        144155.10      2
--
-- PORTABILITY
--   ROW_NUMBER()/RANK()/DENSE_RANK() with PARTITION BY are standard ANSI
--   SQL -- identical on SQLite, Postgres, Snowflake, BigQuery, and
--   Databricks. The one meaningful divergence is HOW you filter the
--   window function's result: SQLite/Postgres/Databricks need the
--   wrapping CTE/subquery shown below (WHERE can't reference a window
--   function directly in the same SELECT). BigQuery and Snowflake support
--   `QUALIFY ROW_NUMBER() OVER (...) <= N` to filter in a single pass
--   without the extra subquery layer -- Databricks SQL also supports
--   QUALIFY. Postgres and SQLite do not have QUALIFY, so the CTE-wrap
--   pattern below is the portable choice across all five.
-- =============================================================================

-- Step 1+2: aggregate to product grain, then rank within each category.
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rn
    FROM product_revenue
)
-- Step 3: filter to the top 2 per category.
SELECT category, product_name, total_revenue, rn
FROM ranked
WHERE rn <= 2
ORDER BY category, rn
LIMIT 10;

-- BigQuery/Snowflake/Databricks equivalent using QUALIFY, no wrapping CTE
-- needed for the final filter step (illustrative -- QUALIFY is not valid
-- SQLite syntax, so this comment block is reference-only, not run here):
--
-- SELECT p.category, p.product_name, ROUND(SUM(f.net_amount), 2) AS total_revenue
-- FROM fact_sales f
-- JOIN dim_product p ON p.product_id = f.product_id
-- GROUP BY p.category, p.product_id, p.product_name
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(f.net_amount) DESC) <= 2
-- ORDER BY p.category;
