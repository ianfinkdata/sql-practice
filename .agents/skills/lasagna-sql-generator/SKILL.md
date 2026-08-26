---
name: lasagna-sql-generator
description: >-
  Use when generating, stress-testing, transpiling, or refactoring deeply nested "lasagna" SQL queries
  (legacy multi-layer subquery anti-patterns with nested CASE statements, window functions, and financial
  opportunity sizing) against the Oakhaven database or cloud dialects (Snowflake, BigQuery, Postgres, Databricks).
  Also provides AST parser complexity auditing, TMDL schema pressure-testing, and CTE refactoring workflows.
---

# Lasagna SQL Generator, Parser Stress Suite & Refactoring Engine

This skill provides an automated generator, AST complexity auditor, and refactoring suite for **"Lasagna SQL"**—deeply nested monolithic subquery queries common in legacy enterprise retail environments (Cognos, MicroStrategy, SAP BusinessObjects, legacy Oracle/Teradata stacks).

It includes a verified, end-to-end retail supply chain business model: **Omnichannel Fulfillment Friction, Stockout Opportunity Sizing & SKU Velocity Quadrants** built directly against `project/oakhaven.db`.

---

## 🎯 When to Use This Skill

Activate this skill when:
- **Pressure-testing SQL / TMDL Parsers:** Stress-testing semantic lineage parsers, TMDL compilers, or SQLglot/sqlparse engines against 5–7+ levels of subquery nesting, projection alias chains, and nested `CASE` statements.
- **Generating Complex Retail Business Logic:** Producing multi-tier retail analytics (e.g. recoverable stockout margin on fast-moving runners vs carrying cost penalties on deadstock).
- **Refactoring Legacy SQL to Modern CTEs:** Converting opaque nested subquery anti-patterns into modular, maintainable Common Table Expressions (`WITH ... AS (...)`).
- **Transpiling Across Dialects:** Generating equivalent queries targeted at SQLite, Snowflake, BigQuery, PostgreSQL, or Databricks.

---

## 🚀 CLI Commands & Workflows

Always run commands from the repository root:

### 1. Run Verified Lasagna Query against Oakhaven DB
```bash
python3 scripts/generate_lasagna_query.py --run
```
*(Executes read-only against `project/oakhaven.db` and renders verified priority rankings).*

### 2. Run in Machine-Readable JSON Mode
```bash
python3 scripts/generate_lasagna_query.py --run --json
```

### 3. Generate Modern Refactored CTE Companion
```bash
python3 scripts/generate_lasagna_query.py --style cte --run
```

### 4. Transpile for Cloud Engines (Snowflake / BigQuery / Postgres / Databricks)
```bash
# Generate Snowflake dialect
python3 scripts/generate_lasagna_query.py --dialect snowflake --output /tmp/snowflake_lasagna.sql

# Generate BigQuery dialect
python3 scripts/generate_lasagna_query.py --dialect bigquery --output /tmp/bigquery_lasagna.sql

# Generate Postgres dialect
python3 scripts/generate_lasagna_query.py --dialect postgres --output /tmp/postgres_lasagna.sql
```

### 5. Audit AST Complexity & Parser Stress Score
```bash
# Audit the primary lasagna pattern file
python3 scripts/verify_sql_parser_stress.py

# Audit a custom SQL file
python3 scripts/verify_sql_parser_stress.py --file path/to/query.sql

# Benchmark all analytical query patterns across the portfolio
python3 scripts/verify_sql_parser_stress.py --benchmark-all
```

---

## 🏗️ The 6-Layer Lasagna Architecture

```
Layer 6 (Outer Query):  Executive Action Tags & Priority Ranking (DENSE_RANK)
  ▲
Layer 5 (Subquery 4):   Financial Opportunity Loss Sizing & Deadstock Penalties
  ▲
Layer 4 (Subquery 3):   Multi-Dimensional Quadrant Scoring (3-tier Nested CASE)
  ▲
Layer 3 (Subquery 2):   Ratio Derivations & Category Quartiles (NTILE, AVG OVER)
  ▲
Layer 2 (Subquery 1):   Product Grain Aggregations & Status Metric Rollups
  ▲
Layer 1 (Innermost):    Fact-to-Dimension Enrichment, Cost Cleansing & Delay Flags
```

