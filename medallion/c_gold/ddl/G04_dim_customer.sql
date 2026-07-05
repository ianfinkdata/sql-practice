-- TASK-20260704-04 · G04_dim_customer.sql · 2026-07-05
-- PURPOSE: Gold dim_customer — canonical-customer grain: the DEF-014 near-dupe collapse
--          happens HERE (silver only flags). Expected 11,866 rows = 12,000 − 134 phone-resolved.
-- GROUNDING: DEF-014 v1.1 (collapse: keep only rows where customer_id = canonical_customer_id);
--            DEF-009/010/012/015/017 (attributes already cleaned in silver); medallion-spec §Gold rules
-- RUN: Get-Content G04_dim_customer.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * A canonical customer is any row that is its own canonical (all 11,850 originals, incl. the
--   134 dupe targets, plus the 16 unresolved candidates per DEF-014 rule 4 — flagged, never guessed).
--   The 134 phone-resolved candidate rows collapse into their originals and do NOT appear here.
-- * Attribute values are taken from the CANONICAL row itself (the original wins; no merging of
--   attribute values across dupe copies — DEF-014 defines id resolution only).
-- * loyalty_tier passes through RAW (20 casing/whitespace variants, B03): there is NO tier
--   normalization DEF (escalated as MISSING DEFINITION in the task handoff; RULE-007 forbids
--   inventing the mapping). The R1 by-tier breakdown is blocked on that DEF.
-- * n_source_ids / is_dupe_survivor quantify the collapse for the R3 DQ report (DEF-014).

CREATE OR REPLACE VIEW oakhaven_gold.dim_customer AS
SELECT
  c.customer_id,                                        -- = canonical_customer_id (DEF-014 grain)
  c.first_name,
  c.middle_name,
  c.last_name,
  c.email,                                              -- DEF-015 (normalized in silver)
  c.phone,                                              -- DEF-010 (normalized in silver)
  c.street_address,
  c.city,                                               -- raw passthrough (no cleaning DEF — RULE-007)
  c.state,                                              -- DEF-012 (normalized in silver)
  c.postal_code,
  c.birth_date,                                         -- DEF-017 (sentinels NULLed in silver)
  c.is_birth_date_sentinel,                             -- DEF-017
  c.is_birth_date_future,                               -- DEF-017
  c.is_age_outlier,                                     -- DEF-017 caveat (kept, flagged)
  c.signup_date,                                        -- orders-before-signup anomaly untouched (RULE-008)
  c.loyalty_tier,                                       -- RAW: no tier-normalization DEF (see NOTES)
  c.marketing_opt_in,                                   -- DEF-009 (normalized 0/1 in silver)
  c.dupe_resolution,                                    -- DEF-014 ('unresolved' for the 16 kept candidates; NULL otherwise)
  m.n_source_ids,                                       -- DEF-014: silver customer_ids collapsing into this row
  CASE WHEN m.n_source_ids > 1 THEN 1 ELSE 0 END AS is_dupe_survivor  -- DEF-014
FROM oakhaven_silver.customers c
JOIN (
  SELECT canonical_customer_id, COUNT(*) AS n_source_ids
  FROM oakhaven_silver.customers
  GROUP BY canonical_customer_id
) m ON m.canonical_customer_id = c.customer_id
WHERE c.customer_id = c.canonical_customer_id;          -- DEF-014 collapse
