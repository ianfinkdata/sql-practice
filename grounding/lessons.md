# Lessons
Distilled, generalizable rules. Agents must apply every applicable rule; the validator
cites rule IDs when flagging violations.
Format: RULE-nnn | rule | source | date

- RULE-001: Every result-producing query ends with a deterministic ORDER BY including a unique tie-break (PK or full grouping key); no LIMIT without ORDER BY. | project setup (reproducibility law) | 2026-07-04
- RULE-002: Connect to MySQL with the exact Windows command in process/mysql-setup.md — the client does NOT auto-read ~/.my.cnf on Windows, and credentials are never echoed or copied. | oakhaven build session 2026-07-02 | 2026-07-04
- RULE-003: Never derive money from orders.order_total_text; DEF-002 (sum of per-line rounded amounts) is the only order-total truth. The text column is reconciliation/practice material (DEF-016). | CONTRACT §3.9 | 2026-07-04
- RULE-004: Round per line, half-up, 2dp (DEF-001). Sum-then-round is a known trap that produced a $0.03 discrepancy historically (CONTRACT v1.2 note). | CONTRACT v1.2 | 2026-07-04
- RULE-005: Silver flags, never filters — any transform that could lose information keeps the raw column as <name>_raw and/or an is_* flag; row counts must match bronze exactly. | medallion-spec | 2026-07-04
- RULE-006: Captured expected outputs are pasted from an actual --batch run, never typed from memory; the validator re-runs and diffs. | project setup | 2026-07-04
- RULE-007: Controlled-vocabulary mappings (DEF-009/012/013) use explicit CASE lists discovered by census — no LIKE/fuzzy matching; unmapped values go to NULL and must trip the verification query. | project setup | 2026-07-04
- RULE-008: Planted anomalies (orders before signup, movements before intro_date, penny prices, below-cost prices, orphan transfers) are FEATURES — surface them in profiling and reports; never "clean" them away. | CONTRACT D16/D17/D24 + §3.14 | 2026-07-04
- RULE-009: No session-dependent SQL in published queries (NOW/CURDATE/RAND/timezone casts); the window-end constant is '2026-06-30'. | project setup | 2026-07-04
- RULE-010: Multi-line SQL goes through a file piped via Get-Content (PowerShell has no "<" redirection), not -e string quoting, once a query exceeds one line. | oakhaven build session; TASK-02 validator confirmed "<" is a PowerShell parser error | 2026-07-04
- RULE-011: Any distinct-value census, casing check, or GROUP BY over dirty text must use a binary collation (COLLATE utf8mb4_bin / utf8mb4_0900_bin) — the schema default utf8mb4_0900_ai_ci is case-insensitive and silently merges variants (naive `col = UPPER(col)` is always true; GROUP BY merged Visa/VISA/visa). Hit independently by both TASK-01 and TASK-02 builders. | TASK-20260704-01, TASK-20260704-02 | 2026-07-04
- RULE-012: Never ORDER BY a string-literal alias without pinning collation — literals inherit the session connection collation, making row order vary between runs; ORDER BY <alias> COLLATE utf8mb4_bin (or order by a real table column). | TASK-20260704-01 validator (P01 nondeterminism) | 2026-07-04
