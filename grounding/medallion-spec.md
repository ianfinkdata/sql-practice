# Medallion Layer Specification — Oakhaven

Normative rules for what belongs in each layer, how objects are named, and how
reproducibility is enforced. Version 1.0 · 2026-07-04 · Owner: Ian.

## Layer map

| Layer | Where | What it is | Mutability |
|---|---|---|---|
| Bronze | schema `oakhaven` (existing) | Raw source of truth, dirty by design | READ ONLY — never altered by this project |
| Silver | schema `oakhaven_silver` | Cleaned, typed, conformed VIEWS, 1:1 with bronze tables | Views only; rebuilt from `medallion/silver/ddl/` |
| Gold | schema `oakhaven_gold` | Business-ready VIEWS: facts, dims, marts | Views only; rebuilt from `medallion/gold/ddl/` |

## Bronze rules

- Bronze is the `oakhaven` schema exactly as loaded (DATA_CONTRACT v1.2, seed `oakhaven-v1`).
  No bronze objects are created; the bronze DELIVERABLE is a query pack.
- Bronze queries state facts, they don't fix anything: row counts, PK/FK integrity,
  enum censuses, date windows, dirt censuses (contract patterns D1–D25), and the revenue
  ground truth (DEF-002 totals, DEF-016 reconciliation).
- Bronze captured outputs are the reference numbers every silver/gold verification
  reconciles back to.

## Silver rules

- One view per bronze table that has dirt or type problems, SAME NAME as the bronze table
  (the schema name carries the layer): `oakhaven_silver.customers`, `.orders`, `.shipments`,
  `.products`, `.suppliers`, `.employees`, `.payments`, `.returns`, `.inventory_movements`.
  Clean tables (`stores`, `product_categories`, `promotions`, `calendar`) pass through as
  trivial views so silver is a complete, self-sufficient layer.
- **Grain preservation: silver never drops, dedupes, or filters rows.** Row count of every
  silver view = its bronze table, verified.
- Allowed transforms (each citing its DEF): trim/case normalization, sentinel → NULL +
  flag (DEF-017), type casts (DEF-011 dates, DEF-016 money), controlled-vocabulary mapping
  (DEF-009 booleans, DEF-012 states, DEF-013 methods), derived flag columns
  (`is_*`, `canonical_customer_id` per DEF-014).
- Column conventions: cleaned column keeps the bronze name; the raw original is retained
  as `<name>_raw` whenever the transform is lossy (e.g., `order_total` + `order_total_raw`,
  `delivered_date` + `delivered_date_raw`). Flags are TINYINT 0/1 named `is_*`.
- Every silver view ships with a verification query proving: row count parity, zero
  unmapped-to-NULL leaks (DEF-009/012/013), sentinel counts match bronze census.

## Gold rules

- Gold objects are business-named, star-style views:
  - `fact_order_lines` — grain: order line (revenue lines only, DEF-003); line_net_revenue
    (DEF-001), unit margin, return quantities/value joined on.
  - `fact_orders` — grain: order; true total (DEF-002), status, channel, fulfillment (DEF-018).
  - `dim_customer` — grain: canonical customer (DEF-014 collapse happens HERE, not silver).
  - `dim_product`, `dim_store`, `dim_date` (calendar constrained to 2019-01-01…2026-06-30).
  - Marts (pre-aggregated, report-facing): `mart_monthly_sales` (month × store × channel),
    `mart_product_performance`, `mart_category_sales`, `mart_fulfillment`, `mart_returns`.
- Every measure column in gold cites a DEF ID in a `-- DEF-nnn` comment in the view DDL.
- Marts that net returns state their dating policy (DEF-005 caveat) in the header comment.
- Gold verification: mart totals reconcile to the bronze ground-truth pack (e.g., sum of
  `mart_monthly_sales.gross_revenue` = bronze gross revenue to the cent).

## Naming & file layout

```
medallion/
  docs/DATA_DICTIONARY.md
  bronze/  B01_row_counts.sql, B02_integrity.sql, B03_enum_census.sql,
           B04_dirt_census.sql, B05_revenue_ground_truth.sql, ...
           EXPECTED_OUTPUTS.md
  silver/  ddl/S00_create_schema.sql, S01_customers.sql, ...
           verify/V01_row_parity.sql, ...
           EXPECTED_OUTPUTS.md
  gold/    ddl/G00_create_schema.sql, G01_fact_order_lines.sql, ...
           queries/Q01_monthly_sales.sql, ...   ← the report-feeding queries
           EXPECTED_OUTPUTS.md
```
(Work lands in `outputs/TASK-<id>/` first; Ian promotes to `medallion/` on approval.)

Every `.sql` file header:
```sql
-- TASK-<id> · <file> · <date>
-- PURPOSE: <one line>
-- GROUNDING: DEF-nnn, DEF-nnn
-- RUN: Get-Content <file> -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
```

## Reproducibility (the "exact same outputs" law)

1. Deterministic ORDER BY on every result-producing query, with a unique tie-break column
   (PK or full grouping key). No LIMIT without ORDER BY.
2. No session-dependent expressions: no NOW()/CURDATE()/RAND()/UUID(); the business window
   end is the constant `'2026-06-30'`.
3. Derived decimals are ROUND()ed explicitly; averages/rates specify 2dp (or the DEF's dp).
4. Captured outputs come from actually running the query via `--batch` (tab-separated) —
   pasted verbatim into `EXPECTED_OUTPUTS.md` under the query's filename. Wide/long results
   may capture an aggregate signature instead (COUNT + SUM of a money column), stated as such.
5. The validator re-runs every query and diffs stdout against the capture. Any diff = FAIL.
6. Queries reference schemas explicitly (`oakhaven.`, `oakhaven_silver.`, `oakhaven_gold.`)
   so they run without a USE statement.
