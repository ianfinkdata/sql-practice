-- =============================================================================
-- PATTERN: Multi-Layer "Lasagna Query" (Legacy Nested Subquery Pattern)
--          Retail Fulfillment Friction, Stockout Risk & Margin Leakage Sizing
-- =============================================================================
-- PROBLEM
--   Enterprise data warehouses and legacy BI tools (e.g. Cognos, BusinessObjects,
--   MicroStrategy, legacy Oracle/Teradata stacks) frequently generated complex
--   business transformations as monolithic, deeply nested subqueries ("Lasagna SQL")
--   rather than modular CTEs or dimensional views.
--
--   In retail supply chains, executives need to quantify the financial impact
--   of operational fulfillment friction:
--     1. "Runners" (high revenue / high margin) suffering from inventory stockouts
--        and cancellation leakage (lost gross margin).
--     2. "Deadstock" (low velocity / low margin) incurring carrying cost drag
--        and wasting warehouse shelf space.
--     3. "Margin Bleeders" (high volume / low realized margin / high returns).
--
--   Authoring this logic in a legacy environment required nesting 5 to 6 subquery
--   layers, chaining derived aliases, and nesting CASE expressions within window
--   functions.
--
-- WHEN TO REACH FOR IT (OR WHY YOU INHERIT IT)
--   - Legacy SQL AST Parser Stress-Testing: Pressure-testing SQL parsers, TMDL
--     compilers, and column lineage trackers against extreme subquery nesting
--     depth, alias shadowing, and nested CASE expressions.
--   - Reverse-Engineering Legacy BI Reports: Deconstructing generated queries from
--     legacy reporting engines into clean, maintainable modern CTEs.
--   - Retail Supply Chain Friction Sizing: Sizing recoverable margin from stockout
--     cancellations and calculating inventory carrying cost penalties.
--
-- HOW IT WORKS (THE 6 LAYERS)
--   Layer 1 (l1 - Base Grain & Cleansing):
--     Enriches fact_sales with dim_product, fixes negative unit costs via CASE,
--     and computes fulfillment latency flags (ship_date - order_date > 7 days).
--   Layer 2 (l2 - Product Grain Aggregations):
--     Aggregates demand volume, completed revenue, cancellation loss, return loss,
--     realized COGS, and gross profit.
--   Layer 3 (l3 - Ratios & Category Benchmarks):
--     Derives realized margin %, cancellation rate %, return rate %, and computes
--     category revenue/margin quartiles via NTILE(4) and window averages.
--   Layer 4 (l4 - Velocity Quadrant Scoring):
--     Applies 3-tier nested CASE logic across quartiles to assign SKU segments
--     ('Top Runner - High Stockout Risk', 'Deadstock - Shelf Space Drag', etc.).
--   Layer 5 (l5 - Financial Opportunity Loss Sizing):
--     Sizes recoverable shortage revenue/margin against category benchmarks and
--     penalizes deadstock holding carrying cost (18% annualized on COGS).
--   Layer 6 (Outer - Executive Prioritization):
--     Assigns strategic directives (EXPEDITE_SUPPLY, LIQUIDATE_CLEARANCE) and
--     ranks SKUs by net value at stake using DENSE_RANK().
--
-- REAL EXAMPLE (Oakhaven Data)
--   Verified against project/oakhaven.db (Seed 20260630, 12,000 sales lines).
--
-- SAMPLE OUTPUT (Exact Verified Results)
--   action_rank  product_id  product_name         category          sku_quadrant                     completed_rev  margin_%  cancel_%  cat_cancel_%  cancel_loss  recov_margin  carry_cost  net_value  recommendation
--   1            1           Canyon Hiking Boots  Footwear          Top Runner - High Stockout Risk  74829.45       52.80     27.78     16.23         39984.65     8777.63       0.00        8777.63    EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK
--   2            135         Canyon Backpacks     Camping & Hiking  Top Runner - High Stockout Risk  77201.34       55.13     21.25     16.24         41451.35     5387.73       0.00        5387.73    EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK
--   3            46          Backcountry Shoes    Climbing          Volume Driver - Margin Bleeder   53666.31       38.37     21.43     17.07         30802.93     2404.63       0.00        2404.63    RENEGOTIATE_COGS & TRIM_DISCOUNTS
--   4            93          Basecamp Multi-Tool  Accessories       Top Runner - High Stockout Risk  48799.00       54.90     20.93     16.30         19157.66     2326.62       0.00        2326.62    EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK
--   12           150         Summit Sunglasses    Accessories       Deadstock - Shelf Space Drag     21939.27       24.23     27.27     16.30         11977.03     1167.41       2992.17    -1824.76    LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE
--
-- PARSER VULNERABILITY & AST ANALYSIS
--   Why this pattern breaks parsers and lineage analyzers:
--     1. Deep AST Nesting: 6 nested SELECT statements exceed default recursion
--        limits in shallow regex or token-stream parsers.
--     2. Chained Column Aliasing: A column defined in Layer 1 is passed to Layer 2,
--        aggregated, renamed in Layer 3, evaluated in a Layer 4 CASE, multiplied in
--        Layer 5, and ranked in Layer 6.
--     3. Window Functions inside Subqueries: NTILE(4) and AVG() OVER (PARTITION BY)
--        within subquery projections require AST parsers to maintain separate
--        relational scopes per nesting level.
--
-- PORTABILITY
--   - SQLite: Uses `julianday(ship_date) - julianday(order_date)` for day differences
--     and explicit subquery nesting.
--   - Snowflake / Postgres / BigQuery / Databricks:
--       - Date arithmetic: `DATEDIFF('day', order_date, ship_date)` (Snowflake/BigQuery)
--         or `(ship_date - order_date)` (Postgres/Databricks).
--       - Refactoring: Replace nested FROM (...) with standard `WITH l1 AS (...), l2 AS (...)`
--         CTEs for 10x better readability and query optimizer pushdown.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PART 1: THE MONOLITHIC 6-LAYER "LASAGNA QUERY" (Legacy Subquery Anti-Pattern)
-- -----------------------------------------------------------------------------

