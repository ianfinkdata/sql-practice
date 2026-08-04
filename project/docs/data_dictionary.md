# Oakhaven Bronze Layer — Data Dictionary

Bronze tables are the raw, as-ingested layer: no primary keys, no
foreign keys, no CHECK constraints. That absence is deliberate — the
Tier 4 constraints lesson later contrasts this against proper DDL. All
five tables are created by `project/bronze/schema.sql`
(`bronze_calendar` is re-created by `project/bronze/calendar_recursive_cte.sql`,
which also populates it).

Generation is fully deterministic: `SEED = 20260630` and
`SNAPSHOT_DATE = date(2026, 6, 30)` (`project/build_lib/config.py`).
Rerunning `python project/build.py` produces byte-identical data every
time — verified by diffing `sqlite3 oakhaven.db ".dump"` output across
two consecutive runs.

For exact generated values (row counts, min/max dates, the literal
string variants that came out of this seed), see `facts_sheet.md`.

---

## bronze_customers (~600 rows)

| Column | Type | Notes |
|---|---|---|
| `customer_id` | INTEGER | Sequential 1..600. No PK constraint. |
| `first_name` | TEXT | Mixed casing (UPPER/lower/Title) and occasional stray/doubled internal whitespace. |
| `last_name` | TEXT | Same messiness pattern as `first_name`. |
| `email` | TEXT | ~4% NULL, ~2% empty string `''`. Otherwise `first.last@domain` form, lowercase. |
| `phone` | TEXT | Mixed formats: `(555) 123-4567`, `555-123-4567`, `5551234567`, `555.123.4567`, `+1 555 123 4567`. ~8% NULL. All non-null values are exactly 3-3-4 digit groups (area/prefix/line), which is what makes format-based re-parsing in `silver_customers.sql` reliable. |
| `state` | TEXT | Mix of full name, 2-letter abbreviation, lowercase, dotted abbreviation (`Calif.`, `Fla.`, `Mass.`, `Penn.`, `Wash.`), empty string, NULL. |
| `signup_date` | TEXT | Mixed formats: `YYYY-MM-DD`, `MM/DD/YYYY`, `YYYY-MM-DD HH:MM:SS`. Range 2018-01-01 through SNAPSHOT_DATE. |
| `is_active` | TEXT | Mixed-boolean text pool: `{Y, N, y, n, true, false, 1, 0, yes, no, NULL}`. |
| `customer_segment` | TEXT | `Retail` / `Wholesale` / `VIP` with inconsistent casing. ~3% NULL. |

**Intentional near-duplicate people:** customer_ids 571–600 (30 rows)
are near-duplicates of 30 of the base 1–570 rows — same underlying
person (same normalized/lowercased email), but with varied name
casing/whitespace and an email rendered with different casing or stray
whitespace (still equal after `LOWER(TRIM(email))`). Other fields
(phone, state, signup_date, is_active, segment) are independently
regenerated, mirroring a person who signed up twice. This is the
dedup-with-`ROW_NUMBER()` lesson hook.

---

## bronze_products (~150 rows)

| Column | Type | Notes |
|---|---|---|
| `product_id` | INTEGER | Sequential 1..150. |
| `product_name` | TEXT | `{adjective} {subcategory}`, e.g. "Summit Hiking Boots". Not guaranteed unique. |
| `category` | TEXT | Inconsistent casing/spacing variants of the 8 canonical categories: `Footwear`, `Apparel`, `Camping & Hiking`, `Climbing`, `Water Sports`, `Winter Sports`, `Accessories`, `Nutrition & Hydration`. Variants include upper/lower/title casing, trailing space, and (for 3 categories) an "and" spelled out instead of "&", or a split compound word (`Foot Wear`). |
| `subcategory` | TEXT | ~10% NULL. |
| `brand` | TEXT | Drawn from a curated pool of ~25 realistic-sounding fictional outdoor-gear brand names. |
| `unit_cost` | REAL | ~3% NULL. ~1% deliberately negative (data-entry error — not "fixed" downstream). |
| `unit_price` | REAL | Always positive; computed as `unit_cost * markup` where markup ∈ [1.3, 2.6] at generation time (before any cost corruption), so price is always sensible even when the stored cost is null/negative. |
| `is_discontinued` | TEXT | Same mixed-boolean text pool as `is_active`. |
| `sku` | TEXT | Mostly unique (`{3-letter category code}-{product_id:04d}`); ~1% of products (2 products, in the seeded run) are picked to have their SKU overwritten with another product's SKU, producing ~2% of products (4 rows) sharing a duplicated SKU. Surfaced via `silver_products.sku_is_duplicate`. |
| `weight_kg` | TEXT | Dirty TEXT, not a clean REAL: e.g. `"1.2"`, `"1.2 kg"`, or NULL (~8%). |
| `created_at` | TEXT | Mixed date formats, same 3-format pattern as `signup_date`. |

---

## bronze_employees (~35 rows)

