# Definitions Registry — Oakhaven Medallion Project

**STATUS: APPROVED v1.0 (2026-07-04) — approval artifact: merged PR #52.**
All DEFs are usable by all tasks. No open items: DEF-012/013 mapping tables were
finalized from the shipped B03 census and approved by Ian 2026-07-04 (v1.1);
DEF-019 added same day from the TASK-02 finding. DEF-020/021 added 2026-07-05
from the TASK-04 MISSING DEFINITION escalations (diffs approved by Ian in-session);
they apply to gold via the follow-up brief TASK-20260705-01.
One entry per metric or business concept. Agents may READ this file; only Ian edits it
(agents propose diffs). Increment the DEF number; bump version on any change.

Sources of authority: `oakhaven/DATA_CONTRACT.md` v1.2 (cited as CONTRACT §n) and the live
database. Where a DEF restates contract law, the contract citation is included.

---

## DEF-001: Line net revenue  (v1.0)
- **Plain definition:** What a single order line is worth after its discount — the atomic money unit of the whole model.
- **Canonical SQL:**
  ```sql
  ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)
  ```
- **Source:** oakhaven.order_items (quantity, unit_price, line_discount_pct)
- **Grain:** per order line
- **Owner:** Ian
- **Caveats:** Per-line rounding, half-up, 2dp — NEVER sum-then-round (CONTRACT §3.9 v1.2). All operands are DECIMAL/TINYINT so MySQL arithmetic is exact; ROUND on DECIMAL rounds half away from zero, which equals half-up for these non-negative values.
- **Changelog:** v0.1 2026-07-04 — drafted from CONTRACT §3.9

## DEF-002: Order true total  (v1.0)
- **Plain definition:** The real order amount: sum of its line net revenues.
- **Canonical SQL:**
  ```sql
  SELECT oi.order_id,
         SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)) AS order_true_total  -- DEF-001
  FROM oakhaven.order_items oi
  GROUP BY oi.order_id
  ```
- **Source:** oakhaven.order_items via DEF-001
- **Grain:** per order
- **Owner:** Ian
- **Caveats:** `orders.order_total_text` is a formatting-practice column, not a source (see DEF-016). Captured payments for completed orders reconcile to this total ± $0.02 (CONTRACT §6.8).
- **Changelog:** v0.1 2026-07-04

## DEF-003: Revenue-recognized order statuses  (v1.0)
- **Plain definition:** Which orders count as sales: completed and refunded orders do; cancelled and pending do not.
- **Canonical SQL:**
  ```sql
  o.status IN ('completed', 'refunded')
  ```
- **Source:** oakhaven.orders.status (clean enum: completed, cancelled, refunded, pending)
- **Grain:** per order
- **Owner:** Ian
- **Caveats:** Refunded orders count as GROSS revenue; their give-back is netted via returns (DEF-005). Pending = only orders within 14 days of window end (11 rows).
- **Changelog:** v0.1 2026-07-04

## DEF-004: Gross revenue  (v1.0)
- **Plain definition:** Total sales value of revenue-recognized orders before returns.
- **Canonical SQL:**
  ```sql
  SELECT SUM(ROUND(oi.quantity * oi.unit_price * (1 - oi.line_discount_pct / 100), 2)) AS gross_revenue  -- DEF-001
  FROM oakhaven.order_items oi
  JOIN oakhaven.orders o ON o.order_id = oi.order_id
  WHERE o.status IN ('completed', 'refunded')  -- DEF-003
  ```
- **Grain:** whatever the GROUP BY slices; base is order-line
- **Owner:** Ian
- **Changelog:** v0.1 2026-07-04

## DEF-005: Net revenue  (v1.0)
- **Plain definition:** Gross revenue minus the value refunded through returns.
- **Canonical SQL:**
  ```sql
  gross_revenue - COALESCE(returned_value, 0)
  -- where returned_value = SUM(r.refund_amount) over oakhaven.returns r
  -- joined via order_items to the same order/date/product slice as the gross side
  ```
- **Source:** DEF-004 + oakhaven.returns.refund_amount
- **Grain:** matches the slice; return value attributes to the ORIGINAL order line's dimensions, dated by policy below
- **Owner:** Ian
- **Caveats:** Two dating policies exist; gold marts use **return_date** for trend marts (cash-timing view) and original order date for product-level return-rate marts. Each mart states which it uses.
- **Changelog:** v0.1 2026-07-04

