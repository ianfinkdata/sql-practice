-- =============================================================================
-- PATTERN: Star-schema fact table template
-- =============================================================================
-- PROBLEM
--   You need a reusable template for building a fact table on top of a
--   cleaned (silver-layer) transaction table: a clear grain declaration,
--   foreign keys out to every relevant dimension, the measures analysts
--   will actually aggregate, and an explicit, documented decision about
--   what happens when a foreign key doesn't resolve (orphan) or is
--   missing (NULL) -- rather than that decision being made implicitly by
--   whatever JOIN type you happened to pick.
--
-- WHEN TO REACH FOR IT
--   - Any time you're promoting a cleaned transaction/event table into
--     the gold/presentation layer of a dimensional model.
--   - As a checklist template: grain comment, FK columns (unvalidated,
--     pass-through), measure columns (recomputed/trustworthy, not raw),
--     and explicit orphan/NULL-handling flags -- copy this shape, don't
--     freehand a new fact table structure each time.
--
-- HOW IT WORKS
--   1. GRAIN: state it in a comment, explicitly, at the top of the file.
--      "One row per X" is the single most important sentence in a fact
--      table's definition -- everything else (which measures are
--      additive, which joins are safe) follows from getting the grain
--      right and keeping it constant for every row.
--   2. FK COLUMNS: carry the dimension keys straight through from the
--      cleaned layer. Do NOT inner-join to validate them here -- that
--      would silently drop rows and change the grain/row-count contract
--      of the fact table. Validation is a downstream consumer's job (via
--      the orphan-detection pattern in 01-bronze-ingestion-patterns/),
--      not the fact table's.
--   3. MEASURES: use the recomputed, trustworthy values from the silver
--      layer (see recompute-dont-trust-the-total.sql), never a raw stored
--      total.
--   4. ORPHAN/NULL FLAGS: surface data-quality issues as explicit boolean
--      columns (is_customer_orphan, is_product_orphan) or simply leave a
--      FK NULL where the source was NULL (employee_id, datekey) -- both
--      are honest signals a downstream query can filter or report on,
--      instead of a row silently vanishing.
--
-- REAL EXAMPLE (Oakhaven)
--   project/gold/fact_sales.sql: grain = one row per order line. Built
--   from silver_sales (never raw bronze_sales). Carries customer_id,
--   product_id, employee_id, and a derived datekey as FK columns to the
--   four dimensions, none of them validated via JOIN inside the fact
--   view itself. net_amount is silver's recomputed measure, not bronze's
--   order_total. is_customer_orphan/is_product_orphan pass straight
--   through from silver. employee_id stays NULL for the ~10.4% of
--   online/no-rep sales; datekey stays NULL for the ~0.5% of rows with a
--   NULL order_date -- both by design, both verified below to match
--   documented counts exactly.
--
--   Verified against project/oakhaven.db (matches facts_sheet.md exactly):
--     fact_sales rows with NULL employee_id: 1243  (== 12000 - 10757 matched to dim_employee)
--     fact_sales rows with NULL datekey:     58    (== 12000 - 11942 matched to dim_date)
--
-- SAMPLE OUTPUT (real data)
--   order_id  order_line_id  customer_id  product_id  employee_id  datekey   net_amount  is_customer_orphan  is_product_orphan
--   1         1              23           3           32           20240305  859.12      0                   0
--   2         1              417          16                       20211104  309.6       0                   0
--   3         1              523          12          32           20230113  106.14      0                   0
--
-- PORTABILITY
--   The SELECT/CASE/CAST shape is standard SQL, identical everywhere.
--   `strftime('%Y%m%d', date_col)` (SQLite) for deriving a datekey has an
--   equivalent on every engine: Postgres `TO_CHAR(date_col,
--   'YYYYMMDD')::INT`, Snowflake `TO_NUMBER(TO_CHAR(date_col,
--   'YYYYMMDD'))`, BigQuery `CAST(FORMAT_DATE('%Y%m%d', date_col) AS
--   INT64)`, Databricks `date_format(date_col, 'yyyyMMdd')` cast to INT.
--   The CREATE VIEW wrapper itself is the one line that differs
--   syntactically across engines for a *view-based* gold layer -- see
--   06-portability-notes/ for the full CREATE OR REPLACE VIEW comparison.
-- =============================================================================

-- GRAIN: one row per order line (matches silver_sales / bronze_sales
-- exactly -- no fan-out, no aggregation inside the fact table itself).
SELECT
    s.order_id,
    s.order_line_id,
    -- FK columns: passed through unvalidated. An orphan or NULL value
    -- here is a fact about the source data, not something to silently
    -- fix or filter inside the fact table.
    s.customer_id,
    s.product_id,
    s.employee_id,                                          -- NULL = no sales rep (online order)
    CAST(strftime('%Y%m%d', s.order_date) AS INTEGER) AS datekey,  -- NULL propagates if order_date is NULL
    s.order_date,
    s.ship_date,
    -- Measures: trustworthy, recomputed values only.
    s.quantity,
    s.unit_price,
    s.discount_pct,
    s.net_amount,
    s.payment_method,
    s.order_status,
    s.channel,
    -- Explicit data-quality flags, carried through rather than hidden.
    s.is_customer_orphan,
    s.is_product_orphan
FROM silver_sales s
LIMIT 5;

-- Prove the pass-through contract: the fact table's NULL/orphan counts
-- exactly match what silver_sales (and ultimately bronze) documents --
-- nothing was silently dropped or filtered by choosing this JOIN
-- strategy (or lack of one).
SELECT
    SUM(CASE WHEN employee_id IS NULL THEN 1 ELSE 0 END) AS null_employee_id,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN is_customer_orphan THEN 1 ELSE 0 END) AS orphan_customer_rows,
    SUM(CASE WHEN is_product_orphan THEN 1 ELSE 0 END) AS orphan_product_rows
FROM fact_sales;
-- -> 1243 | 58 | 103 | 122  (all matching facts_sheet.md exactly)

-- Contrast: what would happen if you "helpfully" inner-joined every
-- dimension inside the fact view instead of passing FKs through --
-- silently changes the grain guarantee (fewer than 12,000 rows) and
-- hides exactly the orphan/NULL signal a data-quality consumer needs.
-- (Illustrative only -- shows the row-count shrinkage, not something to
-- adopt as the fact table's actual definition.)
SELECT COUNT(*) AS rows_if_inner_joined
FROM silver_sales s
JOIN dim_customer c ON c.customer_id = s.customer_id
JOIN dim_product p ON p.product_id = s.product_id
JOIN dim_employee e ON e.employee_id = s.employee_id;
-- -> fewer than 12000: every orphan and every NULL employee_id row
-- vanishes with no trace, which is exactly the failure mode a
-- pass-through fact table is designed to avoid.
