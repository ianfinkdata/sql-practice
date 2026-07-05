-- TASK-20260704-03 · S04_payments.sql · 2026-07-04
-- PURPOSE: Silver payments — DEF-013 method normalization to {visa, mastercard, amex, cash, gift}.
-- GROUNDING: DEF-013 v1.1 (method mapping, all 10 raw spellings from the shipped B03 census);
--            RULE-005 (grain preserved), RULE-007 (explicit CASE list, ELSE NULL tripwire)
-- RUN: Get-Content S04_payments.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)
--
-- NOTES:
-- * DEF-013 v1.1 covers all 10 B03 raw spellings; mapped totals must be visa 27,162 ·
--   mastercard 19,068 · cash 11,203 · amex 6,143 · gift 3,087 (= 66,663, zero NULLs).
-- * status is a clean enum; amount/card_last4 are structural — verbatim passthrough.

CREATE OR REPLACE VIEW oakhaven_silver.payments AS
SELECT
  p.payment_id,
  p.order_id,
  p.payment_ts,
  -- DEF-013: payment method normalization (lossy: keeps method_raw; ELSE NULL = unmapped tripwire)
  CASE UPPER(TRIM(p.method))
    WHEN 'VISA'        THEN 'visa'
    WHEN 'MASTERCARD'  THEN 'mastercard'
    WHEN 'MASTER CARD' THEN 'mastercard'
    WHEN 'MC'          THEN 'mastercard'
    WHEN 'AMEX'        THEN 'amex'
    WHEN 'CASH'        THEN 'cash'
    WHEN 'GIFT'        THEN 'gift'
    ELSE NULL
  END AS method,
  p.method AS method_raw,
  p.amount,
  p.status,
  p.card_last4
FROM oakhaven.payments p;
