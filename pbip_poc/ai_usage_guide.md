# AI Usage & Token Optimization Guide

This guide outlines practical strategies for monitoring usage, managing model rate limits, and optimizing token consumption when working with AI coding assistants (such as Google Antigravity) on Power BI and SQL projects.

---

## 📊 1. Checking Usage & Rate Limits

- **Rate Limits vs Token Limits**: 
  - **Rate Limits (RPM/TPM)**: Constrain how many requests or tokens can be sent per minute.
  - **Context Window Limits**: Constrain how much context (chat history + file contents + tool outputs) can be sent in a single turn.
- **Model Toggling**: If rate limit warnings occur on primary reasoning models (e.g. Gemini Pro / Flash High), toggle to a lighter model variant for simple file checks or formatting tasks.
- **Status & Quotas**: Use your IDE/CLI status panel or account dashboard to monitor daily request volume.

---

## 🛡️ 2. Strategies for Token Optimization

### Strategy A: Centralize SQL Metadata (The Single-File Pattern)
Shredding Power BI metadata across raw `.pbip` JSON files, `.tmdl` definitions, or Power Query M code consumes **20,000 to 50,000+ tokens per context turn**.

**Best Practice:**
- Maintain 1 master `.sql` file per model inside [`sql_queries/`](sql_queries/).
- Use clear commented headers (`-- TABLE: table_name`) to separate tables.
- This allows AI agents to inspect and verify business logic in ~500 tokens instead of processing massive TMDL structures.

### Strategy B: Session Lifecycle Management
AI models process full conversation history on every interaction. As conversations grow long, every new prompt incurs higher latency and token usage.

**Best Practice:**
- **Start a fresh chat session** whenever transitioning to a new project milestone (e.g., switching from writing SQL queries to setting up Power BI models).
- Keep conversations focused on 1 core task at a time.

### Strategy C: Targeted File & Range Inspection
- Instead of asking an agent to scan entire folders, specify exact file paths and line ranges (e.g., `view_file` for lines 1–50 of `fact_sales.sql`).

### Strategy D: Subagent Delegation with Lighter Models
- When launching subagents for research, background searching, or log inspection, assign them faster, lower-overhead models (`flash` or `flash_lite`).
- Reserves high-capacity model quota for complex SQL modeling and DAX architecture.

---

## 📄 Summary Checklist for AI Workflows

- [x] **Centralized SQL**: Model SQL is saved in single files with table headers.
- [x] **Lightweight Summaries**: Readme files serve as Table of Contents to avoid scanning raw data.
- [x] **Targeted Scoping**: Capped PoC query results to 100 rows to avoid large payloads.
- [x] **Clean Sessions**: Reset conversation window when moving between major milestones.