## DEF-006: Average order value (AOV)  (v1.0)
- **Plain definition:** Gross revenue divided by the number of revenue-recognized orders.
- **Canonical SQL:**
  ```sql
  ROUND(SUM(line_net_revenue) / COUNT(DISTINCT o.order_id), 2)
  -- numerator per DEF-004 scope, denominator = orders passing DEF-003 in the same slice
  ```
- **Grain:** per slice
- **Owner:** Ian
- **Changelog:** v0.1 2026-07-04

## DEF-007: Unit return rate  (v1.0)
- **Plain definition:** Of units sold on revenue-recognized orders, the share that came back.
- **Canonical SQL:**
  ```sql
  ROUND(SUM(COALESCE(r.quantity_returned, 0)) / SUM(oi.quantity) * 100, 2)
  -- oi restricted per DEF-003; r = returns LEFT JOINed on order_item_id
  ```
- **Grain:** per slice (product, category, month…)
- **Owner:** Ian
- **Caveats:** LEFT JOIN — most lines have no return. A line can have at most one return row in this dataset.
- **Changelog:** v0.1 2026-07-04

## DEF-008: Revenue return rate  (v1.0)
- **Plain definition:** Refunded value as a share of gross revenue.
- **Canonical SQL:**
  ```sql
  ROUND(SUM(COALESCE(r.refund_amount, 0)) / SUM(line_net_revenue) * 100, 2)  -- DEF-001, DEF-003 scope
  ```
- **Grain:** per slice
- **Owner:** Ian
- **Changelog:** v0.1 2026-07-04

## DEF-009: Boolean normalization rule  (v1.0)
- **Plain definition:** How Y/N/1/0/yes/no/TRUE/FALSE text flags become a real 0/1.
- **Canonical SQL:**
  ```sql
  CASE WHEN UPPER(TRIM(x)) IN ('Y', 'YES', '1', 'TRUE')  THEN 1
       WHEN UPPER(TRIM(x)) IN ('N', 'NO', '0', 'FALSE') THEN 0
       ELSE NULL END
  ```
- **Applies to:** customers.marketing_opt_in, products.discontinued_flag, suppliers.active_flag
- **Owner:** Ian
- **Caveats:** ELSE NULL is deliberate — an unmapped value must surface in the silver verification query (count of non-NULL bronze → NULL silver must be 0), not be guessed.
- **Changelog:** v0.1 2026-07-04

## DEF-010: Phone normalization rule  (v1.0)
- **Plain definition:** Reduce any phone format to its 10 digits; junk becomes NULL.
- **Canonical SQL:**
  ```sql
  CASE WHEN LENGTH(REGEXP_REPLACE(COALESCE(phone, ''), '[^0-9]', '')) >= 10
       THEN RIGHT(REGEXP_REPLACE(phone, '[^0-9]', ''), 10)
       ELSE NULL END
  ```
- **Applies to:** customers.phone, suppliers.phone
- **Owner:** Ian
- **Caveats:** Handles all five contract formats incl. +1 prefix (D2); 'N/A' and NULL → NULL. Also the join key for near-dupe matching (DEF-014).
- **Changelog:** v0.1 2026-07-04

## DEF-011: Delivered-date parse rule  (v1.0)
- **Plain definition:** Turn shipments.delivered_date_raw (mixed text formats) into a DATE; 'PENDING'/NULL stay NULL with a flag.
- **Canonical SQL:**
  ```sql
  CASE
    WHEN delivered_date_raw IS NULL OR delivered_date_raw = 'PENDING' THEN NULL
    WHEN delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN CAST(delivered_date_raw AS DATE)
    WHEN delivered_date_raw REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN STR_TO_DATE(delivered_date_raw, '%m/%d/%Y')
    ELSE STR_TO_DATE(delivered_date_raw, '%b %e, %Y')
  END
  ```
