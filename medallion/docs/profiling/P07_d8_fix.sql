-- TASK-20260704-01 · P07_d8_fix.sql · 2026-07-04
-- PURPOSE: Correct mutually-exclusive census for D8 order_total_text formats (P04's regex overlapped comma/no-comma)
SELECT '--D8 order_total_text mutually exclusive census--' AS marker;
SELECT
  SUM(TRIM(order_total_text) REGEXP '^\\$[0-9]{1,3}(,[0-9]{3})+\\.[0-9]{2}$') AS dollar_with_comma,
  SUM(TRIM(order_total_text) REGEXP '^\\$[0-9]{1,3}\\.[0-9]{2}$' OR TRIM(order_total_text) REGEXP '^\\$[0-9]{4,}\\.[0-9]{2}$') AS dollar_no_comma,
  SUM(TRIM(order_total_text) NOT LIKE '$%') AS no_dollar_sign,
  SUM(order_total_text REGEXP '^ ') AS has_leading_space,
  COUNT(*) AS total
FROM oakhaven.orders;
