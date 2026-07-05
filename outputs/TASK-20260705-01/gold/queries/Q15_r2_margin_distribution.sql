-- TASK-20260705-01 · Q15_r2_margin_distribution.sql · 2026-07-05
-- PURPOSE: R2 Product & Category Explorer — margin distribution: banded histogram of realized
--          unit margin (DEF-021) over the DEF-003 revenue lines; negative bands are the
--          below-cost call-out series (RULE-008).
-- GROUNDING: DEF-021 v1.0 (unit margin, line grain), DEF-003 (scope is the fact itself),
--            RULE-008 (below-cost margins surfaced, never filtered); report-spec R2 breakdowns
-- RUN: Get-Content Q15_r2_margin_distribution.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
-- BAND RULE (deterministic edges): fixed $25-wide bands anchored at $0 —
--   band_start = FLOOR(unit_margin / 25) * 25, band = [band_start, band_start + 25).
--   Edges are constants (no data-dependent binning); live range is −239.05 … 340.80 (Q14),
--   so the histogram spans band_start −250 … 325. Only populated bands appear (COUNT ≥ 1).
--   The band is derived in a CTE so the outer GROUP BY is on a real derived-table column
--   (ONLY_FULL_GROUP_BY-safe).
-- NOTE: ORDER BY band_start (numeric, = the full grouping key — RULE-001; no literal-collation
--       risk, RULE-012 n/a). line_share_pct is the COUNT share of all DEF-003 revenue lines.

WITH banded AS (
  SELECT FLOOR(f.unit_margin / 25) * 25 AS band_start                 -- DEF-021 (deterministic $25 edges)
  FROM oakhaven_gold.fact_order_lines f
)
SELECT
  b.band_start,
  CONCAT('[', b.band_start, ', ', b.band_start + 25, ')') AS band_label,
  COUNT(*) AS line_count,                                             -- DEF-003 scope lines in band
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS line_share_pct,
  CASE WHEN b.band_start < 0 THEN 1 ELSE 0 END AS is_below_cost_band  -- RULE-008 call-out series
FROM banded b
GROUP BY b.band_start
ORDER BY b.band_start;
