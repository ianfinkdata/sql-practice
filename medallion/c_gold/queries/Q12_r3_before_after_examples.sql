-- TASK-20260704-04 · Q12_r3_before_after_examples.sql · 2026-07-05
-- PURPOSE: R3 Data Quality Explorer — before/after examples table: ONE deterministic example
--          row (lowest PK exhibiting the pattern) per lossy transform DEF, bronze raw value →
--          silver clean value.
-- GROUNDING: DEF-009 (boolean), DEF-010 (phone), DEF-011 (delivered date), DEF-012 (state),
--            DEF-013 (method), DEF-015 (email), DEF-016 (order_total cast, reconciliation-grade),
--            DEF-017 (sentinel); report-spec R3 before/after table
-- RUN: Get-Content Q12_r3_before_after_examples.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- NOTE: reads oakhaven_silver views (which carry <name>_raw beside the clean column) — the
--       sanctioned DQ-report surface per the task brief. Each example is the MIN-PK row
--       matching its pattern (ORDER BY pk LIMIT 1 inside each derived table — deterministic,
--       RULE-001); outer ORDER BY pins collation on the literal alias (RULE-012).

SELECT def_id, transform, pk, raw_value, clean_value
FROM (
  SELECT * FROM (
    SELECT 'DEF-009' AS def_id, 'customers.marketing_opt_in' AS transform,
           CAST(customer_id AS CHAR) AS pk, marketing_opt_in_raw AS raw_value,
           CAST(marketing_opt_in AS CHAR) AS clean_value
    FROM oakhaven_silver.customers
    WHERE UPPER(TRIM(marketing_opt_in_raw)) = 'TRUE'
    ORDER BY customer_id LIMIT 1
  ) ex1
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-010', 'customers.phone',
           CAST(customer_id AS CHAR), phone_raw, phone
    FROM oakhaven_silver.customers
    WHERE phone IS NOT NULL AND phone_raw <> phone
    ORDER BY customer_id LIMIT 1
  ) ex2
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-011', 'shipments.delivered_date',
           CAST(shipment_id AS CHAR), delivered_date_raw, CAST(delivered_date AS CHAR)
    FROM oakhaven_silver.shipments
    WHERE delivered_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
    ORDER BY shipment_id LIMIT 1
  ) ex3
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-012', 'customers.state',
           CAST(customer_id AS CHAR), state_raw, state
    FROM oakhaven_silver.customers
    WHERE CHAR_LENGTH(TRIM(state_raw)) > 2
    ORDER BY customer_id LIMIT 1
  ) ex4
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-013', 'payments.method',
           CAST(payment_id AS CHAR), method_raw, method
    FROM oakhaven_silver.payments
    WHERE UPPER(TRIM(method_raw)) = 'MASTER CARD'
    ORDER BY payment_id LIMIT 1
  ) ex5
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-015', 'customers.email',
           CAST(customer_id AS CHAR), email_raw, email
    FROM oakhaven_silver.customers
    WHERE email IS NULL AND email_raw IS NOT NULL
    ORDER BY customer_id LIMIT 1
  ) ex6
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-016', 'orders.order_total (reconciliation-grade cast)',
           CAST(order_id AS CHAR), order_total_raw, CAST(order_total AS CHAR)
    FROM oakhaven_silver.orders
    WHERE TRIM(order_total_raw) NOT LIKE '$%'
    ORDER BY order_id LIMIT 1
  ) ex7
  UNION ALL
  SELECT * FROM (
    SELECT 'DEF-017', 'products.weight_kg (sentinel)',
           CAST(product_id AS CHAR), CAST(weight_kg_raw AS CHAR), CAST(weight_kg AS CHAR)
    FROM oakhaven_silver.products
    WHERE is_weight_sentinel = 1
    ORDER BY product_id LIMIT 1
  ) ex8
) examples
ORDER BY def_id COLLATE utf8mb4_bin;
