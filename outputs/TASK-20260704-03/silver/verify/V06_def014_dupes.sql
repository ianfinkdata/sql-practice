-- TASK-20260704-03 · V06_def014_dupes.sql · 2026-07-04
-- PURPOSE: Prove DEF-014 accounts for exactly 150 candidates: resolved + unresolved = 150,
--          every resolved original is a distinct id <= 11850, and all non-candidates carry
--          canonical_customer_id = customer_id with no resolution label.
-- GROUNDING: DEF-014 (rules 1-4 + verification target in its caveat); RULE-001, RULE-011/012
--            (census over the resolution labels under pinned binary collation)
-- RUN: Get-Content V06_def014_dupes.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED: RS1 sums to 150 (phone 134 · unresolved 16 · no email_birth_date row — the fallback
--   matched zero candidates on live data, see EXPECTED_OUTPUTS note); RS2 all assertions hold
--   (candidates_total 150, resolved 134, unresolved 16, resolved_beyond_originals 0,
--   distinct_originals 134, unresolved_not_self 0); RS3 both columns 0.

-- Result set 1: resolution census over the 150 candidates (D7 range)
SELECT dupe_resolution COLLATE utf8mb4_bin AS resolution, COUNT(*) AS n
FROM oakhaven_silver.customers
WHERE customer_id BETWEEN 11851 AND 12000
GROUP BY resolution
ORDER BY resolution;

-- Result set 2: candidate accounting (resolved + unresolved = 150; originals distinct and <= 11850)
SELECT COUNT(*)                                                              AS candidates_total,
       SUM(dupe_resolution <> 'unresolved')                                  AS resolved,
       SUM(dupe_resolution = 'unresolved')                                   AS unresolved,
       SUM(dupe_resolution <> 'unresolved' AND canonical_customer_id > 11850) AS resolved_beyond_originals,
       COUNT(DISTINCT CASE WHEN dupe_resolution <> 'unresolved'
                           THEN canonical_customer_id END)                   AS distinct_originals,
       SUM(dupe_resolution = 'unresolved' AND canonical_customer_id <> customer_id) AS unresolved_not_self
FROM oakhaven_silver.customers
WHERE customer_id BETWEEN 11851 AND 12000;

-- Result set 3: non-candidates (ids <= 11850) must be self-canonical with NULL resolution
SELECT SUM(canonical_customer_id <> customer_id) AS noncandidate_canonical_mismatches,
       SUM(dupe_resolution IS NOT NULL)          AS noncandidate_resolution_labels
FROM oakhaven_silver.customers
WHERE customer_id <= 11850;
