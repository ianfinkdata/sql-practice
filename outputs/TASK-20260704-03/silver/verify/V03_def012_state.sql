-- TASK-20260704-03 · V03_def012_state.sql · 2026-07-04
-- PURPOSE: Prove DEF-012 maps every bronze state value — post-clean distinct set is exactly
--          {CA, ID, MT, OR, WA} with ZERO NULLs, and counts reconcile to the B03 census.
-- GROUNDING: DEF-012 v1.1 (mapping + verification assertion in its caveat); RULE-007 (tripwire),
--            RULE-011 (census under binary collation), RULE-001/012 (deterministic pinned ORDER BY)
-- RUN: Get-Content V03_def012_state.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- EXPECTED (B03 raw counts rolled up): CA 1723+102+202=2027 · ID 1007+56+99=1162 ·
--   MT 849+44+96=989 · OR 2504+146+289=2939 · WA 4117+252+514=4883 (sum 12000); null_leaks = 0.

-- Result set 1: post-clean census (a NULL group appearing here = unmapped-value leak)
SELECT state COLLATE utf8mb4_bin AS state_clean, COUNT(*) AS n
FROM oakhaven_silver.customers
GROUP BY state_clean
ORDER BY state_clean;

-- Result set 2: explicit leak count (must be 0 — bronze state is NOT NULL)
SELECT COUNT(*) AS state_null_leaks
FROM oakhaven_silver.customers
WHERE state IS NULL;
