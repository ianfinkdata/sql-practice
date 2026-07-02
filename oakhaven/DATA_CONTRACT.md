# Oakhaven Outfitters — DATA CONTRACT v1.2

> **v1.2 (2026-07-02):** codified the rounding convention already implemented
> in the data (set at Agent B launch): the true order total is the **sum of
> per-line amounts, each rounded to 2dp half-up** — not sum-then-round. §3.9
> and criterion 8 updated. QA's C8.02a (strict sum-then-round parse, 1 order
> off by $0.03: order 122965) is retired; C8.02b (per-line) is the binding
> check and passes with 0 violations.

> **v1.1 (2026-07-02, Ian-approved):** calendar is no longer generated. It is
> a verbatim lift-and-shift of `common_db.dim_date` (see §3.8), executed by
> `ddl/02_calendar_copy.sql` during the DDL/load phase. Removed from Agent A's
> charter; §2 and acceptance criterion 10 updated.

**This document + `generate/contract.py` are the single source of truth.**
Every generator agent reads both before writing a line of code. Precedence:

1. `generate/contract.py` — normative for anything it defines (ID ranges,
   seasonality, order headers, prices, promos, stores, categories).
2. This document — normative for everything else (column specs, dirty quotas,
   acceptance criteria).
3. Agent judgment — only where both are silent, and it must be flagged in the
   agent's final report.

**If the contract and your judgment disagree, the contract wins. If the
contract is silent, flag it — don't improvise.**

Changes: only in the main session with Ian's sign-off → bump
`CONTRACT_VERSION` → regenerate affected tables in full. Never patch a CSV.

---

## 1. Global conventions

| Item | Value |
|---|---|
| Schema | `oakhaven` (MySQL 8.0, utf8mb4, InnoDB) |
| Business window | 2019-01-01 → 2026-06-30 |
| Seed | `oakhaven-v1` — all randomness via `random.Random(f"{SEED}:<key>")` |
| Output | `oakhaven/data/<table>.csv` — UTF-8 no BOM, header row, python `csv` defaults |
| Datetime / date format | `YYYY-MM-DD HH:MM:SS` / `YYYY-MM-DD` |
| SQL NULL in CSV | unquoted `\N` (use `contract.NULL_TOKEN`) |
| Determinism | rerunning a generator must reproduce its CSV byte-for-byte |
| Generators | Python 3.13; Faker allowed for names/addresses (seed it: `Faker.seed(<int from SEED+table>)`) |

### The "dirty, not broken" law

Structural columns are ALWAYS clean: every PK unique/non-null; every FK
resolves (FK constraints are ON at load); core dates, amounts, quantities,
and status enums non-null and valid. Dirt lives only in analytical columns,
at the quotas in §4. Every dirty pattern must be *present* (QA probes for it)
and *bounded* (quota ±40% relative).

## 2. ID ranges (fixed — this is what makes parallel agents safe)

| Table | PK | Range | Count |
|---|---|---|---|
| stores | store_id | 1–13 (13 = WEB) | 13 |
| employees | employee_id | 100–339 | 240 |
| suppliers | supplier_id | 1–45 | 45 |
| product_categories | category_id | 1–24 | 24 |
| products | product_id | 10001–10850 | 850 |
| customers | customer_id | 1–12000 | 12,000 |
| promotions | promo_id | 1–70 | 70 |
| calendar | date_key (INT yyyymmdd) | 20190101–20311231 | 4,748 |
| orders | order_id | 100001–160000 | 60,000 |
| order_items | order_item_id | 1–N sequential | ~156,190 (exact: Σ `order_line_count`) |
| payments | payment_id | 1–N sequential | ~66,000 ±5% |
| shipments | shipment_id | 1–N sequential | ~29,800 ±5% (28,934 shipped orders + ~3% split) |
| returns | return_id | 1–N sequential | ~4,900 ±10% |
| inventory_movements | movement_id | 1–N sequential | 90,000 ±5% |

## 3. Table specifications

**Legend:** 🔒 = structural (always clean, NOT NULL unless noted) ·
🧹 = dirty allowed per §4 quota · FK = enforced foreign key.

