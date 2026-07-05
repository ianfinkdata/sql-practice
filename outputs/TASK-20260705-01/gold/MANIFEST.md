# MANIFEST — TASK-20260705-01 gold amendment (DEF-020 + DEF-021)

Work lands here; Ian promotes to `medallion/c_gold/` on approval. Files marked REPLACES are
FULL replacements for their shipped `medallion/c_gold/` counterparts (started from the shipped
content; amendments are additive — every pre-existing column and its SQL is unchanged).
All other shipped c_gold files (G00–G02, G05, G07, G08, G10, G11, V01–V05, Q01–Q12) are
untouched and NOT duplicated here.

| File | Status | What changed |
|---|---|---|
| `ddl/G03_dim_product.sql` | REPLACES `medallion/c_gold/ddl/G03_dim_product.sql` | + `catalog_margin` (DEF-021 companion); header/notes updated |
| `ddl/G04_dim_customer.sql` | REPLACES `medallion/c_gold/ddl/G04_dim_customer.sql` | `loyalty_tier` now DEF-020-normalized; + `loyalty_tier_rank`; raw kept as `loyalty_tier_raw`; header/notes updated |
| `ddl/G06_fact_order_lines.sql` | REPLACES `medallion/c_gold/ddl/G06_fact_order_lines.sql` | + `unit_margin` (DEF-021 realized) via silver products PK join; header/notes updated |
| `ddl/G09_mart_product_performance.sql` | REPLACES `medallion/c_gold/ddl/G09_mart_product_performance.sql` | + `catalog_margin` carried through from dim_product (in SELECT + GROUP BY); header/notes updated |
| `verify/V06_loyalty_tier_census.sql` | NEW | DEF-020 census (B03 totals 7,296/2,583/1,491/630 = 12,000), zero-NULL-leak, RULE-011 binary NO PAD collation, gold-surface census |
| `verify/V07_margin_reconciliation.sql` | NEW | DEF-021 spot reconciliation (3 hand-checkable MIN-PK lines), below-cost censuses (3,534 all-lines / 3,444 revenue-scope / 17 catalog), 0-mismatch bronze recompute |
| `queries/Q13_r1_revenue_by_tier.sql` | NEW | R1 revenue by loyalty tier, ordered by DEF-020 rank |
| `queries/Q14_r2_margin_kpis.sql` | NEW | R2 margin KPIs: median unit margin 103.47 (documented even-count rule), bounds, below-cost count |
| `queries/Q15_r2_margin_distribution.sql` | NEW | R2 margin histogram: deterministic $25 bands anchored at $0 |
| `EXPECTED_OUTPUTS.md` | REPLACES `medallion/c_gold/EXPECTED_OUTPUTS.md` | COMPLETE updated capture set: TASK-04 captures carried over verbatim (regression-proven byte-identical) + V06/V07/Q13–Q15 captures + updated Q06 prose note |
| `MANIFEST.md` | NEW (task artifact, not promoted) | this file |

Not changed by design: `queries/Q09_r2_price_vs_cost.sql` — the R2 scatter needs
unit_cost/list_price/is_below_cost only, all already present (brief: extend only if needed).

Live DB objects changed (CREATE OR REPLACE VIEW in `oakhaven_gold` only):
`dim_product`, `dim_customer`, `fact_order_lines`, `mart_product_performance`.
