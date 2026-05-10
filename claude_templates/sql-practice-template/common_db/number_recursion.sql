-- ============================================================
-- common_db: integer sequence utility table (1 through 1000)
-- Useful for generating test rows or cross-joining to produce ranges.
-- Adjust the upper bound as needed.
-- ============================================================

USE common_db;

CREATE TABLE numbers AS
WITH RECURSIVE NumberEngine AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM NumberEngine
    WHERE n < 1000
)
SELECT n FROM NumberEngine;

SELECT COUNT(*) AS row_count FROM numbers;