- **Applies to:** oakhaven.shipments.delivered_date_raw (formats per CONTRACT D10)
- **Owner:** Ian
- **Caveats:** Silver adds `is_delivery_pending` = (raw = 'PENDING'). Verification: parsed NULLs must equal raw NULL + 'PENDING' counts exactly.
- **Changelog:** v0.1 2026-07-04

## DEF-012: State normalization rule  (v1.1)
- **Plain definition:** Map full state names and period-abbreviations ('Washington', 'Wash.') to 2-letter codes; already-2-letter values pass through uppercased.
- **Canonical SQL:**
  ```sql
  CASE
    WHEN CHAR_LENGTH(TRIM(state)) = 2               THEN UPPER(TRIM(state))
    WHEN TRIM(state) IN ('Washington', 'Wash.')     THEN 'WA'
    WHEN TRIM(state) IN ('Oregon',     'Ore.')      THEN 'OR'
    WHEN TRIM(state) IN ('Idaho',      'Ida.')      THEN 'ID'
    WHEN TRIM(state) IN ('Montana',    'Mont.')     THEN 'MT'
    WHEN TRIM(state) IN ('California', 'Calif.')    THEN 'CA'
    ELSE NULL
  END
  ```
- **Applies to:** customers.state
- **Owner:** Ian
- **Caveats:** Mapping covers all 15 raw values in the shipped B03 census (medallion/a_bronze/EXPECTED_OUTPUTS.md). Silver verification asserts post-clean distinct = {CA, ID, MT, OR, WA} and ZERO NULLs — every bronze value maps. The IN() comparisons run under the schema's case-insensitive collation (deliberate tolerance); ELSE NULL stays as the unmapped-value tripwire (RULE-007).
- **Changelog:** v1.1 2026-07-04 — mapping table finalized from B03 census, approved by Ian · v0.1 2026-07-04

## DEF-013: Payment method normalization  (v1.1)
- **Plain definition:** Collapse the 10 raw spellings into canonical set {visa, mastercard, amex, cash, gift} (lowercase for storage; reports may Title-Case at render time).
- **Canonical SQL:**
  ```sql
  CASE UPPER(TRIM(method))
    WHEN 'VISA'        THEN 'visa'
    WHEN 'MASTERCARD'  THEN 'mastercard'
    WHEN 'MASTER CARD' THEN 'mastercard'
    WHEN 'MC'          THEN 'mastercard'
    WHEN 'AMEX'        THEN 'amex'
    WHEN 'CASH'        THEN 'cash'
    WHEN 'GIFT'        THEN 'gift'
    ELSE NULL
  END
  ```
- **Applies to:** payments.method (CONTRACT D12)
- **Owner:** Ian
- **Caveats:** Covers all 10 raw values in the shipped B03 census. Mapped totals — visa 27,162 · mastercard 19,068 · cash 11,203 · amex 6,143 · gift 3,087 — sum to 66,663 = the full payments row count, so silver verification asserts ZERO NULLs. 'MC' → mastercard confirmed by Ian. ELSE NULL stays as the unmapped-value tripwire (RULE-007).
- **Changelog:** v1.1 2026-07-04 — mapping table finalized from B03 census, approved by Ian · v0.1 2026-07-04

## DEF-014: Customer near-dupe resolution  (v1.1)
- **Plain definition:** customer_ids 11851–12000 are known fuzzy copies of 150 originals (CONTRACT D7). Each maps to a canonical_customer_id; silver flags, gold collapses.
- **Canonical rule:**
  1. Candidates: customer_id BETWEEN 11851 AND 12000.
  2. Match to the original (id ≤ 11850) on normalized phone (DEF-010) when non-NULL and unique among originals.
  3. Fallback: exact equality of DEF-015-normalized email local parts (both emails non-NULL)
     + same raw birth_date (both non-NULL), and the match must hit exactly ONE original —
     a candidate matching two or more originals is ambiguous and goes unresolved, never guessed.
  4. Unresolved → `canonical_customer_id = customer_id`, `dupe_resolution = 'unresolved'` (flagged, never guessed).
  For all non-candidates, `canonical_customer_id = customer_id`.