| Column | Type | Notes |
|---|---|---|
| `employee_id` | INTEGER | Sequential 1..35. |
| `first_name` / `last_name` | TEXT | Mixed casing (no whitespace injection, unlike customers). |
| `department` | TEXT | `Sales` / `Support` / `Warehouse` / `Management` with inconsistent casing. |
| `region` | TEXT | `West` / `East` / `Central` / `South` / `Northeast` with inconsistent casing. |
| `hire_date` | TEXT | Mixed formats, 2018-01-01 through SNAPSHOT_DATE. |
| `termination_date` | TEXT | NULL for ~85% (still employed as of SNAPSHOT_DATE). Populated with a date strictly after `hire_date` for ~15% — this is the SCD Type 2 hook for a later lesson. |
| `is_manager` | TEXT | Mixed-boolean text pool. |
| `email` | TEXT | `first.last@oakhaven.com`, lowercase. ~5% NULL. |

---

## bronze_sales (~12,000 order-line rows — the messiest table)

Grain: one row per order line. Order-level attributes (`order_date`,
`customer_id`, `employee_id`, `payment_method`, `order_status`,
`channel`, and the ship-date behavior) are generated once per
`order_id` and shared across that order's lines, mirroring a flattened
order-header/order-line system.

| Column | Type | Notes |
|---|---|---|
| `order_id` | INTEGER | Groups 1–3 order lines. Not sequential-per-line — repeats across an order's lines. |
| `order_line_id` | INTEGER | 1-based within `order_id`. |
| `customer_id` | INTEGER | ~1% reference a `customer_id` that does not exist in `bronze_customers` (intentional orphan FK, at the order level — all lines of an orphan order share the bad id). |
| `product_id` | INTEGER | ~1% reference a `product_id` that does not exist in `bronze_products` (intentional orphan FK, per line). |
| `employee_id` | INTEGER | ~10% NULL — represents an online/no-rep sale. |
| `order_date` | TEXT | Mixed formats, 2021-01-01 through SNAPSHOT_DATE. ~0.5% NULL. |
| `ship_date` | TEXT | NULL for ~15% of orders. For a further ~2% of orders, chronologically **before** `order_date` (intentional bad data — do not "fix" this in bronze). Otherwise `order_date` + 0–10 days. |
| `quantity` | INTEGER | Mostly positive small ints (1–5). ~3% negative (returns, -1 to -3). A few rows 0 or NULL. |
| `unit_price` | REAL | Price **at time of sale** — drift-adjusted from the product's current `bronze_products.unit_price` by a random ±15% factor. Intentionally may differ from the product's current price; this is real-world price drift, not a bug. |
| `discount_pct` | REAL | Usually a fraction 0–1 (drawn from `{0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30}`, weighted toward 0). ~1% of rows with a nonzero discount erroneously store the whole-number form (e.g. `15` instead of `0.15`) — a data-entry bug that `silver_sales.sql` detects and fixes (`> 1` → `/ 100.0`). |
| `order_total` | TEXT | **Deliberately untrustworthy.** ~57% correctly computed (plain text), ~13% correct but `$`-prefixed/whitespace-padded, ~20% computed **pre-discount** (stale/wrong, plain text), ~7% pre-discount stale with `$` formatting, ~2% NULL, ~0.3% literal `"TBD"`, ~0.3% literal `"N/A"`. Never trust this column — `silver_sales.net_amount` recomputes from `quantity * unit_price * (1 - discount_pct)` instead. |
| `payment_method` | TEXT | Pool: `Credit Card`, `credit card`, `CC`, `Cash`, `cash `, `Debit Card`, `debit card`, `PayPal`, `paypal`, `Gift Card`. |
| `order_status` | TEXT | Pool: `Completed`, `completed`, `CANCELLED`, `Cancelled`, `Returned`, NULL (weighted, NULL ~10%). |
| `channel` | TEXT | Pool: `Online`, `In-Store`, `online`, `in store`. |

---

## bronze_calendar (~7,670 rows — NOT messy)

A manufactured date spine, not raw/messy ingested data. Built entirely
in SQL via `project/bronze/calendar_recursive_cte.sql` (a `WITH
RECURSIVE` INSERT — no Python loop), one row per day from 2018-01-01
through 2038-12-31 inclusive.

| Column | Type | Notes |
|---|---|---|
| `datekey` | INTEGER | `YYYYMMDD`, e.g. `20260630`. |
| `date` | TEXT | ISO `YYYY-MM-DD`. |

---

## Known limitations / deliberate simplifications

- Name title-casing in the silver layer (`UPPER(first char) + LOWER(rest)`)
  only handles single-token names correctly. Faker occasionally
  generates names with internal punctuation (e.g. `O'Brien`); these
  render as `O'brien` after cleaning. This is a known, accepted
  limitation — not a bug to "fix" upstream.
- `discount_pct`'s whole-number bug is only injected on rows where the
  *true* discount is nonzero (a 0% "bug" would be indistinguishable
  from a clean 0% row), so its effective rate is slightly lower than a
  flat 1% of all rows. See `facts_sheet.md` for the actual count.
- Bronze category messiness variants were generated per-row
  independently, so not every possible casing/spacing permutation is
  guaranteed to appear for every category — see `facts_sheet.md` for
  the exact list that came out of this seed.
