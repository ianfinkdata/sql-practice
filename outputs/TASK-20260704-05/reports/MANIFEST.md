# MANIFEST — TASK-20260704-05 report templates + 3 exploratory reports

Work lands here; Ian promotes to `reports/` on approval (per IMPLEMENTATION_PLAN.md §4).

| File | What it is |
|---|---|
| `template.html` | Annotated, self-contained skeleton implementing the report-spec anatomy. Reusable artifact, not a fourth report — all values are labeled SAMPLE placeholders. |
| `R1_sales_explorer.html` | KPIs (Q01), monthly gross revenue by channel (Q02, full 180-row series, COVID-dip + seasonality annotations), revenue by store (Q03), revenue by tier (Q13), promo share (Q04), top-15 months MoM (Q05). |
| `R2_product_explorer.html` | KPIs (Q06 + Q14), category rollup (Q08), margin distribution (Q15), price-vs-cost anomaly panel (D16/D17), top/bottom-15 products (Q10). |
| `R3_data_quality.html` | KPIs (B01/Q11/B06), full D1–D25 dirt census (B04), near-dupe + sentinel + planted-anomaly panels, before/after examples (Q12). |
| `MANIFEST.md` | This file (task artifact, not promoted). |

All figures are transcribed verbatim from `medallion/c_gold/EXPECTED_OUTPUTS.md` and
`medallion/a_bronze/EXPECTED_OUTPUTS.md`; every visual carries a lineage-table row citing
query file + DEF ID(s) + capture reference, per `grounding/report-spec.md`.

## Disclosed escalations (not worked around silently)

`medallion/c_gold/queries/Q07_r2_monthly_units_top5_categories.sql` and
`Q09_r2_price_vs_cost.sql` only have AGGREGATE reproducibility-signature captures in
`EXPECTED_OUTPUTS.md`, not the row-level data the report-spec's R2 trend/scatter visuals
need. Substitutes were built from data that IS fully captured (Q08-leaf top-5 bar in place
of the Q07 monthly trend; a catalog-level totals + D16/D17 count panel in place of the Q09
per-product scatter), flagged in-report via a red-bordered escalation box under each affected
chart plus a "Known data gaps" note and explicit "(aggregate signature only)" lineage-row
annotations. Validator independently cross-footed the Q08-leaf substitute against the Q07
aggregate signature (124,694 units / $28,938,760.99 — exact match) confirming it wasn't
fabricated. Recommend commissioning a row-level (or reduced/quarterly) re-capture of Q07/Q09
from `sql-builder` as a follow-up if the original trend/scatter visuals are wanted.

## Handoff Block (report-designer)

```
WHAT: Built outputs/TASK-20260704-05/reports/template.html plus R1_sales_explorer.html,
R2_product_explorer.html, R3_data_quality.html — self-contained exploratory HTML reports per
grounding/report-spec.md, all numbers sourced verbatim from medallion/c_gold/EXPECTED_OUTPUTS.md
and medallion/a_bronze/EXPECTED_OUTPUTS.md (Q01-Q15, B01, B04, B06), with full lineage footers.

GROUNDING: DEF-003, DEF-004, DEF-005, DEF-006, DEF-007, DEF-008, DEF-009, DEF-014, DEF-017,
DEF-018 (n/a — no fulfillment-days visual was in scope), DEF-020, DEF-021; RULE-008 (planted
anomalies surfaced, never hidden); RULE-006/RULE-001 (all figures traced to --batch captures).
dataviz skill loaded before any chart code.

ASSUMPTIONS:
- "Total rows profiled" (R3 KPI) and per-D-id dirt-census totals are arithmetic SUMS of
  already-captured B01/B04 per-table/per-pattern counts, not raw-fact re-aggregation.
- D24/D16 percentages transcribed verbatim from EXPECTED_OUTPUTS.md prose, not computed.
- Money displayed at 0dp per report-spec formatting rule even for small unit-economics
  figures; exact captured value shown in KPI sub-label and embedded JSON.
- Q07/Q09 grain mismatches resolved by building honest, clearly-labeled substitute visuals
  rather than fabricating row-level points (see escalations above).

CONFIDENCE: high on R1 and R3 (fully-captured row-level data, no gaps). Medium on R2's
trend/scatter substitutes specifically; rest of R2 (KPIs, rollup, distribution, top/bottom) high.

QA HINTS:
1. Trace two KPI numbers per report through the lineage table to EXPECTED_OUTPUTS.md verbatim.
2. Open each file directly from disk (file://) and confirm zero console errors / zero network
   requests.
3. Review the two R2 escalation boxes (Q07, Q09 grain mismatch) and decide whether to
   commission a full row-level re-capture from sql-builder, or accept the substitutes.
```

## Validator findings (sql-validator, same session)

VERDICT: PASS WITH WARNINGS, zero blocking issues. Reproduction: every displayed number
spot-checked cell-by-cell against `EXPECTED_OUTPUTS.md` (KPI rows of all 3 reports + one full
chart series + one full detail table per report) — 0 mismatches. Self-containment clean (no
CDNs/fetch/external refs). RULE-008 anomalies surfaced, not hidden. Escalation disclosure
verified honest (Q08-leaf cross-foot against Q07 signature: 124,694 / $28,938,760.99 exact).

Non-blocking warnings:
1. This MANIFEST.md (created after the validator ran) resolves the "no Handoff Block artifact
   on disk" warning — no `process/memory_log.md` entry existed until this session's log pass.
2. R3's "Primary visual" lineage row cites DEF-009 for D6 (loyalty-tier casing), inherited
   verbatim from `medallion/a_bronze/B04_dirt_census.sql`'s header comment, which predates
   DEF-020 (added 2026-07-05). DEF-009's "Applies to" list in `grounding/definitions.md`
   excludes `loyalty_tier`; DEF-020 is the correct grounding for D6 and is not cited in R3.
   Left as-is pending Ian's call (report content edit, not a definitions.md change).
3. Cosmetic: R2's Q10 bottom-15 "Juniper Kids Daypack" transcribed without the captured
   trailing space (invisible in rendering).
4. R2/R3 anomaly-panel lineage rows cite RULE-008/DEF-019 across multi-bar panels without
   per-bar DEF mapping (honest — most bars have no DEF — but could be clearer).
5. Cosmetic: R1's COVID annotation band (chart indices 13-16) vs its label text
   ("2020-02 → 2020-04") differ by one month at the boundary. No displayed number affected.
6. DEF-018 listed as "required" in the brief but unused in all three reports — consistent
   with report-spec's actual per-report KPI/visual lists; likely an over-inclusive brief line.
