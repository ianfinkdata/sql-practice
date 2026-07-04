-- TASK-20260704-03 · S08_suppliers.sql · 2026-07-04
-- PURPOSE: Silver suppliers — DEF-009 active_flag, DEF-010 phone, DEF-015 contact_email,
--          DEF-017 lead_time_days sentinel policy.
-- GROUNDING: DEF-009 (active_flag), DEF-010 (phone), DEF-015 (contact_email),
--            DEF-017 (lead_time_days = -999 -> NULL + is_lead_time_sentinel);
--            RULE-005 (grain preserved), RULE-007 (country D20 has no mapping DEF — raw)
-- RUN: Get-Content S08_suppliers.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * is_lead_time_sentinel must sum to 2 (bronze B04 D21 census).
-- * country coding mix (D20: US/USA/United States) and the supplier_name near-dup pair have
--   no cleaning DEF — raw passthrough (RULE-007).

CREATE OR REPLACE VIEW oakhaven_silver.suppliers AS
SELECT
  s.supplier_id,
  s.supplier_name,                                      -- near-dup pair (ids 8/16): no DEF — raw passthrough
  s.country,                                            -- D20: no mapping DEF — raw passthrough (RULE-007)
  -- DEF-015: email normalization (lossy: keeps contact_email_raw)
  CASE WHEN LOWER(TRIM(s.contact_email)) IN ('n/a', 'none') OR TRIM(COALESCE(s.contact_email, '')) = '' THEN NULL
       ELSE LOWER(TRIM(s.contact_email)) END AS contact_email,
  s.contact_email AS contact_email_raw,
  -- DEF-010: phone normalization (lossy: keeps phone_raw)
  CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(s.phone, ''), '[^0-9]', '')) >= 10
       THEN RIGHT(REGEXP_REPLACE(s.phone, '[^0-9]', ''), 10)
       ELSE NULL END AS phone,
  s.phone AS phone_raw,
  -- DEF-017: -999 sentinel -> NULL + flag (keeps lead_time_days_raw)
  CASE WHEN s.lead_time_days = -999 THEN NULL ELSE s.lead_time_days END AS lead_time_days,
  s.lead_time_days AS lead_time_days_raw,
  CASE WHEN s.lead_time_days = -999 THEN 1 ELSE 0 END AS is_lead_time_sentinel,  -- DEF-017
  -- DEF-009: boolean normalization (lossy: keeps active_flag_raw; ELSE NULL = unmapped tripwire)
  CASE WHEN UPPER(TRIM(s.active_flag)) IN ('Y', 'YES', '1', 'TRUE')  THEN 1
       WHEN UPPER(TRIM(s.active_flag)) IN ('N', 'NO', '0', 'FALSE') THEN 0
       ELSE NULL END AS active_flag,
  s.active_flag AS active_flag_raw
FROM oakhaven.suppliers s;
