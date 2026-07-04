# EXPECTED_OUTPUTS.md — TASK-20260704-02 bronze pack

Captured 2026-07-04 via actual `--batch` runs against `oakhaven` (RULE-006 — pasted verbatim,
never hand-typed). Connection: `& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
--defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven < <file>.sql`.

B01 and B05 were re-run a second time in this session and diffed byte-for-byte identical against
the capture below (`Compare-Object` produced no output) — reproducibility confirmed per
medallion-spec §Reproducibility rule 5.

---

## B01_row_counts.sql

```
table_name	row_count
calendar	4748
customers	12000
employees	240
inventory_movements	90000
order_items	156190
orders	60000
payments	66663
product_categories	24
products	850
promotions	70
returns	5010
shipments	29784
stores	13
suppliers	45
```

All 14 counts match `grounding/schema.md`'s live-verified snapshot exactly.

---

## B02_integrity.sql

Result set 1 — PK uniqueness (`total_rows` = `distinct_pk` for every table):

```
table_name	total_rows	distinct_pk
calendar	4748	4748
customers	12000	12000
employees	240	240
inventory_movements	90000	90000
order_items	156190	156190
orders	60000	60000
payments	66663	66663
product_categories	24	24
products	850	850
promotions	70	70
returns	5010	5010
shipments	29784	29784
stores	13	13
suppliers	45	45
```

Result set 2 — FK orphan anti-joins (all 16 declared FKs, `orphan_count` = 0 for every row):

```
fk_check	orphan_count
employees.manager_id -> employees.employee_id	0
employees.store_id -> stores.store_id	0
inventory_movements.product_id -> products.product_id	0
inventory_movements.store_id -> stores.store_id	0
order_items.order_id -> orders.order_id	0
order_items.product_id -> products.product_id	0
orders.customer_id -> customers.customer_id	0
orders.employee_id -> employees.employee_id	0
orders.promo_id -> promotions.promo_id	0
orders.store_id -> stores.store_id	0
payments.order_id -> orders.order_id	0
product_categories.parent_category_id -> product_categories.category_id	0
products.category_id -> product_categories.category_id	0
products.supplier_id -> suppliers.supplier_id	0
returns.order_item_id -> order_items.order_item_id	0
shipments.order_id -> orders.order_id	0
```

All PKs unique; zero orphans across every FK.

---

## B03_enum_census.sql

12 result sets, in brief order (orders.status, orders.channel, inventory_movements.movement_type,
payments.status, payments.method, customers.loyalty_tier, customers.state,
products.discontinued_flag, suppliers.active_flag, suppliers.country, customers.marketing_opt_in,
shipments.carrier). Grouped/ordered on `COLLATE utf8mb4_0900_bin` to force byte-exact distinctness
(the schema's default `utf8mb4_0900_ai_ci` collation is case-insensitive and would otherwise
silently merge casing variants — see the file header for the empirical proof on payments.method).

```
value	n
cancelled	1689
completed	55917
pending	11
refunded	2383
value	n
STORE	32819
WEB	27181
value	n
adjustment	5400
receipt	19800
sale	57600
transfer_in	3600
transfer_out	3600
value	n
captured	60615
failed	3665
refunded	2383
value	n
AMEX	6143
CASH	2297
GIFT	3087
MC	1514
Master Card	2237
Mastercard	15317
VISA	3005
Visa	22628
cash	8906
visa	1529
value	n
BASIC	83
Basic	6935
Basic 	107
GOLD	19
Gold	1415
Gold 	22
PLATINUM	5
Platinum	603
Platinum 	9
SILVER	22
Silver	2447
Silver 	33
basic	94
basic 	77
gold	14
gold 	21
platinum	7
platinum 	6
silver	46
silver 	35
value	n
CA	1723
Calif.	102
California	202
ID	1007
Ida.	56
Idaho	99
MT	849
Mont.	44
Montana	96
OR	2504
Ore.	146
Oregon	289
WA	4117
Wash.	252
Washington	514
value	n
0	85
1	70
N	460
Y	130
no 	45
yes	60
value	n
0	4
1	8
N	7
Y	18
no	3
yes	5
value	n
Canada	6
China	5
Germany	2
Italy	2
Taiwan	3
US	7
USA	10
United States	6
Vietnam	4
value	n
0	1169
1	1567
FALSE	1177
N	2926
TRUE	1446
Y	3715
value	n
FEDEX	289
FedEx	8304
ONTRAC	284
OnTrac	2882
UPS	9865
USPS	6997
Usps	275
fedex	316
ups	271
usps 	301
```

