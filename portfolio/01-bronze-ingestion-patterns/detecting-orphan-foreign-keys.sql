-- =============================================================================
-- PATTERN: Detecting orphan foreign keys with LEFT JOIN ... WHERE ... IS NULL
-- =============================================================================
-- PROBLEM
--   A child table's "foreign key" column references a parent table, but
--   nothing enforces that at the database level (bronze/raw layers rarely
--   have FK constraints -- see project/bronze/schema.sql, which has none by
--   design). Some child rows point at a parent id that doesn't exist:
--   deleted parent, bad upstream extract, mistyped id, a system that
--   allows free-text ids. You need to find and quantify those orphans
--   before deciding how to handle them downstream (drop, flag, or pass
--   through).
--
-- WHEN TO REACH FOR IT
--   - Any time you're about to build a fact table or dimensional join and
--     want to know the blast radius of missing/bad keys BEFORE it silently
--     shrinks your INNER JOIN results.
--   - Data-quality auditing on newly landed/raw data, especially from
--     systems with no referential integrity (flat file exports, event
--     streams, hand-entered spreadsheets).
--   - As a gate before promoting bronze -> silver: decide explicitly
--     whether orphans get dropped, nulled out, or surfaced as a flag
--     column for downstream consumers to filter on.
--
-- HOW IT WORKS
--   LEFT JOIN child to parent on the FK. Any row where the parent-side
--   join column comes back NULL had no match -- that's your orphan. This
--   is more reliable than `NOT IN (SELECT parent_id FROM parent)` because
--   NOT IN silently returns zero rows (not an error) if the subquery ever
--   produces a NULL, a classic footgun. `NOT EXISTS (...)` is the other
--   safe equivalent and is what project/silver/silver_sales.sql actually
--   uses for its is_customer_orphan / is_product_orphan flags.
--
-- REAL EXAMPLE (Oakhaven)
--   bronze_sales.customer_id and bronze_sales.product_id are both plain
--   INTEGER columns with no FK constraint to bronze_customers /
--   bronze_products. By design, ~1% of order lines reference a
--   customer_id or product_id that doesn't exist in the parent table --
--   simulating a real-world extract where a customer or product was
--   deleted/never synced. silver_sales.sql does NOT drop these rows; it
--   surfaces them via boolean flags (is_customer_orphan, is_product_orphan)
--   so a fact table can carry orphaned rows deliberately and downstream
--   consumers choose whether to filter them.
--
--   Verified against project/oakhaven.db (matches facts_sheet.md exactly):
--     orphan customer_id lines: 103  (0.86% of 12,000)
--     orphan product_id lines:  122  (1.02% of 12,000)
--
-- SAMPLE OUTPUT (real data)
--   order_id  order_line_id  customer_id
--   --------  -------------  -----------
--   97        1              9318
--   97        2              9318
--   190       1              4124
--   190       2              4124
--   190       3              4124
--
-- PORTABILITY
--   LEFT JOIN ... WHERE ... IS NULL and NOT EXISTS (...) are both standard
--   ANSI SQL -- identical on SQLite, Postgres, Snowflake, BigQuery, and
--   Databricks. No dialect differences. The one universal gotcha to
--   remember (not engine-specific): never use `WHERE fk NOT IN (SELECT id
--   FROM parent)` if the parent id column can contain NULL -- on every one
--   of these engines that silently returns zero rows instead of erroring,
--   because `x NOT IN (1, 2, NULL)` evaluates to UNKNOWN for every x.
-- =============================================================================

-- Count orphan customer_id lines in bronze_sales
SELECT COUNT(*) AS orphan_customer_lines
FROM bronze_sales s
LEFT JOIN bronze_customers c ON c.customer_id = s.customer_id
WHERE c.customer_id IS NULL;
-- -> 103

-- Count orphan product_id lines in bronze_sales
SELECT COUNT(*) AS orphan_product_lines
FROM bronze_sales s
LEFT JOIN bronze_products p ON p.product_id = s.product_id
WHERE p.product_id IS NULL;
-- -> 122

-- Inspect the actual orphan rows (not just the count) before deciding how
-- to handle them -- here every line of order 97 shares the same bad
-- customer_id, confirming the orphan is injected at the order-header
-- level, not per line (consistent with facts_sheet.md / data_dictionary.md).
SELECT s.order_id, s.order_line_id, s.customer_id
FROM bronze_sales s
LEFT JOIN bronze_customers c ON c.customer_id = s.customer_id
WHERE c.customer_id IS NULL
LIMIT 5;

-- The NOT EXISTS equivalent (this is what silver_sales.sql actually uses,
-- as a boolean pass-through flag rather than a filter):
--   NOT EXISTS (SELECT 1 FROM bronze_customers c WHERE c.customer_id = s.customer_id) AS is_customer_orphan,
--   NOT EXISTS (SELECT 1 FROM bronze_products  p WHERE p.product_id  = s.product_id ) AS is_product_orphan
-- Flagging (rather than dropping) at the silver layer keeps the row count
-- stable end-to-end and lets a gold-layer fact table, a dashboard filter,
-- or a data-quality report each make their own call on what to do with
-- orphaned rows.
