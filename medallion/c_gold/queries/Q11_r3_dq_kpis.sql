-- TASK-20260704-04 · Q11_r3_dq_kpis.sql · 2026-07-05
-- PURPOSE: R3 Data Quality Explorer — KPI row: DEF-014 dupe-resolution census (RS1) and the
--          gold-visible planted-anomalies panel (RS2).
-- GROUNDING: DEF-014 v1.1 (near-dupe resolution), RULE-008 (planted anomalies are features);
--            bronze B04/B06 give the remaining R3 numbers (dirt census, window anomalies) —
--            report-spec principle 1 allows bronze pack captures directly.
-- RUN: Get-Content Q11_r3_dq_kpis.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: RS1/RS2 read oakhaven_silver where gold deliberately has no object (dupe map, whole-
--       order-book anomalies) — the DQ report is the sanctioned bronze→silver proof surface
--       (task brief: silver/_raw access allowed for the DQ report). RS2 ORDER BY literal alias
--       with pinned collation (RULE-012).
-- EXPECTED: RS1 reconciles to silver V06 (134 phone + 16 unresolved of 150 candidates);
--           RS2 reconciles to B06 (below-cost 17, orders-before-signup 24,217) — penny lines
--           are the DEF-003 revenue-scope subset of the B04 D17 census (297 across all orders).

-- RS1: DEF-014 resolution census + collapse arithmetic
SELECT
  (SELECT COUNT(*) FROM oakhaven_silver.customers) AS silver_customers,
  (SELECT COUNT(*) FROM oakhaven_gold.dim_customer) AS canonical_customers,       -- DEF-014
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map) AS dupe_candidates,    -- DEF-014 rule 1
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map
    WHERE dupe_resolution = 'phone') AS resolved_phone,                           -- DEF-014 rule 2
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map
    WHERE dupe_resolution = 'email_birth_date') AS resolved_email_birth_date,     -- DEF-014 rule 3
  (SELECT COUNT(*) FROM oakhaven_silver.customer_dupe_map
    WHERE dupe_resolution = 'unresolved') AS unresolved;                          -- DEF-014 rule 4

-- RS2: planted-anomalies panel (RULE-008 — features, surfaced not fixed)
SELECT 'below_cost_products' AS anomaly,
       (SELECT SUM(is_below_cost) FROM oakhaven_gold.dim_product) AS n            -- D16 (B06 = 17)
UNION ALL
SELECT 'penny_lines_revenue_scope',
       (SELECT COUNT(*) FROM oakhaven_gold.fact_order_lines WHERE unit_price = 0.01)  -- D17, DEF-003 scope
UNION ALL
SELECT 'orders_before_signup',
       (SELECT COUNT(*)
        FROM oakhaven_silver.orders o
        JOIN oakhaven_silver.customers c ON c.customer_id = o.customer_id
        WHERE DATE(o.order_ts) < c.signup_date)                                   -- D24 (B06 = 24,217)
ORDER BY anomaly COLLATE utf8mb4_bin;
