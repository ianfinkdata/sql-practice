# Oakhaven Facts Sheet

Ground-truth values from an actual build of `project/oakhaven.db`,
verified by running `python project/build.py` twice in a row and
diffing `sqlite3 oakhaven.db ".dump"` output — **byte-identical** both
times (md5 `8a739680c505eb7a732938964a846ef5`). Cite these numbers
directly; do not re-derive them, and do not assume they'll be
"approximately" this — they are exact for this seed.

## Build configuration

- `faker==40.36.0` (pinned in `project/requirements.txt`)
- `SEED = 20260630`
- `SNAPSHOT_DATE = date(2026, 6, 30)`
- Python: stdlib-only besides Faker (`sqlite3`, `random`, `datetime`)
- Environment note: this sandbox's system Python (3.14) had no `pip`;
  bootstrapped via `apt-get install python3-pip python3.14-venv`, then
  built/tested inside a venv. `pip install -r project/requirements.txt`
  is the documented learner path and works standalone.

## Exact row counts

| Object | Rows |
|---|---|
| `bronze_customers` | 600 |
| `bronze_products` | 150 |
| `bronze_employees` | 35 |
| `bronze_sales` | 12,000 |
| `bronze_calendar` | 7,670 |
| `silver_customers` | 600 |
| `silver_products` | 150 |
| `silver_employees` | 35 |
| `silver_sales` | 12,000 |
| `silver_calendar` | 7,670 |
| `dim_customer` | 600 |
| `dim_product` | 150 |
| `dim_employee` | 35 |
| `dim_date` | 7,670 |
| `fact_sales` | 12,000 |
| `agg_monthly_sales_by_category` | 528 |
| `agg_customer_ltv` | 600 |
| `agg_daily_sales` | 2,007 (days 2021-01-01 through 2026-06-30 inclusive) |

Near-duplicate customers: `customer_id` 571–600 (30 rows) are
intentional near-duplicates of 30 of the base 570 customers.

SKU collisions: 4 products share a duplicated SKU (`WAT-0095` and
`WIN-0129`, each held by 2 different `product_id`s), i.e.
`sku_is_duplicate = 1` for 4 rows in `dim_product`.

## Messiness outcomes actually produced (this seed)

From `validate.py`'s informational section on the current build:

| Metric | Count | ~% of 12,000 (or relevant base) |
|---|---|---|
| `bronze_customers.email` NULL | 26 | 4.3% of 600 |
| `bronze_customers.email` = `''` | 9 | 1.5% of 600 |
| `bronze_products.unit_cost` negative | 2 | 1.3% of 150 |
| `bronze_sales` orphan `customer_id` | 103 | 0.86% |
| `bronze_sales` orphan `product_id` | 122 | 1.02% |
| `bronze_sales.employee_id` NULL | 1,243 | 10.4% |
| `bronze_sales.order_date` NULL | 58 | 0.48% |
| `bronze_sales.order_total` NULL | 210 | 1.75% |
| `bronze_sales.order_total = 'TBD'` | 26 | 0.22% |
| `bronze_sales.order_total = 'N/A'` | 41 | 0.34% |
| `bronze_sales.quantity` negative | 359 | 2.99% |
| `bronze_sales.quantity` = 0 | 212 | 1.77% |
| `bronze_sales.quantity` NULL | 198 | 1.65% |
| `silver_sales` ship_date before order_date (parsed) | 216 | 1.8% |
| `bronze_sales.discount_pct` whole-number bug (`> 1`) | 110 | 0.92% |

## Min/max dates actually produced

- `signup_date` (ISO, via `silver_customers`): **2018-01-13** to **2026-06-20**
- `order_date` (ISO, via `silver_sales`): **2021-01-01** to **2026-06-30**

## Exact string variant pools actually generated