### 3.1 stores — Agent A — 13 rows — CLEAN utility dim
Render `contract.STORES` exactly: `store_id` 🔒PK, `store_code` 🔒 unique,
`city` 🔒, `state` 🔒 (2-letter), `opened_date` 🔒. Add: `square_feet` INT
NULL (3000–14000; NULL for WEB).

### 3.2 employees — Agent A — 240 rows
| Column | Type | Spec |
|---|---|---|
| employee_id | INT 🔒PK | 100–339 |
| first_name / last_name | VARCHAR(40) 🔒 | Faker; 6 "rehired" humans appear under two IDs (same name+birth-ish data, different hire dates) |
| job_title | VARCHAR(60) 🧹 | from: Store Manager, Assistant Manager, Sales Associate, Cashier, Web Support, Buyer, Warehouse Lead |
| store_id | INT 🔒 FK→stores | MUST equal `contract.store_of_employee(employee_id)` |
| manager_id | INT NULL FK→employees(self) | lowest employee_id per store = its manager (title Store Manager, manager_id NULL); everyone else → their store's manager |
| hire_date | DATE 🔒 | between store opened_date − 60d and 2026-05-31 |
| termination_date | DATE NULL | 25% terminated, ≥ hire_date |
| hourly_wage | DECIMAL(6,2) 🔒 | 16.50–41.00 by title 🧹 outliers |
| work_email | VARCHAR(120) 🧹 | first.last@oakhavenoutfitters.com |

### 3.3 suppliers — Agent A — 45 rows
`supplier_id` 🔒PK · `supplier_name` VARCHAR(80) 🔒 🧹 (one near-dup pair:
trailing-period variant) · `country` VARCHAR(30) 🔒 🧹 (coding mix) ·
`contact_email` VARCHAR(120) 🧹 · `phone` VARCHAR(25) 🧹 ·
`lead_time_days` INT 🔒 🧹 (3–45; two `-999` sentinels) ·
`active_flag` VARCHAR(5) 🔒 🧹 (Y/N/1/0/yes mix).

### 3.4 product_categories — Agent A — 24 rows — CLEAN
Render `contract.CATEGORIES` exactly: `category_id` 🔒PK, `category_name` 🔒,
`parent_category_id` INT NULL FK→self.

### 3.5 products — Agent A — 850 rows
| Column | Type | Spec |
|---|---|---|
| product_id | INT 🔒PK | 10001–10850 |
| sku | VARCHAR(20) 🔒 unique 🧹 | 90% `OAK-<cat3>-<4d>`, 10% legacy `SKU<6d>` |
| product_name | VARCHAR(100) 🔒 🧹 | outdoor-gear-plausible; casing/space dirt |
| category_id | INT 🔒 FK | from `contract.CHILD_CATEGORY_IDS` only |
| supplier_id | INT 🔒 FK | 1–45, skewed (top 8 suppliers ≈ 50% of SKUs) |
| unit_cost | DECIMAL(8,2) 🔒 | MUST equal `contract.product_unit_cost(id)` |
| list_price | DECIMAL(8,2) 🔒 | MUST equal `contract.product_list_price(id)` (≈2% below-cost anomalies are baked into that function) |
| weight_kg | DECIMAL(7,2) NULL 🧹 | 0.05–28; NULLs + `-999` sentinels |
| intro_date | DATE 🔒 | 2018-06-01–2026-03-31 |
| discontinued_flag | VARCHAR(5) 🔒 🧹 | Y/N/1/0/yes/no mix |
| color | VARCHAR(30) NULL 🧹 | casing mix |

