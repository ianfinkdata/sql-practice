# Report Design Specification — Oakhaven Exploratory Reports

Normative template for report deliverables. Version 1.0 · 2026-07-04 · Owner: Ian.

## Principles

1. **Every number on a report traces to a query file.** A report may only display values
   produced by a promoted gold query (`medallion/c_gold/queries/`) or bronze pack query;
   the report's lineage table (below) makes the mapping explicit and the validator checks it.
2. **Exploratory, not operational.** These reports invite scanning and drill-reading:
   overview first (KPIs), then trends, then breakdowns, then detail/quality notes.
3. **Self-contained.** One HTML file per report: inline CSS/JS, data embedded as a JSON
   block generated from captured query outputs. No CDNs, no external fetches, opens from
   disk in any browser. (Power BI/PBIR versions are a follow-up, not part of this template.)
4. Visual design follows the `dataviz` skill at build time (form heuristics, palette,
   accessibility). The report-designer agent must load that skill before writing chart code.

## Template anatomy (every exploratory report)

```
┌──────────────────────────────────────────────────────┐
│ Title · subtitle (data window) · generated date       │
│ KPI row: 3–5 stat tiles (headline measures)           │
├──────────────────────────────────────────────────────┤
│ Primary trend: time-series chart (the "shape" of the  │
│ subject) + one comparison split (channel/store/tier)  │
├──────────────────────────────────────────────────────┤
│ Breakdowns: 2–4 categorical charts (bar/heatmap),     │
│ sorted by measure, top-N with explicit "other" bucket │
├──────────────────────────────────────────────────────┤
│ Detail table: top/bottom entities, sortable columns   │
├──────────────────────────────────────────────────────┤
│ Notes & lineage: caveats, DEF IDs, query→visual map   │
└──────────────────────────────────────────────────────┘
```

Required footer — the lineage table:

| Visual | Query file | DEF IDs | Captured output ref |
|---|---|---|---|
| (every visual gets a row) | | | |

## The three reports (TASK-20260704-05)

### R1 — Sales Explorer
- KPIs: gross revenue (DEF-004), net revenue (DEF-005), order count, AOV (DEF-006),
  revenue return rate (DEF-008) — full window.
- Trend: monthly gross revenue line, split by channel (STORE/WEB). Expect visible
  seasonality (summer peaks) and the 2020 COVID dip — annotate both.
- Breakdowns: revenue by store (bar), by loyalty tier (bar), promo vs non-promo share.
- Detail: top 15 months by revenue with MoM change.

### R2 — Product & Category Explorer
- KPIs: active products, units sold, product-level gross revenue, median unit margin,
  unit return rate (DEF-007).
- Trend: monthly units by top-5 category (line or small-multiple).
- Breakdowns: category revenue (bar, parent-category rollup), margin distribution,
  price-vs-cost scatter highlighting the ~2% below-cost anomalies (D16) and penny-price
  lines (D17) as called-out discoveries.
- Detail: top/bottom 15 products by revenue with return rate.

### R3 — Data Quality Explorer (bronze → silver)
- KPIs: total rows profiled, dirty patterns tracked (25), % rows affected per top pattern,
  near-dupe candidates resolved (DEF-014).
- Visuals: dirt census bar (per D-pattern counts from the bronze pack), before/after
  examples table (bronze value → silver value, one per transform DEF), sentinel counts,
  known planted anomalies panel (orders-before-signup count, transfer-out orphans).
- This report doubles as the human-readable proof that silver did what the DEFs say.

## Visual rules

- Time on x-axis, always left-to-right, whole business window unless stated.
- Bars sorted by value (not alphabet) unless the axis is ordinal (months, tiers).
- Money formatted `$1,234,567` (0dp at report scale); rates as `12.34%`.
- Every chart has a one-sentence "so what" caption beneath it.
- Color: one categorical palette across all three reports (dataviz skill placeholder
  palette); channel/tier colors consistent between reports.
- No pie charts beyond 2 slices; prefer bars. Tables scroll inside their own container.

## Acceptance criteria (per report)

1. Opens from disk, renders with no console errors, no external requests.
2. Every displayed number matches its captured query output exactly (validator spot-diffs
   at least the KPI row and one chart's underlying series).
3. Lineage table complete — no visual without a query file and DEF citation.
4. Handoff Block present in the task output.
