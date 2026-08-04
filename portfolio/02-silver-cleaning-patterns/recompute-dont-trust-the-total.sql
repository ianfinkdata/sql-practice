-- =============================================================================
-- PATTERN: Recompute derived measures instead of trusting a stored total
-- =============================================================================
-- PROBLEM
--   A source system stores a pre-calculated total/derived column alongside
--   the raw inputs that produced it (quantity, price, discount -> total).
--   In real operational systems these totals routinely drift from their
--   inputs: computed at a different point in the order lifecycle (e.g.
--   before a discount was applied), formatted inconsistently ($-prefixed,
--   padded), left NULL, or replaced with a placeholder string ("TBD",
--   "N/A") when the system couldn't compute it yet. Trusting the stored
--   total instead of recomputing from source columns silently propagates
--   whatever inconsistency exists upstream.
--
-- WHEN TO REACH FOR IT
--   - Any time a table stores both raw components (qty, price, rate) AND
--     a pre-computed result of those components. Treat the stored result
--     as suspect by default -- recompute it in the silver/cleaning layer
--     and keep the raw stored value only as a passthrough audit column,
--     never as the value you aggregate on.
--   - Whenever a "numeric" column is typed TEXT in the source -- that's
--     almost always a tell that it accumulates non-numeric placeholder
--     values (TBD, N/A, "", currency symbols) that a REAL/NUMERIC column
--     couldn't have held in the first place.
--   - Also applies to rate/percentage columns that mix representations
--     (e.g. a discount stored as 0.15 in some rows and 15 in others -- the
--     "whole-number bug" below is the same class of problem: don't trust
--     a stored value's *scale* any more than you trust its presence).
--
-- HOW IT WORKS
--   1. Identify the true source columns for the derived value.
--   2. Recompute directly: net_amount = quantity * unit_price * (1 - discount_pct).
--   3. Fix any input columns with a known scale/format bug BEFORE using
--      them in the recompute (see the discount_pct whole-number fix
--      below) -- a garbage input still produces a garbage recomputed
--      output.
--   4. Keep the original stored value around under a *_raw name for
--      auditing/reconciliation, but never SUM/aggregate it directly.
--
-- REAL EXAMPLE (Oakhaven)
--   bronze_sales.order_total is deliberately untrustworthy: ~57% correct
--   plain text, ~13% correct but "$"-prefixed/padded, ~20% computed
--   PRE-DISCOUNT (stale), ~7% pre-discount stale + "$" formatting, ~2%
--   NULL, and a combined ~0.6% literal "TBD"/"N/A" placeholder strings.
--   silver_sales.sql never reads order_total for arithmetic -- it
--   recomputes net_amount from quantity * unit_price * (1 - discount_pct)
--   every time, and additionally fixes an independent bug: ~0.92% of rows
--   with a nonzero discount store the whole-number form (e.g. 25 instead
--   of 0.25) -- `CASE WHEN discount_pct > 1 THEN discount_pct / 100.0 ELSE
--   discount_pct END` catches and rescales those before the multiply.
--
--   Verified against project/oakhaven.db:
--     SELECT COUNT(*) FROM bronze_sales WHERE discount_pct > 1;  --> 110
--     (matches facts_sheet.md's 110-row / 0.92% figure exactly)
--
-- SAMPLE OUTPUT (real data)
--   -- The discount_pct scale bug, before/after fix:
--   order_id  order_line_id  bronze_discount  fixed_discount
--   21        1              25.0             0.25
--   22        1              25.0             0.25
--   71        1              25.0             0.25
--   145       2              25.0             0.25
--   183       2              15.0             0.15
--
--   -- order_total silently computed PRE-discount (stale) vs. the
--   -- recomputed, trustworthy net_amount -- order_total equals the
--   -- pre-discount subtotal, not the actual net after discount:
--   order_id  quantity  unit_price  discount_pct  order_total  pre_discount_total  net_amount
--   5         3         458.03      0.2           1374.09      1374.09             1099.27
--   6         3         707.80      0.1           2123.40      2123.40             1911.06
--   34        2         337.29      0.15          674.58       674.58              573.39
--
-- PORTABILITY
--   CASE/WHEN arithmetic and CAST are standard ANSI SQL -- identical
--   logic on SQLite, Postgres, Snowflake, BigQuery, and Databricks.
--   Rounding function names are consistent (ROUND) everywhere. The one
--   thing to watch: SQLite is dynamically typed, so `CAST(text_col AS
--   REAL)` silently returns 0.0 for non-numeric text like 'TBD' rather
--   than erroring -- always filter/guard those placeholder strings
--   explicitly (as shown below) rather than relying on the cast to fail.
--   Postgres/Snowflake/BigQuery/Databricks are stricter and will raise a
--   cast error on 'TBD' -- meaning this exact pattern would need a
--   TRY_CAST (Snowflake/Databricks) or SAFE_CAST (BigQuery) to fail soft
--   instead of erroring the whole query; Postgres has no built-in
--   try-cast and needs a CASE guard or a function like `pg_input_error`.
-- =============================================================================

-- The scale bug: ~1% of nonzero discounts are stored as whole numbers
-- (25 meaning 25%) instead of the fractional form (0.25) the rest of the
-- column uses. Left unfixed, this would make net_amount go deeply
-- negative for those rows (1 - 25 = -24).
SELECT b.order_id, b.order_line_id, b.discount_pct AS bronze_discount,
       CASE WHEN b.discount_pct > 1 THEN b.discount_pct / 100.0 ELSE b.discount_pct END AS fixed_discount
FROM bronze_sales b
WHERE b.discount_pct > 1
LIMIT 5;

SELECT COUNT(*) AS whole_number_discount_bug_rows FROM bronze_sales WHERE discount_pct > 1;
-- -> 110 (0.92% of 12,000 -- matches facts_sheet.md)

-- The recompute pattern in full: never read order_total for arithmetic,
-- always derive net_amount from the raw inputs, with the discount scale
-- fix applied first.
SELECT
    order_id,
    order_line_id,
    quantity,
    unit_price,
    discount_pct,
    order_total AS order_total_raw,          -- kept only as an audit column
    ROUND(
        COALESCE(quantity, 0) * unit_price *
        (1 - CASE WHEN discount_pct > 1 THEN discount_pct / 100.0 ELSE discount_pct END),
        2
    ) AS net_amount                          -- this is what you SUM, never order_total_raw
FROM bronze_sales
WHERE discount_pct > 0 AND discount_pct <= 1
  AND order_total IS NOT NULL AND order_total NOT LIKE '$%'
LIMIT 5;

-- Proof that order_total can't be trusted even when it's a clean,
-- unformatted number: here order_total exactly equals the PRE-discount
-- subtotal (quantity * unit_price), not the actual net-of-discount
-- amount -- a stale total computed before a discount was applied upstream.
SELECT order_id, order_line_id, quantity, unit_price, discount_pct, order_total,
       ROUND(quantity * unit_price, 2) AS pre_discount_total,
       ROUND(quantity * unit_price * (1 - discount_pct), 2) AS net_amount
FROM bronze_sales
WHERE discount_pct > 0 AND discount_pct <= 1
  AND order_total IS NOT NULL AND order_total NOT LIKE '$%'
  AND CAST(order_total AS REAL) != ROUND(quantity * unit_price * (1 - discount_pct), 2)
  AND ABS(CAST(order_total AS REAL) - ROUND(quantity * unit_price, 2)) < 0.02
LIMIT 5;

-- The full set of ways order_total fails to be usable directly -- $-prefixed
-- strings and literal placeholder text, neither of which CAST(... AS REAL)
-- handles safely on every engine:
SELECT DISTINCT order_total
FROM bronze_sales
WHERE order_total IN ('TBD', 'N/A') OR order_total LIKE '$%'
LIMIT 5;
