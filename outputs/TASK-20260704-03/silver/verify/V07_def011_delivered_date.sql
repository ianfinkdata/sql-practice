-- TASK-20260704-03 · V07_def011_delivered_date.sql · 2026-07-04
-- PURPOSE: Prove the DEF-011 parse is exact — parsed NULLs equal raw NULL + 'PENDING' counts
--          exactly, the pending flag matches, and no parseable value fell to NULL.
-- GROUNDING: DEF-011 (parse rule + verification target in its caveat); B04 D10 census
--            (NULL 1840 · PENDING 1165); RULE-001 (single-row aggregate)
-- RUN: Get-Content V07_def011_delivered_date.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: total_rows 29784 · raw_null 1840 · raw_pending 1165 · parsed_null 3005 (= 1840+1165)
--   · pending_flag_sum 1165 · parse_failures 0.

SELECT COUNT(*)                                        AS total_rows,
       SUM(delivered_date_raw IS NULL)                 AS raw_null,
       SUM(delivered_date_raw = 'PENDING')             AS raw_pending,
       SUM(delivered_date IS NULL)                     AS parsed_null,
       SUM(is_delivery_pending)                        AS pending_flag_sum,
       SUM(delivered_date IS NULL
           AND delivered_date_raw IS NOT NULL
           AND delivered_date_raw <> 'PENDING')        AS parse_failures
FROM oakhaven_silver.shipments;
