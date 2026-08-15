# Tabular Editor CLI — Backlog

## P2 — Plan: XMLA Deployment Workflow
**Status:** Backlog  
**Created:** 2025-08-14  
**Description:** Plan out a repeatable workflow for deploying semantic models to Power BI Service / Microsoft Fabric workspaces via `te deploy` and XMLA endpoints. Cover auth options (service principal, interactive, managed identity), dry-run validation, CI/CD integration patterns, and environment variable management for secrets.

---

## P2 — Plan: Script-Based Model Changes (C# / .csx)
**Status:** Backlog  
**Created:** 2025-08-14  
**Description:** Plan out a library of reusable C# scripts (`.csx`) for programmatic TMDL model modifications via `te script`. Candidate operations: bulk-set table/column descriptions, apply formatting strings, add/update DAX measures, enforce naming conventions, stamp lineage tags. Define a `scripts/` directory convention and version-control strategy.

---

## P2 — Plan: Visual-Specific Settings Script & Report Template Engine
**Status:** Completed (Implemented)  
**Created:** 2025-08-14  
**Completed:** 2026-08-15  
**Description:** Implemented `pbip_poc/tools/pbip_report.py` and modular PBIR template library in `pbip_poc/templates/reports/` (Time Series, Comparative, % Change KPI, and Demographic Analysis with North America footprint USA/CAN/MEX & Azure Maps placeholder). The TE CLI manages the SemanticModel layer, while `pbip_report.py` provides AST report inspection, downstream breaking change impact analysis, and template page injection for the `.Report/` layer.

---

## P2 — Plan: Windows 11 Local PBIP Developer Workflow Guide
**Status:** Backlog (Tracked in GitHub Issue #2)  
**Created:** 2026-08-15  
**GitHub Issue:** https://github.com/ianfinkdata/sql-practice/issues/2  
**Description:** Document the complete Windows 11 local developer loop combining terminal CLI tooling (`pbip_report.py` & Tabular Editor CLI in PowerShell or WSL 2) with native Power BI Desktop rendering in a single local loop.