- **dupe_resolution vocabulary:** 'phone' | 'email_birth_date' | 'unresolved' for candidates; NULL for non-candidates.
- **Grain:** per customer
- **Owner:** Ian
- **Caveats:** Verification target: resolved + unresolved candidates = exactly 150; resolved originals are distinct ids ≤ 11850.
  Live-data finding (TASK-03, validator-confirmed): the rule-3 fallback resolves ZERO candidates — no candidate shares
  an email local part with any original (the generator mutated them); the branch stays live in the view for rule fidelity.
  Actual split: 134 phone-resolved + 16 unresolved.
- **Changelog:** v1.1 2026-07-04 — rule-3 uniqueness + non-NULL guards codified from TASK-03 build (validator Warning 1), live zero-resolution finding documented; approved by Ian · v0.1 2026-07-04

## DEF-015: Email normalization rule  (v1.0)
- **Plain definition:** Lowercase, trim; 'N/A'/'none' (any casing) become NULL.
- **Canonical SQL:**
  ```sql
  CASE WHEN LOWER(TRIM(email)) IN ('n/a', 'none') OR TRIM(COALESCE(email, '')) = '' THEN NULL
       ELSE LOWER(TRIM(email)) END
  ```
- **Applies to:** customers.email, suppliers.contact_email, employees.work_email
- **Owner:** Ian
- **Changelog:** v0.1 2026-07-04

## DEF-016: order_total_text cast (reconciliation only)  (v1.0)
- **Plain definition:** How to parse the currency-as-text column when reconciling it against DEF-002. NEVER a revenue source.
- **Canonical SQL:**
  ```sql
  CAST(REPLACE(REPLACE(TRIM(order_total_text), '$', ''), ',', '') AS DECIMAL(10,2))
  ```
- **Applies to:** oakhaven.orders.order_total_text (formats per CONTRACT D8)
- **Owner:** Ian
- **Caveats:** Bronze pack proves cast(text) = DEF-002 total for all 60,000 orders; after that, gold uses DEF-002 exclusively.
- **Changelog:** v0.1 2026-07-04

## DEF-017: Sentinel policy  (v1.0)
- **Plain definition:** Known impossible values become NULL in silver, with a flag column recording that a sentinel was present.
- **Rules:**
  | Bronze value | Silver value | Flag column |
  |---|---|---|
  | products.weight_kg = -999 | NULL | is_weight_sentinel |
  | suppliers.lead_time_days = -999 | NULL | is_lead_time_sentinel |
  | customers.birth_date = '1900-01-01' | NULL | is_birth_date_sentinel |
  | customers.birth_date > CURRENT window end (2026-06-30) | NULL | is_birth_date_future |
- **Owner:** Ian
- **Caveats:** age > 95 outliers (D5) are kept but flagged `is_age_outlier` — plausible, not impossible. Window end is a constant, not CURDATE(), for reproducibility.
- **Changelog:** v0.1 2026-07-04

## DEF-018: Fulfillment days  (v1.1)
- **Plain definition:** Days from order to delivery.
- **Canonical SQL:**
  ```sql
  DATEDIFF(delivered_date, DATE(o.order_ts))  -- delivered_date per DEF-011
  ```
- **Grain:** per shipment (an order may have 2 shipments — 3% split; order-level fulfillment = MAX over its shipments)
- **Owner:** Ian
- **Caveats:** NULL while pending — at ORDER level, "pending" means the order has no shipment
  or ANY undelivered shipment; the MAX is over fully-delivered shipment sets only (ratified
  from TASK-04, affects 160 partially-delivered multi-shipment orders vs the ignore-NULLs
  reading). Ship-to-deliver lag alternative uses shipped_ts; marts state which anchor they use.
- **Changelog:** v1.1 2026-07-05 — order-level pending semantics ratified (TASK-04 validator Warning 2; approved by Ian in-session) · v0.1 2026-07-04

## DEF-019: Inventory transfer pairing  (v1.0)
- **Plain definition:** A transfer_out row and its receiving transfer_in row are the same physical transfer, linked by an identical `reference` token (`TR-######`).
- **Canonical SQL (orphan transfer_out probe):**
  ```sql
  SELECT COUNT(*) FROM oakhaven.inventory_movements tout
  WHERE tout.movement_type = 'transfer_out'
    AND NOT EXISTS (SELECT 1 FROM oakhaven.inventory_movements tin
                    WHERE tin.movement_type = 'transfer_in'
                      AND tin.reference = tout.reference)
  ```