**`bronze_products.category`** (40 distinct raw strings observed, all
mapping to the 8 canonical names in `silver_products.category`):
`ACCESSORIES`, `ACCESSORIES ` (trailing space), `APPAREL`, `APPAREL `,
`Accessories`, `Apparel`, `CAMPING & HIKING`, `CAMPING & HIKING `,
`CAMPING AND HIKING `, `CLIMBING`, `CLIMBING `, `Camping & Hiking`,
`Camping and Hiking`, `Climbing`, `FOOT WEAR `, `FOOTWEAR`, `FOOTWEAR `,
`Foot Wear`, `Footwear`, `NUTRITION & HYDRATION`, `NUTRITION & HYDRATION `,
`NUTRITION AND HYDRATION `, `Nutrition & Hydration`, `Nutrition and Hydration`,
`WATER SPORTS`, `WATER SPORTS `, `WINTER SPORTS`, `WINTER SPORTS `,
`Water Sports`, `Winter Sports`, `accessories`, `apparel`,
`camping & hiking`, `camping and hiking`, `climbing`, `footwear`,
`nutrition & hydration`, `nutrition and hydration`, `water sports`,
`winter sports`.

**`bronze_employees.department`**: `MANAGEMENT`, `Management`,
`SUPPORT`, `Sales`, `Support`, `WAREHOUSE`, `Warehouse`, `management`,
`sales`, `support`, `warehouse`. (Canonical: `Sales`, `Support`,
`Warehouse`, `Management`.)

**`bronze_employees.region`**: `CENTRAL`, `Central`, `EAST`, `East`,
`NORTHEAST`, `Northeast`, `SOUTH`, `South`, `WEST`, `West`, `central`,
`east`, `south`, `west`. (Canonical: `West`, `East`, `Central`,
`South`, `Northeast`.)

**`bronze_sales.payment_method`**: `CC`, `Cash`, `Credit Card`,
`Debit Card`, `Gift Card`, `PayPal`, `cash ` (trailing space),
`credit card`, `debit card`, `paypal`. (Canonical after cleaning:
`Credit Card`, `Cash`, `Debit Card`, `Gift Card`, `PayPal`.)

**`bronze_sales.order_status`**: NULL, `CANCELLED`, `Cancelled`,
`Completed`, `Returned`, `completed`. (Canonical after cleaning:
`Completed`, `Cancelled`, `Returned`.)

**`bronze_sales.channel`**: `In-Store`, `Online`, `in store`, `online`.
(Canonical after cleaning: `Online`, `In-Store`.)

**`bronze_customers.is_active`** (and same pool for `is_manager`,
`is_discontinued`): NULL, `0`, `1`, `N`, `Y`, `false`, `n`, `no`,
`true`, `y`, `yes`.

**`bronze_customers.state`** (sample of the 55+ distinct raw variants —
full pool includes all 50 states × {full name, lowercase full name,
2-letter abbrev, lowercase abbrev} plus dotted forms for CA/FL/MA/PA/WA,
plus NULL/`''`): `''`, NULL, `AK`, `AL`, `AR`, `AZ`, `Alaska`,
`Arizona`, `Arkansas`, `CA`, `CO`, `CT`, `Calif.`, `California`,
`Connecticut`, `DE`, `Delaware`, `FL`, `Fla.`, `GA`, `Georgia`, `HI`,
`IA`, `ID`, `IL`, ... (continues through all 50 states).

## Worked example queries (actual output, this build)

### 1. Overall sales totals

```sql
SELECT COUNT(*) AS order_lines, COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(net_amount), 2) AS total_net_amount
FROM fact_sales;
```

| order_lines | orders | total_net_amount |
|---|---|---|
| 12000 | 7199 | 8742289.04 |

### 2. Net sales by channel

```sql
SELECT channel, COUNT(*) AS lines, ROUND(SUM(net_amount), 2) AS total_net_amount
FROM fact_sales GROUP BY channel ORDER BY total_net_amount DESC;
```

| channel | lines | total_net_amount |
|---|---|---|
| In-Store | 5960 | 4380739.06 |
| Online | 6040 | 4361549.98 |

### 3. Total net sales by category (rolled up from the monthly agg view)

```sql
SELECT category, ROUND(SUM(total_net_amount), 2) AS category_total
FROM agg_monthly_sales_by_category
GROUP BY category ORDER BY category_total DESC;
```

| category | category_total |
|---|---|
| Climbing | 1382563.66 |
| Winter Sports | 1238465.41 |
| Apparel | 1232915.57 |
| Nutrition & Hydration | 1158785.06 |
| Footwear | 1077329.56 |
| Accessories | 931075.29 |
| Camping & Hiking | 904446.02 |
| Water Sports | 721133.90 |

