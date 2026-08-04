-- =============================================================================
-- PATTERN: Customer lifetime value (LTV) rollup
-- =============================================================================
-- PROBLEM
--   You need one row per customer summarizing their entire order history
--   -- total spend, order count, first/last order date -- for ranking,
--   segmentation, or feeding into a churn/CLV model. Building this from
--   the fact table alone (an INNER JOIN or a bare GROUP BY on fact_sales)
--   drops every customer who has never ordered, which is exactly the
--   population a "which segment underperforms" or "how many customers
--   have zero lifetime value" analysis needs to see.
--
-- WHEN TO REACH FOR IT
--   - Any per-customer summary rollup: LTV, order frequency, average
--     order value, recency.
--   - Ranking/segmentation reports (top N customers, VIP thresholds,
--     RFM-style segmentation) that must include zero-activity customers
--     in the denominator even if they're filtered out of the top of the
--     ranking.
--   - The dimensional-modeling generalization of the date-spine pattern
--     (03-date-dimension-patterns/date-spine-left-join-zero-activity-
--     days.sql): drive FROM the dimension (customers), LEFT JOIN the
--     facts, so "zero" is a real, visible value rather than a missing row.
--
-- HOW IT WORKS
--   FROM the customer dimension (not the fact table), LEFT JOIN
--   fact_sales on customer_id, GROUP BY the customer's dimension
--   attributes. COUNT(DISTINCT order_id) counts orders (not order lines,
--   which can be 1-3 per order); COUNT(order_line_id) counts lines;
--   COALESCE(SUM(net_amount), 0) turns "no matching fact rows" into an
--   explicit 0 rather than NULL, matching the "zero-activity" spine
--   principle used throughout this repo's gold layer.
--
-- REAL EXAMPLE (Oakhaven)
--   project/gold/agg_customer_ltv.sql is exactly this pattern: FROM
--   dim_customer, LEFT JOIN fact_sales, GROUP BY the customer's
--   attributes, with order_count as COUNT(DISTINCT order_id) (order-level,
--   since one order can have 1-3 lines) alongside order_line_count and
--   lifetime_net_amount.
--
-- SAMPLE OUTPUT (real data -- top 5 customers by lifetime value)
--   customer_id  full_name        segment     state  order_count  lifetime_net_amount  first_order_date  last_order_date
--   41           Shannon Strong   Retail      OK     22           37544.43              2021-08-14        2026-03-17
--   343          Jennifer Howard  VIP         IA     25           35024.55              2021-07-04        2026-06-25
--   597          Jessica Simpson  Wholesale   NH     17           33636.42              2021-03-08        2026-06-22
--   173          Ryan Bonilla     Retail      SD     18           31159.38              2021-01-24        2026-05-21
--   67           Derek Roberts    Retail      NY     21           30799.93              2021-02-15        2026-06-05
--
-- PORTABILITY
--   FROM dimension / LEFT JOIN fact / GROUP BY / COALESCE(SUM(...), 0) is
--   standard ANSI SQL -- identical on SQLite, Postgres, Snowflake,
--   BigQuery, and Databricks. COUNT(DISTINCT col) inside an aggregate
--   with a LEFT JOIN is also universally supported and behaves
--   identically (a customer with zero matching fact rows contributes
--   COUNT(DISTINCT NULL) = 0, not an error, on every one of these
--   engines).
-- =============================================================================

-- The LTV rollup pattern itself: dimension-driven, LEFT JOIN to facts,
-- zero-activity customers still get a row (with 0 orders, 0 revenue).
SELECT
    c.customer_id,
    c.full_name,
    c.customer_segment,
    c.state,
    COUNT(DISTINCT f.order_id) AS order_count,          -- order-level (dedupes multi-line orders)
    COUNT(f.order_line_id) AS order_line_count,          -- line-level
    ROUND(COALESCE(SUM(f.net_amount), 0), 2) AS lifetime_net_amount,
    MIN(f.order_date) AS first_order_date,
    MAX(f.order_date) AS last_order_date
FROM dim_customer c
LEFT JOIN fact_sales f ON f.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.customer_segment, c.state
ORDER BY lifetime_net_amount DESC
LIMIT 5;

-- Confirm the mechanism: this LEFT JOIN pattern is what WOULD keep a
-- zero-order customer visible (with 0 orders, 0 revenue) rather than
-- dropping them. In this particular seeded build every one of the 600
-- customers happens to have placed at least one order (verified: this
-- returns 0) -- but the guarantee comes from the LEFT JOIN + COALESCE
-- shape, not from a lucky dataset, so the query stays correct the moment
-- a genuinely inactive customer shows up in a real system.
SELECT COUNT(*) AS zero_activity_customers
FROM agg_customer_ltv
WHERE order_count = 0;
-- -> 0 (this build) -- but see agg_daily_sales' 54 zero-order DAYS in
-- 03-date-dimension-patterns/ for the same principle where the dataset
-- does exercise the zero-activity case.

-- Segment-level LTV summary, built directly on top of the rollup view --
-- this is the payoff of having agg_customer_ltv as a reusable object
-- rather than recomputing the join every time.
SELECT
    customer_segment,
    COUNT(*) AS customers,
    SUM(CASE WHEN order_count = 0 THEN 1 ELSE 0 END) AS zero_order_customers,
    ROUND(AVG(lifetime_net_amount), 2) AS avg_ltv,
    ROUND(SUM(lifetime_net_amount), 2) AS segment_total_ltv
FROM agg_customer_ltv
GROUP BY customer_segment
ORDER BY segment_total_ltv DESC;
