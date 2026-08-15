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

## P2 — Plan: Visual-Specific Settings Script
**Status:** Backlog  
**Created:** 2025-08-14  
**Description:** Plan out a script (C# via `te script`, or Python if TE CLI doesn't cover Report-layer JSON) to programmatically configure Power BI visual settings across `.Report/definition/` JSON files. Candidate operations: theme enforcement, default interactions, slicer sync groups, visual formatting consistency, page layout standardization. Note: the TE CLI operates on the SemanticModel layer — Report-layer visuals live in separate JSON files and may require a Python script instead.
