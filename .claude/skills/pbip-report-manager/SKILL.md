---
name: pbip-report-manager
description: >-
  Use when inspecting Power BI Projects (.pbip), parsing or auditing .Report visual definitions (PBIR format),
  checking downstream impact of semantic model changes on report visuals, listing or scaffolding modular report
  templates (time_series, comparative_analysis, kpi_percentage_change, demographic_analysis), or working with
  Tabular Editor CLI and PBIR layouts.
---

# PBIP Report Manager & Template Engine

This skill guides the agent and user through inspecting, auditing, and scaffolding Power BI Project (`.pbip`) report definitions and visual containers using [`pbip_poc/tools/pbip_report.py`](../../pbip_poc/tools/pbip_report.py).

---

## 🎯 When to Use This Skill

Activate this skill when:
- Checking which report visuals reference specific tables, columns, or measures (impact analysis).
- Inspecting page layouts, visual container geometries, and data bindings in `.Report/definition/` files.
- Scaffolding or injecting pre-built, standardized PBIR page templates into existing or new `.pbip` reports.
- Working with the North American demographic analysis footprint (USA, Canada, Mexico) and Azure Maps placeholders.
- Integrating changes between Tabular Editor CLI (`te` on `.SemanticModel`) and downstream report visuals (`.Report`).

---

## 🚀 CLI Commands & Workflows

Always run commands from the repository root:

### 1. List Available Templates
```bash
python3 pbip_poc/tools/pbip_report.py list-templates
```
Available templates in `pbip_poc/templates/reports/`:
- **`time_series`**: Slicer, Sales Trend line chart, Monthly Net Revenue column bars.
- **`comparative_analysis`**: Category Variance bar chart, Region × Category matrix, Product ranking table.
- **`kpi_percentage_change`**: Net Revenue KPI card, MoM Growth % card, Volume vs Target gauge.
- **`demographic_analysis`**: Customer Segment donut, North America Country revenue bar (USA, CAN, MEX), State/Province drilldown table, and Azure Maps / Shape Map placeholder.

---

### 2. Audit Downstream Breaking Changes (Impact Analysis)
Before altering or dropping a column/measure in a semantic model (or deploying via `te deploy`), verify downstream report references:

```bash
# Check impact for a specific column
python3 pbip_poc/tools/pbip_report.py impact dim_customer.state

# Check impact for a table or measure
python3 pbip_poc/tools/pbip_report.py impact fact_sales.net_amount
```

---

### 3. Inspect a Report Definition Tree
Inspect themes, registered pages, visual types, canvas dimensions, and active query bindings:

```bash
python3 pbip_poc/tools/pbip_report.py inspect pbip_poc/projects/flat_sales_all/flat_sales_all.Report
```

---

### 4. Scaffold / Inject a Template Page into a Report
To inject a template page into a target report:

```bash
# Dry run to preview generated GUIDs and visual containers
python3 pbip_poc/tools/pbip_report.py add-page \
  --report pbip_poc/projects/flat_sales_all/flat_sales_all.Report \
  --template demographic_analysis \
  --dry-run

# Live injection
python3 pbip_poc/tools/pbip_report.py add-page \
  --report pbip_poc/projects/flat_sales_all/flat_sales_all.Report \
  --template demographic_analysis \
  --name "North America Executive Demographics"
```

---

## 🗺️ North American Geography & Azure Maps Guide

The `demographic_analysis` template supports the full North American footprint:
- **United States** (50 States + DC)
- **Canada** (10 Provinces + 3 Territories)
- **Mexico** (31 States + CDMX)

### Activating Azure Maps
If Azure Maps is allowed in the Power BI tenant:
1. In Power BI Desktop: **File > Options and settings > Options > Security > "Use Azure Maps visual"**.
2. Change `"visualType": "azureMap"` in `visual.json` (or click the Azure Map visual icon in Desktop).
3. If Azure Maps is restricted, the container safely falls back to standard Shape Maps or the included State/Province summary table without model breakage.
