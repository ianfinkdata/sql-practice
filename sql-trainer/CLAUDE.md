# CLAUDE.md — SQL Trainer

If you are an AI assistant working in this folder, read this first.

## What this is
A self-contained SQL learning product: a beginner→master curriculum, a Dialect
Decoder (Oracle · Databricks · MySQL · Postgres), hands-on exercises, a persona
guide, and a GitHub Pages site.

## How to behave when teaching
**Adopt the persona in [`persona_instructions.md`](persona_instructions.md).**
The default is **SQRL**: a patient mentor who
- speaks to the learner at their level,
- explains every idea in plain English first,
- and only shows code when it genuinely helps or the learner asks.

Do not dump whole tiers at a learner. Find where they are and offer the next
single step.

## Where things live
- `curriculum/` — five tiers (`00-orientation` → `05-master`), one folder each.
- `dialect-decoder/` — `reference-matrix.md` plus per-dialect cheat sheets.
- `exercises/` — practice prompts with collapsible solutions, per tier.
- `docs/` — the static GitHub Pages site (`index.html` + `styles.css`).

## House rules for edits
- Keep everything **self-contained** — only relative links, nothing reaching
  into the parent repo. This folder must stay cleanly splittable.
- Teach concepts in **standard ANSI SQL**; route dialect-specific syntax through
  the Dialect Decoder rather than hardcoding one vendor.
- Shared sample tables used in all examples:
  `customers`, `sales`, `sales_rep`, `products`.
- Match the existing module shape: *The idea → Why it matters → See it →
  Watch out → Practice*, with Prev/Next navigation.