SELECT 
    action_priority_rank,
    product_id,
    product_name,
    category,
    sku_quadrant,
    completed_revenue,
    realized_margin_pct,
    cancellation_rate_pct,
    category_avg_cancellation_rate,
    cancelled_revenue_loss,
    recoverable_shortage_revenue,
    recoverable_shortage_margin,
    carrying_cost_drag_penalty,
    net_value_at_stake,
    strategic_recommendation
FROM (
    -- Layer 5: Opportunity Sizing & Financial Impact Calculation
    SELECT 
        l4.*,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2)
            ELSE 0.0 
        END AS recoverable_shortage_revenue,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0), 2)
            ELSE 0.0 
        END AS recoverable_shortage_margin,
        CASE 
            WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
            THEN ROUND(l4.completed_units * l4.clean_unit_cost * 0.18, 2)
            ELSE 0.0 
        END AS carrying_cost_drag_penalty,
        ROUND(
            (CASE 
                WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                ELSE 0.0 
             END) - 
            (CASE 
                WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
                THEN l4.completed_units * l4.clean_unit_cost * 0.18
                ELSE 0.0 
             END),
            2
        ) AS net_value_at_stake,
        DENSE_RANK() OVER (
            ORDER BY 
                (CASE 
                    WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                    THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                    ELSE 0.0 
                 END) DESC
        ) AS action_priority_rank,
        CASE 
            WHEN l4.sku_quadrant = 'Top Runner - High Stockout Risk' THEN 'EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK'
            WHEN l4.sku_quadrant = 'Cash Cow - Core Engine' THEN 'PROTECT_ALLOCATION & MAINTAIN_BUFFER'
            WHEN l4.sku_quadrant = 'Volume Driver - Margin Bleeder' THEN 'RENEGOTIATE_COGS & TRIM_DISCOUNTS'
            WHEN l4.sku_quadrant = 'Deadstock - Shelf Space Drag' THEN 'LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE'
            WHEN l4.sku_quadrant = 'Niche Specialty' THEN 'EVALUATE_MINIMUM_ORDER_QTY'
            ELSE 'MONITOR_STANDARD'
        END AS strategic_recommendation
    FROM (
        -- Layer 4: Multi-Dimensional Quadrant Scoring via Nested CASE Logic
        SELECT 
            l3.*,
            CASE 
                WHEN l3.category_revenue_quartile = 1 THEN 
                    CASE 
                        WHEN l3.category_margin_quartile <= 2 THEN 
                            CASE 
                                WHEN l3.cancellation_rate_pct > l3.category_avg_cancellation_rate THEN 'Top Runner - High Stockout Risk'
                                ELSE 'Cash Cow - Core Engine'
                            END
                        ELSE 'Volume Driver - Margin Bleeder'
                    END
                WHEN l3.category_revenue_quartile >= 3 THEN 
                    CASE 
                        WHEN l3.category_margin_quartile >= 3 THEN 
                            CASE 
                                WHEN l3.total_orders < 75 THEN 'Deadstock - Shelf Space Drag'
                                ELSE 'Slow Mover - Low Margin'
                            END
                        ELSE 'Niche Specialty'
                    END
                ELSE 'Core Catalog Standard'
            END AS sku_quadrant
        FROM (
            -- Layer 3: Ratio Derivations & Category Benchmarks via Window Functions
            SELECT 
                l2.*,
                ROUND(l2.realized_gross_profit * 100.0 / NULLIF(l2.completed_revenue, 0), 2) AS realized_margin_pct,
                ROUND(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS cancellation_rate_pct,
                ROUND(l2.returned_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS return_rate_pct,
                ROUND((l2.cancelled_revenue_loss + l2.returned_revenue_loss) * 100.0 / NULLIF(l2.completed_revenue + l2.cancelled_revenue_loss + l2.returned_revenue_loss, 0), 2) AS friction_index,
                NTILE(4) OVER (PARTITION BY l2.category ORDER BY l2.completed_revenue DESC) AS category_revenue_quartile,
                NTILE(4) OVER (PARTITION BY l2.category ORDER BY (l2.realized_gross_profit * 1.0 / NULLIF(l2.completed_revenue, 0)) DESC) AS category_margin_quartile,
                ROUND(AVG(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0)) OVER (PARTITION BY l2.category), 2) AS category_avg_cancellation_rate,
                ROUND(AVG(l2.completed_revenue) OVER (), 2) AS fleet_avg_revenue
            FROM (
                -- Layer 2: Product Grain Aggregations & Status Metric Rollups
                SELECT 
                    l1.product_id,
                    l1.product_name,
                    l1.category,
                    l1.brand,
                    l1.unit_price,
                    l1.clean_unit_cost,
                    COUNT(l1.order_id) AS total_orders,
                    SUM(l1.quantity) AS total_units_demanded,
                    SUM(CASE WHEN l1.order_status = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
                    SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity ELSE 0 END) AS completed_units,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount ELSE 0 END), 2) AS completed_revenue,
                    SUM(CASE WHEN l1.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
                    SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.quantity ELSE 0 END) AS cancelled_units,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.net_amount ELSE 0 END), 2) AS cancelled_revenue_loss,
                    SUM(CASE WHEN l1.order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
                    SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.quantity ELSE 0 END) AS returned_units,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.net_amount ELSE 0 END), 2) AS returned_revenue_loss,
                    SUM(CASE WHEN l1.is_delayed_shipment = 1 THEN 1 ELSE 0 END) AS delayed_shipment_orders,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity * l1.clean_unit_cost ELSE 0 END), 2) AS realized_cogs,
                    ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount - (l1.quantity * l1.clean_unit_cost) ELSE 0 END), 2) AS realized_gross_profit
                FROM (
                    -- Layer 1: Base Fact-to-Dimension Enrichment & Anomaly Cleansing
                    SELECT 
                        s.order_id,
                        s.order_line_id,
                        s.customer_id,
                        s.product_id,
                        p.product_name,
                        p.category,
                        p.brand,
                        p.unit_price,
                        CASE 
                            WHEN p.unit_cost IS NULL OR p.unit_cost <= 0 THEN ROUND(p.unit_price * 0.45, 2)
                            ELSE p.unit_cost 
                        END AS clean_unit_cost,
                        s.order_date,
                        s.ship_date,
                        s.quantity,
                        s.discount_pct,
                        s.net_amount,
                        s.order_status,
                        s.channel,
                        CASE 
                            WHEN s.ship_date IS NOT NULL AND s.order_date IS NOT NULL AND julianday(s.ship_date) - julianday(s.order_date) > 7 THEN 1 
                            ELSE 0 
                        END AS is_delayed_shipment
                    FROM fact_sales s
                    JOIN dim_product p ON s.product_id = p.product_id
                    WHERE s.is_product_orphan = 0
                ) l1
                GROUP BY 
                    l1.product_id,
                    l1.product_name,
                    l1.category,
                    l1.brand,
                    l1.unit_price,
                    l1.clean_unit_cost
            ) l2
        ) l3
    ) l4
) l5
WHERE action_priority_rank <= 10 OR sku_quadrant LIKE '%Deadstock%'
ORDER BY action_priority_rank ASC, recoverable_shortage_margin DESC
LIMIT 15;