- **Source:** oakhaven.inventory_movements.reference
- **Grain:** per transfer pair
- **Owner:** Ian
- **Caveats:** Empirically discovered (TASK-02), then adversarially verified (validator): all 3,600 transfer_out references are unique TR tokens (0 NULL, 0 reuse); matched pairs always share product_id and never share store_id. Two discoverable populations, both features per RULE-008: 54 orphan transfer_outs (contract's stated ~1.5%) and 38 reverse-orphan transfer_ins (16 NULL-reference + 22 well-formed-but-unmatched) — the latter is NOT contract-documented; gold inventory reconciliation must expect both.
- **Changelog:** v1.0 2026-07-04 — created from TASK-02 finding; approved by Ian in-session ("apply corrections") with the reverse-orphan population documented as a discoverable

## DEF-020: Loyalty tier normalization  (v1.0)
- **Plain definition:** Collapse the 20 raw casing/whitespace variants of customers.loyalty_tier into the ordinal tier set {basic, silver, gold, platinum} (lowercase storage; reports Title-Case at render time, per DEF-013 precedent). Ordinal rank: basic=1, silver=2, gold=3, platinum=4 — tiers order by rank, never alphabetically.
- **Canonical SQL:**
  ```sql
  CASE UPPER(TRIM(loyalty_tier))
    WHEN 'BASIC'    THEN 'basic'
    WHEN 'SILVER'   THEN 'silver'
    WHEN 'GOLD'     THEN 'gold'
    WHEN 'PLATINUM' THEN 'platinum'
    ELSE NULL
  END
  ```
- **Applies to:** customers.loyalty_tier — in GOLD `dim_customer` only. Silver shipped this column as a raw passthrough and stays untouched; the raw value is retained as `loyalty_tier_raw`.
- **Grain:** per customer
- **Owner:** Ian
- **Caveats:** Covers all 20 raw values in the shipped B03 census (medallion/a_bronze/EXPECTED_OUTPUTS.md — 4 tiers × 5 casing/whitespace variants; the census REQUIRES a NO PAD binary collation, utf8mb4_0900_bin, or trailing-space variants silently merge per RULE-011). Mapped totals basic 7,296 · silver 2,583 · gold 1,491 · platinum 630 sum to 12,000 = the full customers count, so gold verification asserts ZERO NULLs. ELSE NULL is the unmapped-value tripwire (RULE-007).
- **Changelog:** v1.0 2026-07-05 — created from TASK-04 MISSING DEFINITION escalation; mapping finalized from shipped B03 census; diff approved by Ian in-session

## DEF-021: Unit margin  (v1.0)
- **Plain definition:** Per-unit profit on an order line: the realized (post-discount) unit price minus the product's current unit cost. Companion product-level CATALOG margin (list_price − unit_cost) serves the R2 price-vs-cost scatter.
- **Canonical SQL:**
  ```sql
  ROUND(oi.unit_price * (1 - oi.line_discount_pct / 100), 2) - p.unit_cost   -- realized, line grain
  -- companion, product grain (R2 scatter):
  -- p.list_price - p.unit_cost
  ```
- **Source:** oakhaven.order_items (unit_price, line_discount_pct) × oakhaven.products (unit_cost, list_price)
- **Grain:** per order line (realized); per product (catalog companion)
- **Owner:** Ian
- **Caveats:** Cost basis is CURRENT products.unit_cost — no historical cost table exists, so margins on old orders use today's cost (stated limitation). order_items.unit_price is a true transactional price (equals list_price on only 142 of 156,190 lines — live-probed 2026-07-05). The realized unit price is rounded 2dp BEFORE subtracting, mirroring DEF-001's round-per-line law; unit_cost is an exact DECIMAL so the result is exact 2dp. Realized below-cost lines (3,534 live) and the D16 catalog below-cost products (17) / D17 penny lines are features to surface, never filter (RULE-008). R2's "median unit margin" = median over DEF-003 revenue lines in fact_order_lines.
- **Changelog:** v1.0 2026-07-05 — created from TASK-04 MISSING DEFINITION escalation; price/cost basis probed live; diff approved by Ian in-session