### 4. Top 5 customers by lifetime value

```sql
SELECT customer_id, full_name, customer_segment, state, order_count,
       lifetime_net_amount, first_order_date, last_order_date
FROM agg_customer_ltv ORDER BY lifetime_net_amount DESC LIMIT 5;
```

| customer_id | full_name | segment | state | order_count | lifetime_net_amount | first_order_date | last_order_date |
|---|---|---|---|---|---|---|---|
| 41 | Shannon Strong | Retail | OK | 22 | 37544.43 | 2021-08-14 | 2026-03-17 |
| 343 | Jennifer Howard | VIP | IA | 25 | 35024.55 | 2021-07-04 | 2026-06-25 |
| 597 | Jessica Simpson | Wholesale | NH | 17 | 33636.42 | 2021-03-08 | 2026-06-22 |
| 173 | Ryan Bonilla | Retail | SD | 18 | 31159.38 | 2021-01-24 | 2026-05-21 |
| 67 | Derek Roberts | Retail | NY | 21 | 30799.93 | 2021-02-15 | 2026-06-05 |

### 5. Zero-order-day date-spine pattern (`agg_daily_sales`)

```sql
SELECT COUNT(*) FROM agg_daily_sales WHERE order_line_count = 0;
```

Result: **54** days between 2021-01-01 and 2026-06-30 had zero order
lines, and still appear as rows (with `order_line_count = 0`,
`total_net_amount = 0.0`) thanks to the `LEFT JOIN dim_date ...
fact_sales` pattern in `gold/agg_daily_sales.sql`, rather than
disappearing entirely.

### 6. The discount_pct whole-number bug, before/after silver's fix

```sql
SELECT b.order_id, b.order_line_id, b.discount_pct AS bronze_discount,
       s.discount_pct AS silver_discount, s.net_amount
FROM bronze_sales b
JOIN silver_sales s ON s.order_id = b.order_id AND s.order_line_id = b.order_line_id
WHERE b.discount_pct > 1 LIMIT 5;
```

| order_id | order_line_id | bronze_discount | silver_discount | net_amount |
|---|---|---|---|---|
| 21 | 1 | 25.0 | 0.25 | 1786.01 |
| 22 | 1 | 25.0 | 0.25 | 905.51 |
| 71 | 1 | 25.0 | 0.25 | 1357.23 |
| 145 | 2 | 25.0 | 0.25 | 152.71 |
| 183 | 2 | 15.0 | 0.15 | 1279.74 |

## Verification commands actually run

```bash
# environment had no pip on system Python 3.14; bootstrapped via apt:
sudo apt-get install -y python3-pip python3.14-venv
python3 -m venv .venv-build
.venv-build/bin/pip install -r project/requirements.txt
.venv-build/bin/python -c "import faker; print(faker.VERSION)"   # -> 40.36.0

.venv-build/bin/python project/build.py                          # clean run, prints summary, "ALL HARD CHECKS PASSED"
sqlite3 project/oakhaven.db ".tables"                             # 18 tables/views listed
# ... joined fact_sales to each dim, counted orphans/nulls (see below), spot-checked
#     bronze/silver/gold rows by eye

# determinism check: build twice, diff the full dump
.venv-build/bin/python project/build.py
sqlite3 project/oakhaven.db ".dump" > /tmp/dump_run1.sql
.venv-build/bin/python project/build.py
sqlite3 project/oakhaven.db ".dump" > /tmp/dump_run2.sql
diff /tmp/dump_run1.sql /tmp/dump_run2.sql   # -> no output; files identical
```

`fact_sales` join-integrity check (confirms every non-orphan row
resolves against its dimension, and orphan/NULL counts match exactly):

| Check | Result |
|---|---|
| `fact_sales` rows | 12000 |
| `fact_sales JOIN dim_customer` matches | 11897 (= 12000 − 103 orphans) |
| `fact_sales JOIN dim_product` matches | 11878 (= 12000 − 122 orphans) |
| `fact_sales JOIN dim_employee` matches | 10757 (= 12000 − 1243 NULL employee_id) |
| `fact_sales JOIN dim_date` matches | 11942 (= 12000 − 58 NULL datekey) |