### 3.6 customers — Agent A — 12,000 rows (the dirtiest table)
| Column | Type | Spec |
|---|---|---|
| customer_id | INT 🔒PK | 1–12000 |
| first_name / last_name | VARCHAR(50) 🔒 | Faker |
| middle_name | VARCHAR(50) NULL | 60% NULL |
| email | VARCHAR(120) NULL 🧹 | see quotas |
| phone | VARCHAR(25) NULL 🧹 | five formats + N/A + NULL |
| street_address | VARCHAR(120) 🔒 | Faker |
| city | VARCHAR(50) 🔒 🧹 | PNW-weighted; casing/whitespace dirt |
| state | VARCHAR(20) 🔒 🧹 | WA/OR/ID/MT/CA-weighted; coding mix |
| postal_code | VARCHAR(10) 🔒 🧹 | 2% four-digit (lost leading zero) |
| birth_date | DATE NULL 🧹 | NULLs, 1900-01-01 sentinels, future typos, age>95 outliers |
| signup_date | DATE 🔒 | uniform in window. KNOWN ANOMALY (intentional): some orders predate signup — a "migration artifact" for learners to find |
| loyalty_tier | VARCHAR(12) 🔒 🧹 | Basic 60 / Silver 22 / Gold 13 / Platinum 5 (%), casing dirt |
| marketing_opt_in | VARCHAR(5) 🔒 🧹 | Y/N/TRUE/FALSE/0/1 mix |

**Near-duplicates:** customer_ids 11851–12000 are fuzzy copies of 150
originals drawn deterministically from 1–11850 (`Random(f"{SEED}:dupes")`):
same human, variant spelling/format, same phone digits in different format.

### 3.7 promotions — Agent A — 70 rows
Render `contract.PROMOS` for `promo_id` 🔒PK, `promo_code` VARCHAR(20) 🔒 🧹
(4% lowercased), `start_date` 🔒, `end_date` 🔒, `discount_pct` DECIMAL(4,1)
🔒. Add `description` VARCHAR(200) NULL (marketing blurb, 10% NULL).

### 3.8 calendar — NOT generated — 4,748 rows — CLEAN utility dim
Verbatim copy of `common_db.dim_date` via `ddl/02_calendar_copy.sql`
(rerunnable; no agent involvement). Shape as copied: `date_key` INT 🔒PK
GENERATED (yyyymmdd from `date`) · `date` DATE 🔒 (tightened to NOT NULL
during copy) · `year` · `month_num` · `month` VARCHAR(3) · `quarter` ·
`week_day` (0=Mon, MySQL WEEKDAY convention) · `week_day_name` VARCHAR(3) ·
`is_weekend` · `week_start` · `iso_week_start`. Covers 2019-01-01–2031-12-31,
deliberately wider than the fact window. No holiday/fiscal columns — join
practice uses `date`, `week_start`, and `iso_week_start`.

### 3.9 orders — Agent B — 60,000 rows
Header fields MUST come from `contract.order_header(order_id)`:
`order_id` 🔒PK · `customer_id` 🔒FK · `store_id` 🔒FK · `employee_id` NULL
FK (STORE channel only) · `promo_id` NULL FK · `channel` VARCHAR(5) 🔒 ·
`order_ts` DATETIME 🔒 · `status` VARCHAR(10) 🔒 (clean enum).
Agent B adds:
- `order_total_text` VARCHAR(15) 🔒 🧹 — THE currency-as-text column. True
  total = Σ over lines of ROUND(`quantity × unit_price ×
  (1 − line_discount_pct/100)`, 2) — per-line rounding, half-up (v1.2) —
  then formatted per §4 quota. Numeric truth lives in
  order_items; this column is for CAST/REPLACE practice.
- `order_notes` VARCHAR(200) NULL 🧹 — 80% NULL, junk/sentinels otherwise.