Notes for DEF-012/DEF-013 mapping tables:
- `customers.state`: 15 distinct raw values feeding DEF-012 (WA/OR/ID/MT/CA exact + full-name +
  abbrev-period variants for each).
- `payments.method`: 10 distinct raw values feeding DEF-013 (>= 8 required by CONTRACT D12 — met).
- `products.discontinued_flag`: 6 distinct values (0/1/N/Y/'no '/yes).
- `suppliers.active_flag`: 6 distinct values (0/1/N/Y/no/yes).
- `customers.loyalty_tier`: 20 distinct raw values (4 tiers x 5 casing/whitespace variants each) —
  this is the column where the collation fix mattered most; a plain GROUP BY would have silently
  collapsed most of these.

---

## B04_dirt_census.sql

25 result sets, one per D1-D25 (see file header for the full method notes, including the D8
magnitude-aware fix and the D20 USA-coding scope).

```
dirt_id	pattern	n
D1	leading/trailing space	240
D1	N/A or none (any case)	180
D1	NULL	240
D1	UPPERCASE	360
dirt_id	pattern	n
D2	1-NULL	477
D2	2-N/A	118
D2	3-(206) 555-0143 style	7137
D2	4-206-555-0143 style	2400
D2	5-206.555.0143 style	1226
D2	6-+1 206 555 0143 style	642
dirt_id	pattern	n
D3	1-full state name (e.g. Washington)	1200
D3	2-abbrev-period (e.g. Wash.)	600
D3	3-clean 2-letter code	10200
dirt_id	pattern	n
D4	ALLCAPS	240
D4	leading/trailing space	240
D4	lowercase	240
dirt_id	pattern	n
D5	1900-01-01 sentinel	60
D5	age > 95 as of 2026-06-30	36
D5	future date (> 2026-06-30)	24
D5	NULL	600
dirt_id	pattern	n
D6	1-canonical casing	11400
D6	2-wrong casing	600
dirt_id	pattern	n
D7	customer_id BETWEEN 11851 AND 12000	150
dirt_id	pattern	n
D8	1-standard formatting (comma present when magnitude requires it)	55525
D8	2-missing comma (total >= 1000, no comma)	1561
D8	3-no $ sign	1753
D8	4-leading/trailing space	1161
dirt_id	pattern	n
D9	non-NULL order_notes	12040
dirt_id	pattern	n
D10	1-NULL	1840
D10	2-PENDING	1165
D10	3-YYYY-MM-DD	16196
D10	4-MM/DD/YYYY	9112
D10	5-Mon D, YYYY	1471
dirt_id	pattern	n
D11	1-canonical casing	28048
D11	2-casing variant	1736
dirt_id	pattern	n
D12	distinct spellings (BINARY-exact)	10
dirt_id	pattern	n
D13	-999 sentinel	9
D13	NULL	51
dirt_id	pattern	n
D14	distinct values (BINARY-exact)	6
dirt_id	pattern	n
D15	ALLCAPS	9
D15	double space	26
D15	trailing space	17
dirt_id	pattern	n
D16	list_price < unit_cost	17
dirt_id	pattern	n
D17	unit_price = 0.01	297
dirt_id	pattern	n
D18	hourly_wage > 150.00	3
dirt_id	pattern	n
D19	1-canonical casing	226
D19	2-casing variant	14
dirt_id	pattern	n
D20	distinct USA codings (US/USA/United States, BINARY-exact)	3
dirt_id	pattern	n
D21	lead_time_days = -999	2
dirt_id	pattern	n
D22	NULL	279
dirt_id	pattern	n
D23	1-MIGRATION	2654
D23	2-PO-style id or junk (non-NULL, non-MIGRATION)	64686
D23	3-NULL	22660
dirt_id	pattern	n
D24	DATE(order_ts) < signup_date	24217
dirt_id	pattern	n
D25	rows sharing a duplicated tracking_number	298
```

