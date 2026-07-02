# Oakhaven Outfitters — Practice Database Implementation Plan

## The Scenario

**Oakhaven Outfitters** is a fictional Pacific-Northwest outdoor gear retailer,
founded 2019. It runs **12 physical stores + 1 e-commerce channel**, sources from
~45 wholesale suppliers, and sells ~850 SKUs across camping, hiking, climbing,
paddling, and apparel categories. Business dates span **2019-01-01 through
2026-06-30**, with realistic seasonality (summer peaks, holiday spikes, a
visible COVID-style dip in 2020) and year-over-year growth.

Why this scenario: retail generates every shape of practice data you want —
high-volume transactions (orders, line items, payments), slowly-changing
dimensions (employees with hire/term dates, product price changes), logistics
(shipments, inventory movements), and natural date-based analysis (cohorts,
rolling windows, YoY). And squirrels hoard things in oak trees, which keeps the
SQRL brand intact.

## Definition of Done (verbatim contract with Ian)

1. New MySQL schema (`oakhaven`) with **at least 10 tables**.
2. **Well-formed dirty data**: messy in realistic ways, but never
   database-breaking.
3. **Primary keys enforced on every table.** Foreign keys enforced.
   No structural column (PK, FK, core dates/amounts) is ever NULL.
4. Several tables with row counts **in the tens of thousands**; dimension
   tables stay naturally small.

## Guardrail: "dirty, not broken"

Dirtiness lives ONLY in non-structural columns. The split:

| Always clean (structural) | Allowed to be dirty (analytical) |
|---|---|
| Every PK: unique, non-null | Text casing/whitespace (` Seattle `, `SEATTLE`, `seattle`) |
| Every FK: resolves to a real parent row | Phone/email format inconsistency |
| Order/payment/shipment dates | Sentinel values (`N/A`, `UNKNOWN`, `1900-01-01`, `-999`) |
| Monetary amounts on transactions | NULLs in genuinely nullable columns (mid_name, notes, termination_date) |
| Quantity, status enums | Near-duplicate customers (same human, two rows, slightly different spelling) |
| | Dates-as-VARCHAR in one designated column (mixed `MM/DD/YYYY` and `YYYY-MM-DD`) |
| | Currency-as-text in one designated column (`$1,204.50`) |
| | Outliers (a $48,000 order; a 97-year-old customer), a few future-dated typos |
| | Inconsistent state/region coding (`WA` / `Wash.` / `Washington`) |
| | Trailing whitespace, double spaces, misspelled category echoes in free-text |

Every dirty pattern is **quota'd in the data contract** (e.g. "4% of
customers.phone use dotted format, 1% are `N/A`") so it's discoverable but not
overwhelming, and so QA can verify it exists.

## Table Inventory (14 tables)