### 3.10 order_items — Agent B — Σ `contract.order_line_count(order_id)` rows
`order_item_id` BIGINT 🔒PK sequential by (order_id, line#) · `order_id` 🔒FK
· `product_id` 🔒FK (any of 10001–10850, weighted seasonally is optional) ·
`quantity` TINYINT 🔒 1–8 skewed low · `unit_price` DECIMAL(8,2) 🔒 =
`contract.product_list_price(pid)` × U(0.95, 1.05) round 2dp — EXCEPT 0.2%
of lines get 0.01 (penny-pricing error, discoverable) · `line_discount_pct`
DECIMAL(4,1) 🔒 = promo pct if order has promo_id else 0; plus 6% of
non-promo lines get clearance 10–40. **This is the numeric backbone — no
other dirt allowed.**

### 3.11 payments — Agent B — ~66,000 rows
`payment_id` 🔒PK · `order_id` 🔒FK · `payment_ts` DATETIME 🔒 ≥ order_ts ·
`method` VARCHAR(20) 🔒 🧹 (casing/name variants) · `amount` DECIMAL(10,2) 🔒
· `status` VARCHAR(10) 🔒 ∈ {captured, failed, refunded} · `card_last4`
CHAR(4) NULL (NULL for cash/gift).
Invariants: cancelled orders → failed attempts only or nothing. All other
orders → captured payments summing EXACTLY to the true order total (4% split
across two rows). 5% of orders get one failed attempt before success.
`refunded` orders additionally get negative-amount refund row(s) ≥
order_ts + 1d.

### 3.12 shipments — Agent C — ~29,800 rows
For every order_id where `contract.order_header(id)["has_shipment"]` — never
read orders.csv. 3% of shipped orders split into two rows.
`shipment_id` 🔒PK · `order_id` 🔒FK · `carrier` VARCHAR(20) 🔒 🧹 (UPS /
FedEx / USPS / OnTrac + casing dirt) · `shipped_ts` DATETIME 🔒 = order_ts +
4h–5d · `delivered_date_raw` VARCHAR(20) NULL 🧹 — THE dates-as-VARCHAR
column (shipped + 1–10d, mixed formats per §4) · `tracking_number`
VARCHAR(30) 🔒 🧹 (1% duplicated values — dirty but PK stays unique) ·
`ship_cost` DECIMAL(6,2) 🔒 (0.00 allowed, 1%).

### 3.13 returns — Agent B — ~4,900 rows
3.3% of order_items on completed/refunded orders (every refunded order gets
≥1 return). `return_id` 🔒PK · `order_item_id` 🔒FK · `return_date` DATE 🔒
= order date + 1–90d (cap at 2026-06-30) · `quantity_returned` 🔒 1–quantity
· `reason` VARCHAR(100) NULL 🧹 free-text mess · `refund_amount` DECIMAL(8,2)
🔒 = quantity_returned × effective line price · `condition_code` VARCHAR(10)
🔒 🧹 (A/B/C/used/LIKE NEW mix).

### 3.14 inventory_movements — Agent C — 90,000 rows ±5%
`movement_id` 🔒PK · `product_id` 🔒FK · `store_id` 🔒FK · `movement_ts`
DATETIME 🔒 in window, follows the §"demand shape" seasonality for sales ·
`movement_type` VARCHAR(15) 🔒 clean enum {receipt, sale, adjustment,
transfer_in, transfer_out} at 22/64/6/4/4% · `quantity` INT 🔒 signed
(receipt/transfer_in > 0; sale/transfer_out < 0; adjustment ±, never 0) ·
`reference` VARCHAR(40) NULL 🧹 (PO-style ids, 'MIGRATION', junk, NULL) ·
`unit_cost_at_time` DECIMAL(8,2) NULL (10% NULL, else cost × U(0.9, 1.1)).
Sales are daily store/product aggregates, NOT 1:1 with order_items.
Discoverable anomaly: 1.5% of transfer_out rows have no matching transfer_in.

## 4. Dirty-data quota registry (QA probes each row of this table)

| # | Table.column | Pattern | Quota |
|---|---|---|---|
| D1 | customers.email | NULL / 'N/A' or 'none' / UPPERCASE / trailing space | 2% / 1.5% / 3% / 2% |
| D2 | customers.phone | (206) 555-0143 / 206-555-0143 / 206.555.0143 / +1 206 555 0143 / 'N/A' / NULL | 60/20/10/5/1/4% |
| D3 | customers.state | full name ('Washington') / abbrev-period ('Wash.') | 10% / 5% |
| D4 | customers.city | leading-or-trailing space / ALLCAPS / lowercase | 2% / 2% / 2% |
| D5 | customers.birth_date | NULL / 1900-01-01 / future date / age > 95 | 5% / 0.5% / 0.2% / 0.3% |
| D6 | customers.loyalty_tier | wrong casing ('GOLD', 'gold ') | 5% |
| D7 | customers near-dupes | ids 11851–12000 fuzzy-copy 150 originals | exactly 150 |
| D8 | orders.order_total_text | `$1,234.56` / `$1234.56` / no `$` / leading space | 90/5/3/2% |
| D9 | orders.order_notes | junk ('called re: delivery', 'N/A', 'MIGRATED 2021') | 20% non-NULL |
| D10 | shipments.delivered_date_raw | `YYYY-MM-DD` / `MM/DD/YYYY` / `Mon D, YYYY` / 'PENDING' / NULL | 55/30/5/4/6% |
| D11 | shipments.carrier | casing variants ('ups', 'FEDEX', 'usps ') | 6% |
| D12 | payments.method | Visa/VISA/visa, Mastercard/'Master Card'/MC, AMEX, cash/CASH, GIFT | mix; ≥8 distinct spellings |
| D13 | products.weight_kg | NULL / -999 | 6% / 1% |
| D14 | products.discontinued_flag | Y/N/1/0/yes/'no ' | ≥5 distinct values |
| D15 | products.product_name | double space / trailing space / ALLCAPS | 3% / 2% / 1% |
| D16 | products.list_price | below unit_cost (via contract fn) | ≈2% |
| D17 | order_items.unit_price | 0.01 penny error | 0.2% |
| D18 | employees.hourly_wage | typo outlier (>150.00) | ~1% (≥2 rows) |
| D19 | employees.job_title | casing variants | 6% |
| D20 | suppliers.country | USA / US / United States | mix, ≥3 codings |
| D21 | suppliers.lead_time_days | -999 sentinel | exactly 2 rows |
| D22 | returns.reason | casing dupes + free text + NULL | NULL 6% |
| D23 | inventory_movements.reference | 'MIGRATION' / junk / NULL | 3% / 2% / 25% |
| D24 | orders vs customers | order_ts < signup_date (migration artifact) | emerges naturally; QA asserts > 0 |
| D25 | shipments.tracking_number | duplicated value pairs | 1% |

## 5. Agent charters

| Agent | Tables | May read | Must never |
|---|---|---|---|
| A — Dimensions | stores, employees, suppliers, product_categories, products, customers, promotions | contract only | invent IDs outside §2 |
| B — Sales | orders, order_items, payments, returns | contract only | deviate from `order_header` / `order_line_count` / pricing fns |
| C — Logistics | shipments, inventory_movements | contract only | read other agents' CSVs |
| D — QA | all loaded tables | contract + §6 | pass a check that didn't run |

Each generator: one `gen_<domain>.py` in `oakhaven/generate/`, imports
`contract`, writes `oakhaven/data/<table>.csv`, prints per-table row counts.
Final report must list any contract silence encountered.

## 6. Acceptance criteria (Agent D executes; all must pass)

1. **Row counts** within §2 tolerances (exact where exact).
2. **PKs**: `COUNT(*) = COUNT(DISTINCT pk)` for all 14 tables.
3. **FKs**: schema declares ≥ 15 FK constraints; anti-join orphan checks
   return 0 for every FK (belt-and-suspenders on top of constraints).
4. **Structural NULLs**: zero NULLs in every 🔒 column.
5. **Dirt presence**: one probe per registry row D1–D25 returns > 0 (and
   within quota ±40% relative where a % is given).
6. **Window**: MIN/MAX of order_ts, payment_ts, shipped_ts, movement_ts all
   within 2019-01-01–2026-06-30 23:59:59.
7. **Seasonality**: orders in Jul 2025 > Feb 2025 × 1.5; Apr 2020 < Jan 2020;
   2024 total > 2021 total.
8. **Sequence sanity**: shipped_ts ≥ order_ts (0 violations); payment
   captured-sum per completed order = order_items true total (per-line
   rounding per §3.9, v1.2) ± $0.02 (0 violations); return_date >
   DATE(order_ts) — EXCEPT exactly 1 approved row (refunded order dated
   2026-06-30 whose return is window-capped to the same date);
   quantity_returned ≤ quantity.
9. **Status logic**: pending orders only within 14 days of 2026-06-30;
   cancelled orders have no captured payments and no shipments.
10. **Calendar**: 4,748 rows, no gaps (`DATEDIFF(MAX(date),MIN(date))+1 =
    COUNT(*)`), MIN(date) ≤ 2019-01-01 and MAX(date) ≥ 2026-06-30, and it
    matches the source: row count equals `common_db.dim_date`.

Output: `qa/validation.sql` + a pass/fail report table. Any failure → the
owning agent's tables are regenerated (contract fix requires Ian).