### Layer Details:
1. **Layer 1 (`l1` - Base Grain)**: Cleanses negative unit costs (`CASE WHEN unit_cost <= 0 THEN unit_price * 0.45`), filters orphan product keys, and computes fulfillment delay flags (`julianday(ship_date) - julianday(order_date) > 7`).
2. **Layer 2 (`l2` - Product Rollup)**: Aggregates total demand, completed units, completed revenue, cancelled revenue loss, returned revenue loss, and realized COGS / gross profit.
3. **Layer 3 (`l3` - Benchmarks & Ratios)**: Computes realized margin percentage, cancellation rate %, return rate %, category revenue quartile (`NTILE(4)`), category margin quartile, and category average cancellation benchmark.
4. **Layer 4 (`l4` - Velocity Quadrants)**: Uses 3-tier nested `CASE` expressions to classify SKUs into:
   - `Top Runner - High Stockout Risk`
   - `Cash Cow - Core Engine`
   - `Volume Driver - Margin Bleeder`
   - `Deadstock - Shelf Space Drag`
   - `Slow Mover - Low Margin`
   - `Niche Specialty`
5. **Layer 5 (`l5` - Opportunity Sizing)**: Models recoverable revenue from shortage cancellations ($`cancelled_loss * (1 - cat_avg_cancel / cancel_rate)`$), recoverable margin, and deadstock holding cost penalty ($`units * cost * 0.18`$).
6. **Layer 6 (Outer Query)**: Assigns strategic operational directives (`EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK`, `LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE`) and ranks by net value at stake.

---

## 📊 Ground-Truth Output (Verified Oakhaven Data)

| Action Rank | Product ID | Product Name | Category | SKU Quadrant | Completed Rev | Margin % | Cancel % | Recov. Margin | Carry Cost Penalty | Net Value at Stake | Strategic Recommendation |
| :---: | :---: | :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | 1 | Canyon Hiking Boots | Footwear | Top Runner - High Stockout Risk | $74,829.45 | 52.80% | 27.78% | **$8,777.63** | $0.00 | $8,777.63 | EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK |
| **2** | 135 | Canyon Backpacks | Camping & Hiking | Top Runner - High Stockout Risk | $77,201.34 | 55.13% | 21.25% | **$5,387.73** | $0.00 | $5,387.73 | EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK |
| **3** | 46 | Backcountry Climbing Shoes | Climbing | Volume Driver - Margin Bleeder | $53,666.31 | 38.37% | 21.43% | **$2,404.63** | $0.00 | $2,404.63 | RENEGOTIATE_COGS & TRIM_DISCOUNTS |
| **4** | 93 | Basecamp Multi-Tool | Accessories | Top Runner - High Stockout Risk | $48,799.00 | 54.90% | 20.93% | **$2,326.62** | $0.00 | $2,326.62 | EXPEDITE_SUPPLY & EXPAND_SAFETY_STOCK |
| **12** | 150 | Summit Sunglasses | Accessories | Deadstock - Shelf Space Drag | $21,939.27 | 24.23% | 27.27% | $1,167.41 | **$2,992.17** | -$1,824.76 | LIQUIDATE_CLEARANCE & REALLOCATE_SHELF_SPACE |

---

## 🧪 AST Parser Vulnerability Checklist

When testing custom SQL parsers or TMDL AST analyzers, verify:
- [x] **Subquery Recursion Depth:** Can the parser handle ≥5 nested `(SELECT ...)` scopes without stack overflow?
- [x] **Alias Lineage Chaining:** Does the parser track column lineage from Layer 1 through Layer 6?
- [x] **Nested CASE Expressions:** Does the evaluator correctly resolve 3-level deep `CASE WHEN ... THEN (CASE WHEN ... END) END` expressions?
- [x] **Subquery Window Placement:** Are `NTILE()` and `AVG() OVER (PARTITION BY ...)` expressions in derived subquery scopes properly isolated from outer window scopes?
- [x] **CTE vs Subquery Semantic Parity:** Does transpilation between nested subqueries and CTEs produce identical AST dependency graphs?