-- -----------------------------------------------------------------------------
-- PART 2: MODERN REFACTORED COMPANION QUERY (Clean CTE Modular Pattern)
-- -----------------------------------------------------------------------------
-- Compare this against the lasagna query above: identical semantic output,
-- but each logical step is clearly isolated, testable, and friendly to both
-- human reviewers and SQL query optimizers.

WITH l1_base_fact AS (
    SELECT 
        s.order_id,
        s.order_line_id,
        s.customer_id,
        s.product_id,
        p.product_name,
        p.category,
        p.brand,
        p.unit_price,
        CASE 
            WHEN p.unit_cost IS NULL OR p.unit_cost <= 0 THEN ROUND(p.unit_price * 0.45, 2)
            ELSE p.unit_cost 
        END AS clean_unit_cost,
        s.order_date,
        s.ship_date,
        s.quantity,
        s.discount_pct,
        s.net_amount,
        s.order_status,
        s.channel,
        CASE 
            WHEN s.ship_date IS NOT NULL AND s.order_date IS NOT NULL AND julianday(s.ship_date) - julianday(s.order_date) > 7 THEN 1 
            ELSE 0 
        END AS is_delayed_shipment
    FROM fact_sales s
    JOIN dim_product p ON s.product_id = p.product_id
    WHERE s.is_product_orphan = 0
),
l2_product_agg AS (
    SELECT 
        l1.product_id,
        l1.product_name,
        l1.category,
        l1.brand,
        l1.unit_price,
        l1.clean_unit_cost,
        COUNT(l1.order_id) AS total_orders,
        SUM(l1.quantity) AS total_units_demanded,
        SUM(CASE WHEN l1.order_status = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
        SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity ELSE 0 END) AS completed_units,
        ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount ELSE 0 END), 2) AS completed_revenue,
        SUM(CASE WHEN l1.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
        SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.quantity ELSE 0 END) AS cancelled_units,
        ROUND(SUM(CASE WHEN l1.order_status = 'Cancelled' THEN l1.net_amount ELSE 0 END), 2) AS cancelled_revenue_loss,
        SUM(CASE WHEN l1.order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
        SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.quantity ELSE 0 END) AS returned_units,
        ROUND(SUM(CASE WHEN l1.order_status = 'Returned' THEN l1.net_amount ELSE 0 END), 2) AS returned_revenue_loss,
        SUM(CASE WHEN l1.is_delayed_shipment = 1 THEN 1 ELSE 0 END) AS delayed_shipment_orders,
        ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.quantity * l1.clean_unit_cost ELSE 0 END), 2) AS realized_cogs,
        ROUND(SUM(CASE WHEN l1.order_status = 'Completed' THEN l1.net_amount - (l1.quantity * l1.clean_unit_cost) ELSE 0 END), 2) AS realized_gross_profit
    FROM l1_base_fact l1
    GROUP BY 
        l1.product_id,
        l1.product_name,
        l1.category,
        l1.brand,
        l1.unit_price,
        l1.clean_unit_cost
),
l3_benchmarks AS (
    SELECT 
        l2.*,
        ROUND(l2.realized_gross_profit * 100.0 / NULLIF(l2.completed_revenue, 0), 2) AS realized_margin_pct,
        ROUND(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS cancellation_rate_pct,
        ROUND(l2.returned_orders * 100.0 / NULLIF(l2.total_orders, 0), 2) AS return_rate_pct,
        ROUND((l2.cancelled_revenue_loss + l2.returned_revenue_loss) * 100.0 / NULLIF(l2.completed_revenue + l2.cancelled_revenue_loss + l2.returned_revenue_loss, 0), 2) AS friction_index,
        NTILE(4) OVER (PARTITION BY l2.category ORDER BY l2.completed_revenue DESC) AS category_revenue_quartile,
        NTILE(4) OVER (PARTITION BY l2.category ORDER BY (l2.realized_gross_profit * 1.0 / NULLIF(l2.completed_revenue, 0)) DESC) AS category_margin_quartile,
        ROUND(AVG(l2.cancelled_orders * 100.0 / NULLIF(l2.total_orders, 0)) OVER (PARTITION BY l2.category), 2) AS category_avg_cancellation_rate,
        ROUND(AVG(l2.completed_revenue) OVER (), 2) AS fleet_avg_revenue
    FROM l2_product_agg l2
),
l4_scoring AS (
    SELECT 
        l3.*,
        CASE 
            WHEN l3.category_revenue_quartile = 1 THEN 
                CASE 
                    WHEN l3.category_margin_quartile <= 2 THEN 
                        CASE 
                            WHEN l3.cancellation_rate_pct > l3.category_avg_cancellation_rate THEN 'Top Runner - High Stockout Risk'
                            ELSE 'Cash Cow - Core Engine'
                        END
                    ELSE 'Volume Driver - Margin Bleeder'
                END
            WHEN l3.category_revenue_quartile >= 3 THEN 
                CASE 
                    WHEN l3.category_margin_quartile >= 3 THEN 
                        CASE 
                            WHEN l3.total_orders < 75 THEN 'Deadstock - Shelf Space Drag'
                            ELSE 'Slow Mover - Low Margin'
                        END
                    ELSE 'Niche Specialty'
                END
            ELSE 'Core Catalog Standard'
        END AS sku_quadrant
    FROM l3_benchmarks l3
),
l5_opportunity_sizing AS (
    SELECT 
        l4.*,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2)
            ELSE 0.0 
        END AS recoverable_shortage_revenue,
        CASE 
            WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
            THEN ROUND(ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0), 2)
            ELSE 0.0 
        END AS recoverable_shortage_margin,
        CASE 
            WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
            THEN ROUND(l4.completed_units * l4.clean_unit_cost * 0.18, 2)
            ELSE 0.0 
        END AS carrying_cost_drag_penalty,
        ROUND(
            (CASE 
                WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                ELSE 0.0 
             END) - 
            (CASE 
                WHEN l4.sku_quadrant IN ('Deadstock - Shelf Space Drag', 'Slow Mover - Low Margin')
                THEN l4.completed_units * l4.clean_unit_cost * 0.18
                ELSE 0.0 
             END),
            2
        ) AS net_value_at_stake,
        DENSE_RANK() OVER (
            ORDER BY 
                (CASE 
                    WHEN l4.cancellation_rate_pct > l4.category_avg_cancellation_rate 
                    THEN ROUND(l4.cancelled_revenue_loss * (1.0 - (l4.category_avg_cancellation_rate / NULLIF(l4.cancellation_rate_pct, 0))), 2) * (l4.realized_margin_pct / 100.0)
                    ELSE 0.0 
                 END) DESC
        ) AS action_priority_rank,
        CASE 
            WHEN l4.sku_quadrant = 'Top Runner - High Stockout Risk' THEN 'EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK'
            WHEN l4.sku_quadrant = 'Cash Cow - Core Engine' THEN 'PROTECT_ALLOCATION & MAINTAIN_BUFFER'
            WHEN l4.sku_quadrant = 'Volume Driver - Margin Bleeder' THEN 'RENEGOTIATE_COGS & TRIM_DISCOUNTS'
            WHEN l4.sku_quadrant = 'Deadstock - Shelf Space Drag' THEN 'LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE'
            WHEN l4.sku_quadrant = 'Niche Specialty' THEN 'EVALUATE_MINIMUM_ORDER_QTY'
            ELSE 'MONITOR_STANDARD'
        END AS strategic_recommendation
    FROM l4_scoring l4
)
SELECT 
    action_priority_rank,
    product_id,
    product_name,
    category,
    sku_quadrant,
    completed_revenue,
    realized_margin_pct,
    cancellation_rate_pct,
    category_avg_cancellation_rate,
    cancelled_revenue_loss,
    recoverable_shortage_revenue,
    recoverable_shortage_margin,
    carrying_cost_drag_penalty,
    net_value_at_stake,
    strategic_recommendation
FROM l5_opportunity_sizing
WHERE action_priority_rank <= 10 OR sku_quadrant LIKE '%Deadstock%'
ORDER BY action_priority_rank ASC, recoverable_shortage_margin DESC
LIMIT 15;