All 25 probes return > 0 (contract acceptance criterion 5, "dirt presence"). Quota cross-checks
against DATA_CONTRACT §4 (± the contract's own 40% relative tolerance where a % is stated):
D1 2.0/1.5/3.0/2.0% vs quota 2/1.5/3/2% (exact); D2 sums to 12,000 exactly (exhaustive partition)
with split 59.5/20.0/10.2/5.35/0.98/3.98% vs quota 60/20/10/5/1/4% — all within tolerance;
D3 10.0/5.0% vs 10/5%; D4 2.0/2.0/2.0% vs 2/2/2%; D5 0.5/0.2/0.3/5.0% vs 5/0.5/0.2/0.3%; D6 5.0% vs
5%; D7 exactly 150; D8 92.5/2.6/2.9/1.9% of all 60,000 orders vs 90/5/3/2% — note the 5% missing-comma
quota only applies where a comma is possible (true total >= $1,000, n = 31,588): rebased,
1,561/31,588 = 4.94% vs 5%, an excellent match (see file note on the magnitude-aware fix);
D9 20.1% vs 20%; D10 sums to 29,784 exactly, 55/30/5/4/6% shape matched; D11 5.8% vs 6%; D12 10 >= 8;
D13 1.1/6.0% vs 6/1%; D14 6 >= 5; D15 3.1/2.0/1.1% vs 3/2/1%; D16 2.0% vs ~2%; D17 0.19% vs 0.2%;
D18 3 rows (>= 2 required) at 1.25%; D19 5.8% vs 6%; D20 exactly 3 codings (>= 3 required); D21
exactly 2; D22 279/5010 = 5.6% vs 6% (NULL-specific quota); D23 sums to 90,000 exactly, MIGNULL/NULL
buckets at 2.9%/25.2% vs 3%/25% (junk vs legitimate-PO-id split not separable without a documented
ID format — left as one combined bucket, honestly labeled); D24, D25 have no upper quota (contract:
"emerges naturally, assert > 0" / "~1%" respectively) — both non-zero and D25 at 1.00% matches
closely.

---

## B05_revenue_ground_truth.sql

Result set 1 — gross revenue total (DEF-004):

```
gross_revenue
83160177.98
```

Result set 2 — gross revenue by order year (DEF-004 sliced by YEAR(order_ts)):

```
order_year	gross_revenue
2019	6640121.67
2020	5476281.72
2021	9177799.79
2022	11081156.71
2023	12864160.59
2024	14648117.48
2025	15982206.48
2026	7290333.54
```

The 8 yearly figures sum to 83,160,177.98, reconciling exactly to result set 1.

Result set 3 — DEF-016 reconciliation (CAST(order_total_text) vs. DEF-002 true total, all orders):

```
total_orders	orders_missing_items	mismatches
60000	0	0
```

0 mismatches across all 60,000 orders — DEF-016 holds exactly, confirming order_total_text was
formatted directly from the DEF-002 true total (never a separate/derived amount).

---

## B06_window_anomalies.sql

Result set 1 — date-window MIN/MAX (contract §6 criterion 6; all within 2019-01-01..2026-06-30
23:59:59):

```
ts_column	min_ts	max_ts
movement_ts	2019-01-01 06:40:25	2026-06-30 23:59:59
order_ts	2019-01-01 08:48:34	2026-06-30 21:34:10
payment_ts	2019-01-01 09:11:16	2026-06-30 23:59:59
shipped_ts	2019-01-02 16:31:38	2026-06-30 23:59:59
```

Result set 2 — planted anomaly counts:

```
anomaly	n
below-cost products (list_price < unit_cost)	17
movements before intro_date (DATE(movement_ts) < intro_date)	31093
orders before signup (DATE(order_ts) < signup_date)	24217
orphan transfer_out (no transfer_in sharing its reference)	54
penny lines (order_items.unit_price = 0.01)	297
```

All 5 anomalies present (> 0), consistent with RULE-008 (planted anomalies are features, never
"fixed"). The "orders before signup" (24,217 / 40.4% of orders) and "movements before intro_date"
(31,093 / 34.5% of movements) counts are large because `signup_date` and `intro_date` are drawn
uniformly across the whole business window independently of `order_ts`/`movement_ts` — the contract
calls this out as an intentional, unbounded "migration artifact," not a small-quota anomaly like the
other three. The orphan transfer_out count (54 / 1.500% of 3,600 transfer_out rows) matches the
contract's ~1.5% quota almost exactly, confirming the reference-based pairing key (see file header
ASSUMPTION).
