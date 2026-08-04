-- =============================================================================
-- PATTERN: Conformed dimension / SCD Type 1 (overwrite-in-place)
-- =============================================================================
-- PROBLEM
--   Most dimensions don't need history -- when a customer's phone number
--   or a product's brand changes, you usually want the CURRENT value
--   everywhere, with no trace of the old value retained. This is "Slowly
--   Changing Dimension Type 1": overwrite in place, one row per entity,
--   always reflecting the latest known state. It's also the "conformed
--   dimension" idea from Kimball-style modeling: one shared, cleaned,
--   business-ready dimension that every fact table references the same
--   way, rather than each fact table carrying its own copy of customer/
--   product attributes duplicated and potentially drifting.
--
-- WHEN TO REACH FOR IT
--   - The default choice for any dimension unless you have a specific,
--     named business need to preserve history (see
--     scd-type-2-history-tracking.sql for when you do need it).
--   - Any dimension multiple fact tables need to reference identically --
--     the whole point of "conformed" is that dim_customer means the exact
--     same thing (same grain, same cleaning rules, same key) whether it's
--     joined from fact_sales, fact_support_tickets, or fact_returns.
--
-- HOW IT WORKS
--   One row per natural key, always reflecting current state. In a view-
--   based warehouse (like this one), Type 1 is almost free: the view
--   simply selects the latest/only version of each row from the cleaned
--   silver layer -- there's no history to manage because nothing is being
--   retained. In a physically materialized warehouse, Type 1 is
--   implemented via UPDATE (or MERGE) on the existing row: match on
--   natural key, overwrite the changed columns, don't insert a new row.
--
-- REAL EXAMPLE (Oakhaven)
--   project/gold/dim_customer.sql, dim_product.sql, and dim_employee.sql
--   are all Type 1 conformed dimensions: one row per customer_id/
--   product_id/employee_id, built once from the corresponding silver
--   view, with no versioning logic. Every gold-layer fact/agg view in
--   this repo (fact_sales, agg_customer_ltv, agg_monthly_sales_by_category,
--   agg_daily_sales) joins to these same three dimensions using the same
--   keys and the same cleaned attribute definitions -- that consistency
--   IS what "conformed" means in practice, not a separate technique.
--
-- SAMPLE OUTPUT (real data)
--   customer_id  full_name       customer_segment  state  is_active
--   1            Michael Cantu   Retail            OH     1
--   2            Ricardo Brooks  VIP               CA     1
--   3            Kevin Potter    Wholesale         TX     0
--
-- PORTABILITY
--   The SELECT-based Type 1 view pattern (below) is standard SQL,
--   identical everywhere. For the MERGE/upsert variant used to Type-1
--   -update a *physically materialized* dimension table, syntax diverges
--   more than almost anywhere else in SQL:
--     - SQLite: no native MERGE. Use `INSERT ... ON CONFLICT(natural_key)
--       DO UPDATE SET col = excluded.col, ...` (SQLite's UPSERT syntax,
--       added in 3.24+).
--     - Postgres: same `INSERT ... ON CONFLICT (key) DO UPDATE SET ...`
--       syntax as SQLite (Postgres is actually where this syntax
--       originated; SQLite's is modeled on it).
--     - Snowflake / Databricks (Delta Lake) / BigQuery: all three support
--       full ANSI `MERGE INTO target USING source ON (target.key =
--       source.key) WHEN MATCHED THEN UPDATE SET ... WHEN NOT MATCHED
--       THEN INSERT ...` -- this is the idiomatic form on modern cloud
--       warehouses and is the closest thing to a portable "Type 1 upsert"
--       across those three.
--   In a view-based (rather than materialized-table) gold layer, as in
--   this repo, none of the above matters -- `CREATE OR REPLACE VIEW` (or
--   SQLite's `DROP VIEW IF EXISTS` + `CREATE VIEW`) always recomputes
--   from source, so there's no "overwrite" step to implement at all. See
--   06-portability-notes/ for the CREATE OR REPLACE VIEW comparison
--   across all five engines.
-- =============================================================================

-- The Type 1 conformed dimension pattern in this repo: one row per
-- customer_id, always the current/only known state, cleaned once in
-- silver and passed straight through in gold.
SELECT
    customer_id,
    full_name,
    customer_segment,
    state,
    is_active
FROM dim_customer
ORDER BY customer_id
LIMIT 3;

-- "Conformed" in action: three different gold-layer objects all join to
-- the exact same dim_customer, by the exact same key, getting identical
-- customer attributes every time -- no per-fact-table redefinition of who
-- a customer is or what "active" means.
SELECT c.customer_segment, COUNT(DISTINCT c.customer_id) AS customers,
       COUNT(DISTINCT f.order_id) AS orders
FROM dim_customer c
LEFT JOIN fact_sales f ON f.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY customers DESC;

-- Illustrative only (not executed against the shared oakhaven.db): the
-- physical-table upsert form of Type 1, for when a dimension is
-- materialized rather than a view (SQLite UPSERT syntax shown; see the
-- portability note above for Postgres/Snowflake/Databricks/BigQuery
-- equivalents):
--
-- INSERT INTO dim_customer_table (customer_id, full_name, customer_segment, state, is_active)
-- SELECT customer_id, full_name, customer_segment, state, is_active FROM silver_customers
-- ON CONFLICT(customer_id) DO UPDATE SET
--     full_name        = excluded.full_name,
--     customer_segment = excluded.customer_segment,
--     state            = excluded.state,
--     is_active        = excluded.is_active;
-- -- Old values are gone the moment this runs -- that's the defining
-- -- trait of Type 1: no history retained, ever.