| # | Table | Type | Target rows | Notes |
|---|-------|------|------------:|-------|
| 1 | `stores` | dim | 13 | 12 retail + 1 web channel |
| 2 | `employees` | dim | ~240 | hire/termination dates, manager self-FK, store FK |
| 3 | `suppliers` | dim | ~45 | dirty contact/address data |
| 4 | `product_categories` | dim | ~24 | parent/child hierarchy (self-FK) |
| 5 | `products` | dim | ~850 | SKU, cost, price, discontinued flags |
| 6 | `customers` | dim | ~12,000 | loyalty tiers, near-duplicates, dirty contact info |
| 7 | `promotions` | dim | ~70 | date-ranged discount campaigns |
| 8 | `calendar` | dim | ~2,740 | one row per day 2019-01-01 → 2026-06-30, clean (it's a utility) |
| 9 | `orders` | fact | **~60,000** | store, customer, employee, promo FKs; seasonality baked in |
| 10 | `order_items` | fact | **~150,000** | 1–8 lines per order; line discounts |
| 11 | `payments` | fact | **~63,000** | split payments, failed/retried attempts |
| 12 | `shipments` | fact | **~34,000** | web + ship-to-home orders only; carrier, ship/deliver dates |
| 13 | `returns` | fact | ~4,800 | tied to order_items; reason codes (free-text = dirty) |
| 14 | `inventory_movements` | fact | **~90,000** | receipts, sales decrements, adjustments, transfers |

Four tables in the tens of thousands (orders, order_items, payments,
inventory_movements), one at 34k, the rest naturally small. ✔

## Architecture: contract → generate → load → verify

```
oakhaven/
├── IMPLEMENTATION_PLAN.md      ← this file
├── DATA_CONTRACT.md            ← THE source of truth (Phase 1 output)
├── ddl/
│   └── 01_schema.sql           ← CREATE DATABASE + 14 CREATE TABLEs, PKs, FKs
├── generate/
│   ├── contract.py             ← contract constants as importable Python (ID ranges, seeds, quotas)
│   ├── gen_dimensions.py       ← Agent A output
│   ├── gen_sales.py            ← Agent B output
│   └── gen_logistics.py        ← Agent C output
├── data/                       ← generated CSVs (gitignored)
├── load/
│   └── load_all.sql            ← LOAD DATA LOCAL INFILE, dimension-first order
└── qa/
    └── validation.sql          ← acceptance checks (Agent D)
```

### The contract is what makes parallel subagents safe

`DATA_CONTRACT.md` (and its executable twin `generate/contract.py`) pins down,
per table:

- **Exact PK ID ranges** (e.g. `customer_id` = 1..12000, `order_id` =
  100001..160000). Because ranges are fixed *before* generation, the sales
  agent can emit valid `customer_id` FKs without ever seeing the dimensions
  agent's CSV. No inter-agent coordination needed.
- **Column-by-column spec**: name, MySQL type, nullability, dirty-data quota.
- **Deterministic RNG seed per table** so any table can be regenerated
  independently and reproducibly.
- **Business-logic invariants**: order dates within store open dates,
  payments ≥ order total per order (net of failed attempts), shipment date ≥
  order date, seasonality curve definition.
- **Acceptance criteria** that QA (Agent D) executes verbatim.

Rule for all agents: **if the contract and your judgment disagree, the
contract wins; if the contract is silent, flag it — don't improvise.**

## Phases & Subagent Assignments

### Phase 1 — Author the contract (main session, no subagents)
Write `DATA_CONTRACT.md` + `generate/contract.py`. Ian reviews before any
generation starts. ~This is the only review gate.~

### Phase 2 — DDL (main session)
`ddl/01_schema.sql`: schema, 14 tables, PKs, FKs, sensible indexes on FK and
date columns. Applied to MySQL immediately so load failures surface early.

### Phase 3 — Parallel data generation (3 subagents, worktree-isolated)
| Agent | Deliverable | Tables |
|-------|-------------|--------|
| **A — Dimensions** | `gen_dimensions.py` + CSVs | stores, employees, suppliers, categories, products, customers, promotions, calendar |
| **B — Sales** | `gen_sales.py` + CSVs | orders, order_items, payments, returns |
| **C — Logistics** | `gen_logistics.py` + CSVs | shipments, inventory_movements |

Each agent's prompt = pointer to `DATA_CONTRACT.md` + its table list. Python
3.13 + Faker (already used in this repo's `python/generate_synthetic_data.py`).
B and C depend only on the contract's ID ranges, not on A's output files.

### Phase 4 — Load (main session)
`load/load_all.sql` via `mysql.exe` (service MySQL80, already running).
Dimension tables first, then facts, FK checks ON so violations fail loudly.
Fallback if `local_infile` is disabled server-side: generators also emit
chunked multi-row `INSERT` .sql files.

### Phase 5 — QA (1 subagent)
| Agent | Deliverable |
|-------|-------------|
| **D — Validator** | `qa/validation.sql` + pass/fail report |

Checks: row counts vs. contract (±2%), PK uniqueness, zero FK orphans, zero
NULLs in structural columns, **presence** of each contracted dirty pattern
(e.g. `SELECT COUNT(*) FROM customers WHERE phone = 'N/A'` must be > 0),
date-window sanity, seasonality spot-check.

## Decisions log

- **2026-07-02 — Credentials resolved.** Dedicated `claude@localhost` MySQL
  user found in `C:\Users\ianfi\.my.cnf`. Windows mysql clients do NOT read
  `~/.my.cnf` automatically; all project scripts must connect with
  `--defaults-extra-file="C:\Users\ianfi\.my.cnf"`.
- **2026-07-02 — Keep plain-text cnf for now.** Ian decided to leave the
  credentials file as-is. Future hardening path (documented in memory file
  `mysql-local-credentials.md` on E:\memory): migrate to the encrypted store
  via `mysql_config_editor set --login-path=claude --host=127.0.0.1
  --user=claude --password`, switch scripts to `--login-path=claude`, delete
  the `.my.cnf`.

- **2026-07-02 — PROJECT COMPLETE.** All 5 phases done. 14 tables loaded
  (~420k rows total), FK checks ON throughout, QA verdict: PASS — 128/130
  clean, 1 approved exception (criterion 8, single window-capped return),
  1 rounding-wording ambiguity codified as contract v1.2 (per-line rounding).
  QA suite is rerunnable: `qa/validation.sql`. Emergent discoverables for
  exercises: 24,217 orders predate customer signup ("migration artifact");
  31,093 inventory movements predate product intro_date.

## Future enhancement: holiday + fiscal backfill on the calendar

Decided 2026-07-02 (contract v1.1): `oakhaven.calendar` is a verbatim
lift-and-shift of `common_db.dim_date`, which has no holiday or fiscal
columns. If exercises later need them, enrich the SOURCE and re-copy so both
databases benefit:

1. Alter the source:
   `ALTER TABLE common_db.dim_date
      ADD COLUMN is_holiday TINYINT NOT NULL DEFAULT 0,
      ADD COLUMN holiday_name VARCHAR(40) NULL,
      ADD COLUMN fiscal_year SMALLINT NULL,
      ADD COLUMN fiscal_quarter TINYINT NULL;`
2. Backfill fiscal (Oakhaven FY starts Jul 1 — FY2020 = 2019-07-01→2020-06-30):
   `UPDATE common_db.dim_date SET
      fiscal_year = YEAR(`date`) + (MONTH(`date`) >= 7),
      fiscal_quarter = QUARTER(DATE_ADD(`date`, INTERVAL 6 MONTH));`
3. Backfill US major holidays (New Year's, Memorial Day, July 4th, Labor Day,
   Thanksgiving, Christmas — fixed dates via UPDATE; floating ones via
   week_day + day-of-month window logic, or a small Python script).
4. Re-run `oakhaven/ddl/02_calendar_copy.sql` (add the new columns to its
   INSERT column list first).
5. Bump DATA_CONTRACT.md §3.8 and acceptance criterion 10, per protocol.

## Out of scope (for now)

Views, stored procedures, exercise curriculum on top of the schema, and
integration with `sql-trainer/`. All natural follow-ups once the data exists.
