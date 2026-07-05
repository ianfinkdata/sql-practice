# EXPECTED_OUTPUTS.md — TASK-20260705-01 gold amendment (DEF-020 loyalty tier + DEF-021 unit margin)

This file is the COMPLETE updated capture set for the gold layer and supersedes the
TASK-20260704-04 version (medallion/c_gold/EXPECTED_OUTPUTS.md).

**TASK-20260705-02 amendment (capture-only):** the Q07 and Q09 entries are now FULL row-level
captures replacing their aggregate signatures; no SQL logic, view, or other capture changed.

**What changed vs TASK-04:**
- **Amended views (4, all additive):** `dim_customer` (+ `loyalty_tier` normalized per DEF-020,
  + `loyalty_tier_rank`, raw kept as `loyalty_tier_raw`), `fact_order_lines` (+ `unit_margin`
  per DEF-021 realized form, via a silver products PK join), `dim_product` (+ `catalog_margin`
  per DEF-021 companion), `mart_product_performance` (+ `catalog_margin` carried through).
- **New verify:** V06 (DEF-020 tier census, RULE-011 binary NO PAD collation, zero-NULL-leak),
  V07 (DEF-021 spot reconciliation + below-cost censuses).
- **New queries:** Q13 (R1 revenue by loyalty tier, rank-ordered), Q14 (R2 margin KPIs incl.
  median unit margin), Q15 (R2 margin distribution histogram). Q09 needed no change (the R2
  scatter uses unit_cost/list_price/is_below_cost, all already present).
- **Everything else is carried over VERBATIM from the TASK-04 captures** — the regression guard
  (below) proved no existing output moved.

**REGRESSION GUARD (run 2026-07-05, after the four amended views were applied live):** the
full shipped verify pack V01–V05 and ALL shipped queries Q01–Q12 (incl. the Q07/Q09 aggregate
signature queries) were re-run against the amended views and diffed against the TASK-04
captures: **all 17 targets byte-identical** — the added columns changed no existing query's
output (every existing query SELECTs named columns; verified by re-run, not assumption).

Captured 2026-07-05 via actual `--batch` runs against the live server, MySQL 8.0 (RULE-006 —
pasted verbatim, never hand-typed; this file was assembled mechanically from the captured
run files). Connection: `Get-Content <file>.sql -Raw | & "C:\Program Files\MySQL\MySQL Server
8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven`.

Preconditions: the TASK-04 gold layer live (G00–G11 in filename order), then the four amended
ddl files from this task re-applied (`G03_dim_product.sql`, `G04_dim_customer.sql`,
`G06_fact_order_lines.sql`, `G09_mart_product_performance.sql` — CREATE OR REPLACE VIEW,
dependency order G03 → G04 → G06 → G09). Gold reads from `oakhaven_silver` only (plus
`oakhaven_silver` `_raw` columns in the two R3 DQ queries and bronze `oakhaven` reads inside
V07's reconciliation probes, which recompute DEF-021 off the source of truth).

Every NEW or re-run query in this file (V06, V07, Q13, Q14, Q15) was run TWICE in this session
and diffed byte-for-byte identical — reproducibility confirmed per medallion-spec
§Reproducibility rule 5.

Q07 (450 rows) and Q09 (850 rows) were originally captured as aggregate signatures per
medallion-spec §Reproducibility rule 4; TASK-20260705-02 replaced both entries with their
full row-level `--batch` captures (see each entry for the zero-drift regression against the
retired signatures). Each was run twice and confirmed byte-identical before pasting.

---

# verify/

## V01_gross_revenue_reconciliation.sql

RS1 — gross revenue via four independent gold paths (DEF-004) vs the bronze B05 constant;
RS2 — DEF-005 net consistency; RS3 — mart_monthly_sales LEFT-JOIN tripwire:
```
mart_monthly_gross	fact_line_gross	mart_category_gross	mart_product_gross	matches_b05
83160177.98	83160177.98	83160177.98	83160177.98	1
mart_net_total	fact_net_total	is_match
81208524.85	81208524.85	1
orphan_return_cells
0
```

All four paths = 83,160,177.98 = bronze B05 to the cent (`matches_b05` = 1). Net totals agree
(81,208,524.85 = gross − 1,951,653.13 refunds); zero orphan return cells — the trend mart's
return_date netting drops nothing.

---

## V02_fact_row_counts.sql
```
fact_lines	silver_revenue_lines	is_match
151818	151818	1
fact_orders_rows	revenue_orders	fact_distinct_orders	mart_order_total	matches_b01	matches_b03
60000	58300	58300	58300	1	1
dim_product_rows	mart_product_rows	matches_b01
850	850	1
```

fact_order_lines = 151,818 = silver order_items restricted to DEF-003 orders (target derived
live, not hardcoded). fact_orders = 60,000 (B01); revenue orders = 58,300 = B03 census
(completed 55,917 + refunded 2,383) and the same 58,300 falls out of the fact's DISTINCT
order_id and the mart's SUM(order_count). dim_product and mart_product_performance both
cover all 850 products (B01).

---

## V03_dim_customer_reconciliation.sql
```
silver_customers	dim_customers	collapsed_dupes	collapsed_by_canonical	is_match
12000	11866	134	134	1
sum_source_ids	absorbed_dupes	dupe_survivors	distinct_originals_in_map
12000	134	134	134
fact_orders_missing_canonicals	fact_lines_missing_canonicals
0	0
```

DEF-014 collapse proven: dim_customer 11,866 = 12,000 silver customers − 134 collapsed dupes,
where 134 is read from `oakhaven_silver.customer_dupe_map` two independent ways (resolution
label and canonical≠self), matching silver V06 (134 phone-resolved + 16 unresolved kept).
Source-id accounting: SUM(n_source_ids) = 12,000 (every silver row lands in exactly one dim
row); 134 absorbed; 134 dupe survivors = 134 distinct originals (1:1). Zero canonical keys in
either fact are missing from the dim.

---

## V04_dim_date_window.sql
```
n_days	distinct_keys	min_date	max_date	is_full_span	distinct_months
2738	2738	2019-01-01	2026-06-30	1	90
```

dim_date is exactly the 2019-01-01..2026-06-30 window: 2,738 unique days (full span), 90
distinct sales months.

---

## V05_returns_scope.sql
```
silver_return_rows	silver_refund_total	fact_return_rows	fact_refund_total	mart_return_rows	mart_refund_total	fact_mart_match
5010	1951653.13	5010	1951653.13	5010	1951653.13	1
returns_on_non_revenue_orders	refund_outside_scope
0	0.00
lines_with_multiple_returns
0
```

All 5,010 bronze returns sit on DEF-003 revenue-order lines (RS2 = 0), so silver = fact =
mart_returns exactly, refund total 1,951,653.13. RS3 = 0 adversarially confirms the DEF-007
caveat (at most one return per line) — the fact's LEFT JOIN cannot fan out.

---

## V06_loyalty_tier_census.sql

RS1 — full-base DEF-020 census (the exact gold expression over all 12,000 silver customers);
RS2 — zero-NULL-leak + total accounting; RS3 — raw-variant coverage under the RULE-011 NO PAD
binary collation; RS4 — the gold dim_customer surface census (DEF-014 canonical grain):
```
tier	tier_rank	n_customers	n_raw_variants
basic	1	7296	5
silver	2	2583	5
gold	3	1491	5
platinum	4	630	5
silver_customers	mapped_total	full_base_null_leaks	dim_tier_null_leaks	dim_rank_null_leaks	tier_rank_mismatches
12000	12000	0	0	0	0
raw_variants_binary	raw_variants_default_collation
20	8
loyalty_tier	loyalty_tier_rank	n_canonical_customers	n_source_customers
basic	1	7212	7297
silver	2	2553	2582
gold	3	1476	1491
platinum	4	625	630
```

RS1 hits the B03-reconciled DEF-020 mapped totals exactly — basic 7,296 · silver 2,583 ·
gold 1,491 · platinum 630, summing to 12,000 — with 5 raw variants per tier, in rank order
(never alphabet). RS2: all 12,000 rows map (zero NULL leaks full-base AND on the gold dim;
zero tier↔rank mismatches — the DEF-020 bijection holds). RS3: 20 distinct raw variants under
`COLLATE utf8mb4_0900_bin`; the schema-default ai_ci PAD collation sees only 8 (casing and
trailing-space variants silently merge — exactly the RULE-011 trap the binary NO PAD collation
avoids). RS4: the 11,866-row canonical census (7,212 / 2,553 / 1,476 / 625) with DEF-014
source accounting — `n_source_customers` sums to 12,000, but its per-tier split
(7,297 / 2,582 / 1,491 / 630) deliberately does NOT re-produce RS1: exactly one absorbed dupe's
own raw tier (silver) differs from its canonical original's (basic). Orders attribute to the
CANONICAL row's tier by DEF-014 design (the original wins; ids resolve, attributes don't merge).

---

## V07_margin_reconciliation.sql

RS1 — hand-computable MIN-PK spot lines (bronze ingredients vs the fact column); RS2 —
below-cost censuses; RS3 — full-population consistency probes:
```
which	order_item_id	unit_price	line_discount_pct	unit_cost	bronze_recomputed_margin	fact_unit_margin	is_match
below_cost_min_pk	68	104.26	0.0	129.65	-25.39	-25.39	1
overall_min_pk	1	23.19	0.0	14.64	8.55	8.55	1
penny_line_min_pk	1830	0.01	10.0	217.87	-217.86	-217.86	1
below_cost_all_lines	below_cost_revenue_lines	below_cost_out_of_scope	catalog_below_cost	is_below_cost_flag_total
3534	3444	90	17	17
fact_unit_margin_mismatches	dim_catalog_margin_mismatches	mart_catalog_margin_mismatches	below_cost_flag_mismatches
0	0	0	0
```

RS1: all three spot lines match — e.g. the D17 penny line (order_item_id 1830):
ROUND(0.01 × (1 − 10/100), 2) = 0.01, minus unit_cost 217.87 → −217.86 = the fact's
unit_margin exactly (rounded BEFORE subtracting per DEF-021/RULE-004). RS2: 3,534 realized
below-cost lines across ALL 156,190 order lines (the DEF-021 caveat census) = 3,444 in DEF-003
revenue scope + 90 on cancelled/pending orders — the same scope-split pattern as the D17 penny
lines (297 = 291 + 6, Q11); catalog below-cost = 17 = SUM(is_below_cost) = the B06 D16 census.
RS3: zero mismatches recomputing both DEF-021 forms straight off bronze across all 151,818
fact lines and all 850 products; mart_product_performance carries dim_product's catalog_margin
exactly, and is_below_cost ⇔ catalog_margin < 0 with no exceptions.

---

# queries/

## Q01_r1_sales_kpis.sql
```
gross_revenue	returned_value	net_revenue	order_count	aov	revenue_return_rate_pct
83160177.98	1951653.13	81208524.85	58300	1426.42	2.35
```

R1 KPI row: gross 83,160,177.98 (= B05), net 81,208,524.85 (DEF-005), 58,300 orders (DEF-003),
AOV 1,426.42 (DEF-006), revenue return rate 2.35% (DEF-008).

---

## Q02_r1_monthly_revenue_by_channel.sql

180 rows (90 months × 2 channels), captured in full:
```
sales_month	channel	order_count	gross_revenue	net_revenue
2019-01	STORE	140	202718.28	200974.22
2019-01	WEB	112	185701.62	184856.71
2019-02	STORE	128	185159.35	183767.00
2019-02	WEB	96	126393.55	125842.11
2019-03	STORE	167	245997.52	244489.15
2019-03	WEB	162	226329.31	222497.79
2019-04	STORE	187	278129.75	273997.99
2019-04	WEB	155	233875.61	226572.51
2019-05	STORE	205	264081.24	260574.67
2019-05	WEB	207	293196.83	287031.06
2019-06	STORE	285	443968.15	436435.97
2019-06	WEB	215	329720.93	326072.11
2019-07	STORE	247	353856.66	348456.12
2019-07	WEB	217	285830.39	277647.01
2019-08	STORE	271	354209.91	339768.71
2019-08	WEB	254	373391.84	366316.43
2019-09	STORE	208	273663.95	269110.99
2019-09	WEB	185	233142.79	224916.34
2019-10	STORE	211	296559.16	292626.29
2019-10	WEB	168	228644.93	223149.68
2019-11	STORE	238	334423.53	325333.77
2019-11	WEB	167	223946.00	215807.75
2019-12	STORE	238	333420.25	324585.92
2019-12	WEB	231	333760.12	330298.53
2020-01	STORE	136	187673.05	182462.86
2020-01	WEB	104	151035.16	145437.43
2020-02	STORE	140	193929.19	184072.42
2020-02	WEB	101	145712.83	142499.43
2020-03	STORE	67	94586.61	88549.13
2020-03	WEB	66	100275.74	96738.95
2020-04	STORE	64	86514.63	83804.24
2020-04	WEB	47	71825.82	68014.90
2020-05	STORE	113	166927.10	163914.43
2020-05	WEB	106	161456.29	157446.89
2020-06	STORE	190	275275.55	274093.23
2020-06	WEB	143	206361.22	205153.75
2020-07	STORE	268	395029.20	389063.72
2020-07	WEB	203	297873.12	292993.01
2020-08	STORE	253	386851.40	382627.16
2020-08	WEB	224	291552.75	284688.54
2020-09	STORE	208	294460.21	288057.20
2020-09	WEB	176	235061.69	229445.80
2020-10	STORE	189	262261.78	253933.42
2020-10	WEB	161	212698.89	202718.18
2020-11	STORE	232	334565.91	327206.65
2020-11	WEB	220	306188.01	300823.04
2020-12	STORE	252	343253.07	335618.94
2020-12	WEB	190	274912.50	268528.55
2021-01	STORE	207	306225.48	299390.83
2021-01	WEB	162	209126.70	206543.82
2021-02	STORE	168	244174.81	237693.57
2021-02	WEB	160	233784.66	231329.54
2021-03	STORE	205	277200.79	272292.44
2021-03	WEB	189	284946.77	280674.39
2021-04	STORE	267	386012.22	374591.44
2021-04	WEB	203	276132.05	266615.84
2021-05	STORE	308	456654.15	451381.74
2021-05	WEB	250	358226.94	351117.08
2021-06	STORE	338	465401.89	458595.95
2021-06	WEB	312	472331.40	467471.36
2021-07	STORE	424	575830.38	565966.58
2021-07	WEB	315	448907.34	440937.37
2021-08	STORE	407	569609.92	557886.31
2021-08	WEB	322	454078.10	442554.02
2021-09	STORE	268	356893.55	346313.23
2021-09	WEB	243	338047.04	331195.11
2021-10	STORE	263	385089.21	378012.17
2021-10	WEB	237	341619.20	327333.17
2021-11	STORE	309	442643.58	433961.20
2021-11	WEB	277	356344.28	347723.22
2021-12	STORE	340	526702.33	518193.12
2021-12	WEB	286	411817.00	402938.06
2022-01	STORE	237	316037.18	304561.98
2022-01	WEB	207	281033.86	272304.76
2022-02	STORE	233	327343.51	321892.85
2022-02	WEB	183	264385.19	257245.25
2022-03	STORE	269	388805.63	380449.11
2022-03	WEB	250	390396.79	381182.56
2022-04	STORE	309	429069.68	422558.74
2022-04	WEB	259	343217.09	335183.03
2022-05	STORE	392	539493.84	525939.87
2022-05	WEB	334	443304.36	437014.98
2022-06	STORE	440	613618.73	602048.69
2022-06	WEB	380	535754.36	520147.34
2022-07	STORE	490	700240.11	686825.65
2022-07	WEB	399	535925.16	528051.21
2022-08	STORE	497	677403.66	664014.26
2022-08	WEB	365	530009.55	514804.11
2022-09	STORE	352	535198.83	520825.80
2022-09	WEB	294	416090.44	402319.73
2022-10	STORE	307	427692.41	410914.11
2022-10	WEB	263	390293.00	377157.11
2022-11	STORE	391	513290.56	498235.90
2022-11	WEB	325	440116.93	434344.61
2022-12	STORE	397	545499.14	531384.69
2022-12	WEB	374	496936.70	488435.89
2023-01	STORE	287	408711.55	398474.06
2023-01	WEB	222	329389.20	312655.25
2023-02	STORE	214	316171.46	309824.38
2023-02	WEB	207	306535.58	297791.36
2023-03	STORE	316	430699.61	424308.12
2023-03	WEB	264	382756.64	374920.38
2023-04	STORE	336	490681.11	479090.86
2023-04	WEB	288	432778.50	424808.62
2023-05	STORE	412	612006.48	601210.58
2023-05	WEB	339	475258.30	466232.11
2023-06	STORE	467	706926.78	692977.73
2023-06	WEB	413	602603.78	591255.25
2023-07	STORE	596	888217.07	872971.81
2023-07	WEB	462	627909.45	615269.16
2023-08	STORE	513	725625.83	714512.24
2023-08	WEB	424	664742.11	652449.24
2023-09	STORE	404	575112.66	558133.94
2023-09	WEB	349	463858.44	445542.73
2023-10	STORE	394	575110.06	561242.50
2023-10	WEB	278	422939.42	408078.86
2023-11	STORE	453	628692.16	617336.61
2023-11	WEB	333	473179.10	459062.20
2023-12	STORE	491	666555.93	649543.39
2023-12	WEB	444	657699.37	645264.48
2024-01	STORE	323	490788.09	473457.87
2024-01	WEB	256	415973.51	407210.68
2024-02	STORE	292	369294.05	362291.98
2024-02	WEB	256	357126.82	345751.63
2024-03	STORE	401	574680.48	562512.18
2024-03	WEB	309	399273.42	389627.98
2024-04	STORE	389	589289.20	579996.78
2024-04	WEB	296	418912.85	407589.30
2024-05	STORE	490	685584.15	668876.37
2024-05	WEB	385	609002.79	601358.55
2024-06	STORE	544	763602.34	747210.29
2024-06	WEB	446	618005.49	606885.46
2024-07	STORE	612	897062.62	875974.01
2024-07	WEB	517	763566.01	742622.35
2024-08	STORE	607	857432.56	834576.05
2024-08	WEB	476	677886.93	665360.17
2024-09	STORE	433	643293.77	628382.56
2024-09	WEB	395	594696.88	578301.79
2024-10	STORE	390	547387.01	535003.88
2024-10	WEB	316	434891.64	419409.25
2024-11	STORE	512	744121.59	728815.02
2024-11	WEB	404	575978.19	561393.00
2024-12	STORE	605	854296.55	832866.12
2024-12	WEB	504	765970.54	749455.00
2025-01	STORE	320	433317.16	416710.96
2025-01	WEB	261	385406.66	363832.26
2025-02	STORE	306	434514.52	420575.12
2025-02	WEB	243	314683.84	305383.29
2025-03	STORE	422	625859.99	611842.01
2025-03	WEB	330	467853.31	455089.96
2025-04	STORE	434	650323.58	631257.54
2025-04	WEB	337	475128.84	467489.28
2025-05	STORE	575	856882.37	843388.35
2025-05	WEB	498	720729.32	708392.52
2025-06	STORE	572	837681.33	817176.32
2025-06	WEB	517	688524.36	674998.08
2025-07	STORE	677	918879.01	900027.36
2025-07	WEB	568	790078.24	774272.39
2025-08	STORE	662	886503.57	863043.88
2025-08	WEB	555	775225.60	761481.46
2025-09	STORE	564	850224.19	835264.60
2025-09	WEB	385	596419.43	574234.68
2025-10	STORE	484	707954.04	686068.05
2025-10	WEB	346	502965.78	481171.40
2025-11	STORE	537	792351.29	774328.46
2025-11	WEB	494	697343.57	682643.75
2025-12	STORE	586	835263.74	818863.40
2025-12	WEB	497	738092.74	721569.55
2026-01	STORE	367	524553.33	503025.64
2026-01	WEB	280	372374.65	356913.38
2026-02	STORE	303	445477.87	435815.76
2026-02	WEB	259	354091.06	343711.34
2026-03	STORE	467	651748.19	635608.98
2026-03	WEB	352	470143.63	462565.06
2026-04	STORE	464	658938.75	649641.12
2026-04	WEB	368	539855.57	530418.25
2026-05	STORE	543	805910.99	787935.59
2026-05	WEB	492	727662.64	719537.18
2026-06	STORE	643	945812.08	896812.27
2026-06	WEB	574	793764.78	751976.99
```

---

## Q03_r1_revenue_by_store.sql
```
store_id	store_code	city	state	order_count	gross_revenue	net_revenue
13	WEB	Online	WA	26438	37662991.83	36754095.68
1	SEA-PIKE	Seattle	WA	3295	4810385.30	4701699.20
2	SEA-BAL	Seattle	WA	3344	4757842.21	4661619.76
6	PDX-PRL	Portland	OR	3321	4678141.69	4569384.00
4	BEL-01	Bellevue	WA	3192	4603206.56	4495755.18
3	TAC-01	Tacoma	WA	3193	4572816.09	4469609.03
5	SPO-01	Spokane	WA	2897	4021410.04	3927331.28
7	PDX-HAW	Portland	OR	2624	3724235.84	3637217.51
8	EUG-01	Eugene	OR	2557	3588077.77	3502682.86
9	BOI-01	Boise	ID	2447	3489147.38	3408268.30
10	MSO-01	Missoula	MT	2246	3282689.18	3202443.84
11	BZN-01	Bozeman	MT	1681	2441938.49	2389723.80
12	BEN-01	Bend	OR	1065	1527295.60	1488694.41
```

WEB (store 13) dominates at 37.66M gross; the 12 physical stores follow, Seattle Pike first.

---

## Q04_r1_promo_share.sql
```
promo_flag	order_count	gross_revenue	revenue_share_pct
no_promo	51064	73956202.54	88.93
promo	7236	9203975.44	11.07
```

Promo orders carry 11.07% of gross revenue; shares sum to 100.00.

---

## Q05_r1_top15_months_mom.sql
```
sales_month	gross_revenue	mom_change	mom_change_pct
2026-06	1739576.86	206003.23	13.43
2025-07	1708957.25	182751.56	11.97
2025-08	1661729.17	-47228.08	-2.76
2024-07	1660628.63	279020.80	20.20
2024-12	1620267.09	300167.31	22.74
2025-05	1577611.69	452159.27	40.18
2025-12	1573356.48	83661.62	5.62
2024-08	1535319.49	-125309.14	-7.55
2026-05	1533573.63	334779.31	27.93
2025-06	1526205.69	-51406.00	-3.26
2023-07	1516126.52	206595.96	15.78
2025-11	1489694.86	278775.04	23.02
2025-09	1446643.62	-215085.55	-12.94
2023-08	1390367.94	-125758.58	-8.29
2024-06	1381607.83	87020.89	6.72
```

MoM change is computed on the full monthly series BEFORE the top-15 cut (so 2025-08's −2.76%
is vs 2025-07). Summer months and Decembers dominate, consistent with the R1 seasonality note.

---

## Q06_r2_product_kpis.sql
```
active_products	total_products	units_sold	gross_revenue	unit_return_rate_pct
590	850	359151	83160177.98	2.36
```

590 active products (DEF-009 discontinued_flag = 0; silver V02: 590 zeros) of 850 total;
359,151 units sold in DEF-003 scope; unit return rate 2.36% (DEF-007). "Median unit margin"
lives in Q14 (DEF-021, added by TASK-20260705-01) — the TASK-04 MISSING DEFINITION is closed;
Q06 itself is unchanged and byte-identical to its TASK-04 capture.

---

## Q07_r2_monthly_units_top5_categories.sql

Full row-level capture (TASK-20260705-02) — 450 data rows (90 months × top-5 categories),
ORDER BY sales_month, category_id (RULE-001). Replaces the retired aggregate signature;
regression vs that signature: SUM(units_sold) = 124694, SUM(gross_revenue) = 28938760.99,
category_ids {10,11,12,17,19} (Sleeping Bags, Camp Kitchen, Backpacks, Kayaks, Jackets) —
all identical, zero drift. Run twice, byte-identical.
```
sales_month	category_id	category_name	units_sold	gross_revenue
2019-01	10	Sleeping Bags	121	28383.35
2019-01	11	Camp Kitchen	146	31060.26
2019-01	12	Backpacks	80	18762.45
2019-01	17	Kayaks	91	20299.70
2019-01	19	Jackets	135	32208.69
2019-02	10	Sleeping Bags	92	22025.02
2019-02	11	Camp Kitchen	110	25197.84
2019-02	12	Backpacks	119	28481.39
2019-02	17	Kayaks	80	17831.45
2019-02	19	Jackets	132	30561.00
2019-03	10	Sleeping Bags	154	35510.43
2019-03	11	Camp Kitchen	123	27175.31
2019-03	12	Backpacks	174	37284.90
2019-03	17	Kayaks	123	33261.63
2019-03	19	Jackets	149	36559.33
2019-04	10	Sleeping Bags	156	34068.30
2019-04	11	Camp Kitchen	190	46719.43
2019-04	12	Backpacks	174	41205.38
2019-04	17	Kayaks	177	40185.55
2019-04	19	Jackets	157	36629.02
2019-05	10	Sleeping Bags	199	39316.30
2019-05	11	Camp Kitchen	136	31897.51
2019-05	12	Backpacks	157	39956.71
2019-05	17	Kayaks	128	29411.19
2019-05	19	Jackets	175	40186.61
2019-06	10	Sleeping Bags	230	59930.48
2019-06	11	Camp Kitchen	242	56920.23
2019-06	12	Backpacks	220	60578.04
2019-06	17	Kayaks	186	43678.70
2019-06	19	Jackets	219	52462.30
2019-07	10	Sleeping Bags	185	36356.14
2019-07	11	Camp Kitchen	214	50387.24
2019-07	12	Backpacks	201	45562.60
2019-07	17	Kayaks	165	33026.18
2019-07	19	Jackets	175	36898.32
2019-08	10	Sleeping Bags	232	49485.07
2019-08	11	Camp Kitchen	276	65303.63
2019-08	12	Backpacks	204	48492.47
2019-08	17	Kayaks	218	51643.67
2019-08	19	Jackets	212	49546.62
2019-09	10	Sleeping Bags	174	36547.10
2019-09	11	Camp Kitchen	137	32541.59
2019-09	12	Backpacks	147	27860.54
2019-09	17	Kayaks	151	33070.55
2019-09	19	Jackets	182	37748.87
2019-10	10	Sleeping Bags	130	29336.67
2019-10	11	Camp Kitchen	153	29107.00
2019-10	12	Backpacks	174	41057.95
2019-10	17	Kayaks	161	36526.27
2019-10	19	Jackets	179	36948.48
2019-11	10	Sleeping Bags	192	45673.38
2019-11	11	Camp Kitchen	153	30291.39
2019-11	12	Backpacks	127	33049.75
2019-11	17	Kayaks	152	38865.45
2019-11	19	Jackets	179	45185.20
2019-12	10	Sleeping Bags	209	52573.25
2019-12	11	Camp Kitchen	268	56521.47
2019-12	12	Backpacks	182	50150.77
2019-12	17	Kayaks	184	43571.67
2019-12	19	Jackets	142	32334.46
2020-01	10	Sleeping Bags	134	31508.64
2020-01	11	Camp Kitchen	120	30351.37
2020-01	12	Backpacks	95	23410.89
2020-01	17	Kayaks	122	28323.50
2020-01	19	Jackets	102	20556.51
2020-02	10	Sleeping Bags	110	32041.21
2020-02	11	Camp Kitchen	91	19435.61
2020-02	12	Backpacks	101	28819.43
2020-02	17	Kayaks	129	28494.13
2020-02	19	Jackets	114	22861.30
2020-03	10	Sleeping Bags	63	13141.54
2020-03	11	Camp Kitchen	73	15271.09
2020-03	12	Backpacks	55	13943.39
2020-03	17	Kayaks	52	9375.10
2020-03	19	Jackets	102	18119.56
2020-04	10	Sleeping Bags	29	8820.64
2020-04	11	Camp Kitchen	54	13016.63
2020-04	12	Backpacks	36	10918.73
2020-04	17	Kayaks	28	6627.42
2020-04	19	Jackets	68	13788.74
2020-05	10	Sleeping Bags	97	21359.74
2020-05	11	Camp Kitchen	91	21963.04
2020-05	12	Backpacks	111	20492.16
2020-05	17	Kayaks	100	26323.33
2020-05	19	Jackets	95	23469.35
2020-06	10	Sleeping Bags	154	39187.72
2020-06	11	Camp Kitchen	152	33091.56
2020-06	12	Backpacks	161	37739.44
2020-06	17	Kayaks	116	23580.23
2020-06	19	Jackets	135	29391.61
2020-07	10	Sleeping Bags	210	46826.10
2020-07	11	Camp Kitchen	238	55510.89
2020-07	12	Backpacks	240	53625.43
2020-07	17	Kayaks	207	39627.62
2020-07	19	Jackets	178	38973.64
2020-08	10	Sleeping Bags	200	49973.15
2020-08	11	Camp Kitchen	255	56159.83
2020-08	12	Backpacks	247	56896.52
2020-08	17	Kayaks	187	46006.55
2020-08	19	Jackets	207	42328.70
2020-09	10	Sleeping Bags	168	35681.17
2020-09	11	Camp Kitchen	163	35365.15
2020-09	12	Backpacks	166	42934.89
2020-09	17	Kayaks	138	33607.11
2020-09	19	Jackets	190	42088.53
2020-10	10	Sleeping Bags	120	28472.77
2020-10	11	Camp Kitchen	148	29450.05
2020-10	12	Backpacks	128	31022.79
2020-10	17	Kayaks	156	33729.12
2020-10	19	Jackets	206	45076.00
2020-11	10	Sleeping Bags	170	40079.87
2020-11	11	Camp Kitchen	200	42114.75
2020-11	12	Backpacks	220	57703.95
2020-11	17	Kayaks	204	44721.13
2020-11	19	Jackets	187	44250.17
2020-12	10	Sleeping Bags	182	41342.81
2020-12	11	Camp Kitchen	192	42779.84
2020-12	12	Backpacks	193	51302.25
2020-12	17	Kayaks	162	32886.50
2020-12	19	Jackets	186	41737.63
2021-01	10	Sleeping Bags	168	36604.82
2021-01	11	Camp Kitchen	150	35725.87
2021-01	12	Backpacks	174	44740.16
2021-01	17	Kayaks	106	21351.99
2021-01	19	Jackets	245	56091.16
2021-02	10	Sleeping Bags	103	21973.23
2021-02	11	Camp Kitchen	169	38406.15
2021-02	12	Backpacks	120	29420.19
2021-02	17	Kayaks	150	42677.67
2021-02	19	Jackets	171	40847.47
2021-03	10	Sleeping Bags	175	38286.52
2021-03	11	Camp Kitchen	152	29739.30
2021-03	12	Backpacks	168	35304.01
2021-03	17	Kayaks	149	34556.22
2021-03	19	Jackets	208	45902.72
2021-04	10	Sleeping Bags	189	44594.08
2021-04	11	Camp Kitchen	246	53150.61
2021-04	12	Backpacks	202	48569.22
2021-04	17	Kayaks	190	45956.75
2021-04	19	Jackets	194	45615.44
2021-05	10	Sleeping Bags	196	49640.14
2021-05	11	Camp Kitchen	237	58632.19
2021-05	12	Backpacks	242	56379.70
2021-05	17	Kayaks	223	54075.48
2021-05	19	Jackets	318	67310.21
2021-06	10	Sleeping Bags	265	55716.29
2021-06	11	Camp Kitchen	240	51682.13
2021-06	12	Backpacks	280	74809.63
2021-06	17	Kayaks	243	61337.73
2021-06	19	Jackets	286	62824.82
2021-07	10	Sleeping Bags	299	55058.67
2021-07	11	Camp Kitchen	298	69987.58
2021-07	12	Backpacks	377	102594.25
2021-07	17	Kayaks	282	72943.28
2021-07	19	Jackets	311	68488.61
2021-08	10	Sleeping Bags	322	78648.06
2021-08	11	Camp Kitchen	257	54228.33
2021-08	12	Backpacks	321	80030.66
2021-08	17	Kayaks	359	88749.67
2021-08	19	Jackets	343	69110.03
2021-09	10	Sleeping Bags	233	50178.86
2021-09	11	Camp Kitchen	225	54904.88
2021-09	12	Backpacks	257	63744.43
2021-09	17	Kayaks	200	47774.60
2021-09	19	Jackets	191	40977.96
2021-10	10	Sleeping Bags	255	60395.45
2021-10	11	Camp Kitchen	210	53219.09
2021-10	12	Backpacks	225	52105.17
2021-10	17	Kayaks	171	40173.60
2021-10	19	Jackets	291	61623.47
2021-11	10	Sleeping Bags	216	46929.79
2021-11	11	Camp Kitchen	237	53526.08
2021-11	12	Backpacks	262	63456.55
2021-11	17	Kayaks	174	37647.40
2021-11	19	Jackets	219	41294.16
2021-12	10	Sleeping Bags	284	61291.76
2021-12	11	Camp Kitchen	291	65946.82
2021-12	12	Backpacks	248	66328.37
2021-12	17	Kayaks	198	48830.07
2021-12	19	Jackets	355	77354.73
2022-01	10	Sleeping Bags	191	47468.80
2022-01	11	Camp Kitchen	210	43166.94
2022-01	12	Backpacks	172	37339.46
2022-01	17	Kayaks	210	47071.12
2022-01	19	Jackets	210	38709.98
2022-02	10	Sleeping Bags	196	51876.96
2022-02	11	Camp Kitchen	184	36970.14
2022-02	12	Backpacks	197	48256.60
2022-02	17	Kayaks	210	49281.24
2022-02	19	Jackets	157	39911.23
2022-03	10	Sleeping Bags	207	47786.37
2022-03	11	Camp Kitchen	232	46790.53
2022-03	12	Backpacks	226	55921.36
2022-03	17	Kayaks	171	38167.55
2022-03	19	Jackets	299	73991.15
2022-04	10	Sleeping Bags	198	47148.05
2022-04	11	Camp Kitchen	190	50471.74
2022-04	12	Backpacks	220	58681.67
2022-04	17	Kayaks	231	53233.36
2022-04	19	Jackets	266	62475.15
2022-05	10	Sleeping Bags	259	57238.13
2022-05	11	Camp Kitchen	342	80374.54
2022-05	12	Backpacks	296	70651.25
2022-05	17	Kayaks	289	62912.56
2022-05	19	Jackets	327	72180.13
2022-06	10	Sleeping Bags	286	76572.60
2022-06	11	Camp Kitchen	330	74840.64
2022-06	12	Backpacks	287	76628.14
2022-06	17	Kayaks	355	84515.58
2022-06	19	Jackets	340	79960.23
2022-07	10	Sleeping Bags	244	66866.13
2022-07	11	Camp Kitchen	411	93345.23
2022-07	12	Backpacks	413	100306.43
2022-07	17	Kayaks	357	88761.46
2022-07	19	Jackets	420	97289.37
2022-08	10	Sleeping Bags	345	77345.29
2022-08	11	Camp Kitchen	361	81895.36
2022-08	12	Backpacks	371	96479.24
2022-08	17	Kayaks	274	68698.73
2022-08	19	Jackets	417	90232.03
2022-09	10	Sleeping Bags	244	60752.23
2022-09	11	Camp Kitchen	238	49771.36
2022-09	12	Backpacks	311	75112.34
2022-09	17	Kayaks	265	67817.44
2022-09	19	Jackets	310	71946.62
2022-10	10	Sleeping Bags	244	57922.25
2022-10	11	Camp Kitchen	261	57039.84
2022-10	12	Backpacks	190	46301.44
2022-10	17	Kayaks	228	48330.52
2022-10	19	Jackets	308	65006.29
2022-11	10	Sleeping Bags	316	71041.04
2022-11	11	Camp Kitchen	298	61534.99
2022-11	12	Backpacks	328	75771.25
2022-11	17	Kayaks	245	62386.89
2022-11	19	Jackets	353	73180.38
2022-12	10	Sleeping Bags	390	81555.10
2022-12	11	Camp Kitchen	373	72963.17
2022-12	12	Backpacks	345	74577.61
2022-12	17	Kayaks	300	66450.92
2022-12	19	Jackets	398	81135.39
2023-01	10	Sleeping Bags	189	45048.39
2023-01	11	Camp Kitchen	221	47598.80
2023-01	12	Backpacks	234	55285.01
2023-01	17	Kayaks	234	55799.95
2023-01	19	Jackets	260	60267.95
2023-02	10	Sleeping Bags	168	45393.73
2023-02	11	Camp Kitchen	212	48039.56
2023-02	12	Backpacks	181	42852.39
2023-02	17	Kayaks	191	48768.92
2023-02	19	Jackets	178	40782.09
2023-03	10	Sleeping Bags	209	51600.44
2023-03	11	Camp Kitchen	308	75559.26
2023-03	12	Backpacks	272	66039.63
2023-03	17	Kayaks	223	51876.45
2023-03	19	Jackets	268	62575.29
2023-04	10	Sleeping Bags	247	64075.12
2023-04	11	Camp Kitchen	288	62253.41
2023-04	12	Backpacks	299	74592.29
2023-04	17	Kayaks	328	81294.87
2023-04	19	Jackets	278	60573.10
2023-05	10	Sleeping Bags	246	62579.87
2023-05	11	Camp Kitchen	334	83547.13
2023-05	12	Backpacks	274	65045.62
2023-05	17	Kayaks	306	81879.94
2023-05	19	Jackets	288	65548.37
2023-06	10	Sleeping Bags	353	80110.12
2023-06	11	Camp Kitchen	368	78135.73
2023-06	12	Backpacks	424	100472.98
2023-06	17	Kayaks	400	103148.36
2023-06	19	Jackets	375	87590.69
2023-07	10	Sleeping Bags	355	81661.36
2023-07	11	Camp Kitchen	484	101675.81
2023-07	12	Backpacks	430	101519.36
2023-07	17	Kayaks	507	122630.34
2023-07	19	Jackets	479	107483.71
2023-08	10	Sleeping Bags	400	94163.75
2023-08	11	Camp Kitchen	390	88760.58
2023-08	12	Backpacks	366	88204.48
2023-08	17	Kayaks	420	101247.12
2023-08	19	Jackets	431	97999.34
2023-09	10	Sleeping Bags	315	69465.30
2023-09	11	Camp Kitchen	322	67678.06
2023-09	12	Backpacks	281	56272.58
2023-09	17	Kayaks	291	74791.97
2023-09	19	Jackets	352	77511.33
2023-10	10	Sleeping Bags	260	64213.43
2023-10	11	Camp Kitchen	254	59614.15
2023-10	12	Backpacks	278	58613.67
2023-10	17	Kayaks	222	54468.32
2023-10	19	Jackets	389	94126.17
2023-11	10	Sleeping Bags	340	79989.44
2023-11	11	Camp Kitchen	338	76083.53
2023-11	12	Backpacks	326	81598.12
2023-11	17	Kayaks	316	76098.34
2023-11	19	Jackets	315	67869.71
2023-12	10	Sleeping Bags	398	93048.10
2023-12	11	Camp Kitchen	352	90693.72
2023-12	12	Backpacks	357	84218.91
2023-12	17	Kayaks	362	87592.89
2023-12	19	Jackets	341	80898.04
2024-01	10	Sleeping Bags	326	73880.69
2024-01	11	Camp Kitchen	207	55381.14
2024-01	12	Backpacks	235	56224.43
2024-01	17	Kayaks	243	59582.41
2024-01	19	Jackets	302	72650.66
2024-02	10	Sleeping Bags	163	38945.59
2024-02	11	Camp Kitchen	257	52856.46
2024-02	12	Backpacks	252	60214.28
2024-02	17	Kayaks	202	55350.83
2024-02	19	Jackets	256	53375.04
2024-03	10	Sleeping Bags	245	50614.63
2024-03	11	Camp Kitchen	299	64823.31
2024-03	12	Backpacks	314	83121.12
2024-03	17	Kayaks	305	68820.61
2024-03	19	Jackets	341	76441.38
2024-04	10	Sleeping Bags	225	55280.00
2024-04	11	Camp Kitchen	306	71235.43
2024-04	12	Backpacks	329	87090.35
2024-04	17	Kayaks	290	63318.85
2024-04	19	Jackets	358	84572.20
2024-05	10	Sleeping Bags	324	79269.57
2024-05	11	Camp Kitchen	352	71615.74
2024-05	12	Backpacks	470	117229.74
2024-05	17	Kayaks	325	72024.38
2024-05	19	Jackets	432	91691.99
2024-06	10	Sleeping Bags	410	92462.92
2024-06	11	Camp Kitchen	376	83131.06
2024-06	12	Backpacks	462	112228.28
2024-06	17	Kayaks	331	83329.39
2024-06	19	Jackets	467	95894.96
2024-07	10	Sleeping Bags	401	97285.96
2024-07	11	Camp Kitchen	553	124529.52
2024-07	12	Backpacks	479	109369.74
2024-07	17	Kayaks	492	122646.53
2024-07	19	Jackets	535	111853.17
2024-08	10	Sleeping Bags	383	95797.14
2024-08	11	Camp Kitchen	418	98677.77
2024-08	12	Backpacks	466	114052.84
2024-08	17	Kayaks	453	103981.70
2024-08	19	Jackets	546	120721.89
2024-09	10	Sleeping Bags	314	77826.17
2024-09	11	Camp Kitchen	407	88082.63
2024-09	12	Backpacks	301	76680.94
2024-09	17	Kayaks	323	85177.47
2024-09	19	Jackets	401	96496.62
2024-10	10	Sleeping Bags	295	73316.13
2024-10	11	Camp Kitchen	303	70150.65
2024-10	12	Backpacks	291	62946.65
2024-10	17	Kayaks	312	71200.71
2024-10	19	Jackets	266	62225.21
2024-11	10	Sleeping Bags	356	87250.69
2024-11	11	Camp Kitchen	463	101831.84
2024-11	12	Backpacks	397	100456.70
2024-11	17	Kayaks	375	101262.36
2024-11	19	Jackets	401	82398.76
2024-12	10	Sleeping Bags	418	94691.41
2024-12	11	Camp Kitchen	541	117761.75
2024-12	12	Backpacks	535	122865.91
2024-12	17	Kayaks	396	93175.61
2024-12	19	Jackets	512	112148.49
2025-01	10	Sleeping Bags	210	45483.37
2025-01	11	Camp Kitchen	270	68096.16
2025-01	12	Backpacks	210	50272.39
2025-01	17	Kayaks	172	36629.57
2025-01	19	Jackets	261	57051.97
2025-02	10	Sleeping Bags	181	36732.41
2025-02	11	Camp Kitchen	250	59507.10
2025-02	12	Backpacks	237	56136.19
2025-02	17	Kayaks	211	51820.05
2025-02	19	Jackets	238	55582.51
2025-03	10	Sleeping Bags	296	61391.61
2025-03	11	Camp Kitchen	311	63588.35
2025-03	12	Backpacks	327	71937.21
2025-03	17	Kayaks	318	70165.57
2025-03	19	Jackets	352	75922.71
2025-04	10	Sleeping Bags	196	47031.89
2025-04	11	Camp Kitchen	352	75096.97
2025-04	12	Backpacks	393	101200.71
2025-04	17	Kayaks	263	63376.35
2025-04	19	Jackets	333	73941.77
2025-05	10	Sleeping Bags	459	108119.72
2025-05	11	Camp Kitchen	499	122252.74
2025-05	12	Backpacks	407	94932.34
2025-05	17	Kayaks	473	119370.21
2025-05	19	Jackets	493	115286.96
2025-06	10	Sleeping Bags	437	91707.36
2025-06	11	Camp Kitchen	395	100455.13
2025-06	12	Backpacks	532	118549.08
2025-06	17	Kayaks	425	108584.37
2025-06	19	Jackets	429	102929.37
2025-07	10	Sleeping Bags	497	111287.90
2025-07	11	Camp Kitchen	527	108110.51
2025-07	12	Backpacks	525	119172.55
2025-07	17	Kayaks	471	117997.20
2025-07	19	Jackets	516	115303.05
2025-08	10	Sleeping Bags	554	112814.60
2025-08	11	Camp Kitchen	546	128378.07
2025-08	12	Backpacks	522	117220.15
2025-08	17	Kayaks	470	109021.58
2025-08	19	Jackets	582	116690.23
2025-09	10	Sleeping Bags	402	106091.22
2025-09	11	Camp Kitchen	384	92180.41
2025-09	12	Backpacks	404	93426.59
2025-09	17	Kayaks	440	114591.15
2025-09	19	Jackets	443	100449.40
2025-10	10	Sleeping Bags	329	75242.87
2025-10	11	Camp Kitchen	310	70318.92
2025-10	12	Backpacks	428	107105.14
2025-10	17	Kayaks	358	95740.82
2025-10	19	Jackets	358	78995.93
2025-11	10	Sleeping Bags	349	76029.43
2025-11	11	Camp Kitchen	450	107541.18
2025-11	12	Backpacks	498	126753.68
2025-11	17	Kayaks	423	99784.04
2025-11	19	Jackets	494	105501.24
2025-12	10	Sleeping Bags	497	118862.23
2025-12	11	Camp Kitchen	469	103831.44
2025-12	12	Backpacks	431	104710.78
2025-12	17	Kayaks	469	118930.20
2025-12	19	Jackets	446	103929.44
2026-01	10	Sleeping Bags	291	65356.84
2026-01	11	Camp Kitchen	271	63511.47
2026-01	12	Backpacks	265	62093.93
2026-01	17	Kayaks	294	69271.67
2026-01	19	Jackets	311	68712.00
2026-02	10	Sleeping Bags	229	52322.33
2026-02	11	Camp Kitchen	288	67427.02
2026-02	12	Backpacks	236	56898.74
2026-02	17	Kayaks	257	57239.38
2026-02	19	Jackets	278	59589.43
2026-03	10	Sleeping Bags	338	72977.93
2026-03	11	Camp Kitchen	382	88369.83
2026-03	12	Backpacks	445	103593.37
2026-03	17	Kayaks	336	78999.82
2026-03	19	Jackets	377	82084.55
2026-04	10	Sleeping Bags	351	82555.97
2026-04	11	Camp Kitchen	362	83820.89
2026-04	12	Backpacks	387	97883.77
2026-04	17	Kayaks	316	79683.12
2026-04	19	Jackets	384	90963.01
2026-05	10	Sleeping Bags	464	106445.12
2026-05	11	Camp Kitchen	426	96931.67
2026-05	12	Backpacks	420	109836.60
2026-05	17	Kayaks	452	113333.83
2026-05	19	Jackets	467	94018.27
2026-06	10	Sleeping Bags	563	137609.87
2026-06	11	Camp Kitchen	550	122683.29
2026-06	12	Backpacks	530	125001.95
2026-06	17	Kayaks	522	125174.20
2026-06	19	Jackets	529	114174.95
```

---

## Q08_r2_category_revenue_rollup.sql

RS1 — parent-category rollup; RS2 — leaf-category detail:
```
parent_category_id	parent_category_name	units_sold	gross_revenue
2	Hiking	70893	17066740.97
1	Camping	67275	15619384.28
6	Footwear	44934	10965816.94
4	Paddling	43814	10424721.51
5	Apparel	45758	10234089.00
3	Climbing	43374	9328127.04
8	Accessories	22168	5241080.64
7	Winter Sports	20935	4280217.60
parent_category_name	category_id	category_name	units_sold	gross_revenue
Hiking	12	Backpacks	25394	6128683.14
Apparel	19	Jackets	26805	5948192.32
Footwear	22	Trail Runners	22732	5783014.54
Camping	11	Camp Kitchen	25462	5747764.41
Paddling	17	Kayaks	23514	5657557.03
Hiking	13	Trekking Poles	22251	5565397.99
Camping	10	Sleeping Bags	23519	5456564.09
Hiking	14	Navigation	23248	5372659.84
Accessories	24	Water Bottles	22168	5241080.64
Footwear	21	Hiking Boots	22202	5182802.40
Climbing	15	Ropes & Harnesses	23248	5129180.73
Paddling	18	Paddles & PFDs	20300	4767164.48
Camping	9	Tents	18294	4415055.78
Apparel	20	Base Layers	18953	4285896.68
Winter Sports	23	Skis & Snowboards	20935	4280217.60
Climbing	16	Carabiners & Hardware	20126	4198946.31
```

RS1 gross across the 8 parents sums to 83,160,177.98 (= B05); Hiking leads at 17.07M.

---

## Q09_r2_price_vs_cost.sql

Full row-level capture (TASK-20260705-02) — 850 data rows (one per product, = the B01
products count), ORDER BY product_id (PK — RULE-001). Replaces the retired aggregate
signature; regression vs that signature: SUM(unit_cost) = 103962.91, SUM(list_price) =
203872.50, SUM(is_below_cost) = 17 (= the B06 D16 census exactly, RULE-008) — all
identical, zero drift. Run twice, byte-identical.
```
product_id	sku	category_name	unit_cost	list_price	is_below_cost
10001	OAK-BAC-8218	Backpacks	221.70	516.99	0
10002	OAK-BAC-4441	Backpacks	50.50	98.99	0
10003	OAK-CAM-8691	Camp Kitchen	97.14	225.99	0
10004	OAK-TRE-1744	Trekking Poles	215.64	418.99	0
10005	OAK-CAR-4241	Carabiners & Hardware	17.06	38.99	0
10006	OAK-SKI-3350	Skis & Snowboards	130.64	290.99	0
10007	OAK-TEN-1645	Tents	49.41	85.99	0
10008	OAK-BAS-5875	Base Layers	16.02	29.99	0
10009	OAK-CAR-3638	Carabiners & Hardware	219.90	398.99	0
10010	OAK-JAC-1260	Jackets	12.68	29.99	0
10011	OAK-WAT-7814	Water Bottles	215.35	477.99	0
10012	OAK-CAM-1132	Camp Kitchen	31.33	63.99	0
10013	OAK-ROP-6570	Ropes & Harnesses	33.10	63.99	0
10014	OAK-JAC-3206	Jackets	161.38	315.99	0
10015	SKU819998	Navigation	94.05	155.99	0
10016	OAK-SLE-1240	Sleeping Bags	194.55	368.99	0
10017	OAK-HIK-7050	Hiking Boots	175.66	294.99	0
10018	OAK-KAY-1186	Kayaks	139.38	295.99	0
10019	OAK-TRE-7948	Trekking Poles	110.05	240.99	0
10020	OAK-WAT-1373	Water Bottles	238.59	528.99	0
10021	OAK-JAC-0145	Jackets	221.86	382.99	0
10022	OAK-BAS-9275	Base Layers	17.19	33.99	0
10023	OAK-PAD-7369	Paddles & PFDs	217.49	495.99	0
10024	OAK-BAS-2090	Base Layers	23.32	38.99	0
10025	OAK-TRA-1182	Trail Runners	26.89	56.99	0
10026	OAK-ROP-2378	Ropes & Harnesses	45.91	90.99	0
10027	OAK-HIK-0434	Hiking Boots	153.19	295.99	0
10028	OAK-WAT-1282	Water Bottles	191.83	318.99	0
10029	OAK-BAS-5960	Base Layers	177.13	313.99	0
10030	OAK-TEN-2737	Tents	224.33	403.99	0
10031	SKU141697	Water Bottles	62.37	108.99	0
10032	OAK-TRA-5554	Trail Runners	163.00	309.99	0
10033	SKU521481	Backpacks	156.92	277.99	0
10034	OAK-HIK-2088	Hiking Boots	200.86	324.99	0
10035	OAK-TRA-6249	Trail Runners	66.70	52.99	1
10036	OAK-CAR-4407	Carabiners & Hardware	195.92	340.99	0
10037	OAK-TEN-5844	Tents	45.75	81.99	0
10038	OAK-CAM-2651	Camp Kitchen	191.63	403.99	0
10039	OAK-CAR-5570	Carabiners & Hardware	209.90	404.99	0
10040	OAK-JAC-3243	Jackets	71.34	156.99	0
10041	OAK-WAT-3275	Water Bottles	35.22	56.99	0
10042	OAK-BAS-3349	Base Layers	216.23	451.99	0
10043	OAK-BAC-4108	Backpacks	235.14	491.99	0
10044	OAK-WAT-5601	Water Bottles	55.99	120.99	0
10045	OAK-ROP-2878	Ropes & Harnesses	39.33	62.99	0
10046	OAK-JAC-5148	Jackets	194.67	329.99	0
10047	OAK-KAY-3730	Kayaks	38.24	74.99	0
10048	OAK-ROP-3417	Ropes & Harnesses	194.57	419.99	0
10049	SKU906547	Base Layers	98.33	181.99	0
10050	OAK-BAC-1364	Backpacks	109.27	257.99	0
10051	OAK-JAC-4651	Jackets	216.58	403.99	0
10052	OAK-CAM-6489	Camp Kitchen	48.28	97.99	0
10053	OAK-JAC-2023	Jackets	100.41	213.99	0
10054	OAK-NAV-1835	Navigation	46.28	94.99	0
10055	OAK-HIK-3767	Hiking Boots	220.32	385.99	0
10056	OAK-NAV-5330	Navigation	213.39	346.99	0
10057	OAK-TEN-5118	Tents	75.20	153.99	0
10058	OAK-WAT-7386	Water Bottles	209.65	474.99	0
10059	OAK-JAC-1904	Jackets	98.55	176.99	0
10060	SKU140578	Skis & Snowboards	78.83	149.99	0
10061	OAK-SLE-9903	Sleeping Bags	120.03	275.99	0
10062	OAK-CAR-5648	Carabiners & Hardware	73.31	169.99	0
10063	OAK-CAM-3768	Camp Kitchen	53.16	107.99	0
10064	OAK-PAD-5286	Paddles & PFDs	52.93	92.99	0
10065	OAK-NAV-2405	Navigation	37.09	87.99	0
10066	SKU566158	Kayaks	224.14	509.99	0
10067	OAK-ROP-7606	Ropes & Harnesses	94.14	160.99	0
10068	SKU110884	Navigation	192.31	426.99	0
10069	OAK-CAM-7633	Camp Kitchen	169.09	272.99	0
10070	OAK-JAC-6550	Jackets	188.04	423.99	0
10071	OAK-NAV-1897	Navigation	96.00	159.99	0
10072	OAK-CAR-6127	Carabiners & Hardware	139.74	254.99	0
10073	OAK-PAD-3511	Paddles & PFDs	127.00	248.99	0
10074	OAK-HIK-2007	Hiking Boots	31.68	64.99	0
10075	OAK-NAV-2204	Navigation	84.23	163.99	0
10076	OAK-NAV-4468	Navigation	4.97	10.99	0
10077	OAK-TEN-5800	Tents	190.97	352.99	0
10078	SKU143467	Camp Kitchen	30.98	62.99	0
10079	OAK-TRA-1784	Trail Runners	137.83	278.99	0
10080	OAK-WAT-4569	Water Bottles	165.57	312.99	0
10081	OAK-CAM-3196	Camp Kitchen	25.68	60.99	0
10082	SKU908998	Base Layers	145.98	324.99	0
10083	OAK-BAS-7286	Base Layers	17.87	32.99	0
10084	OAK-WAT-2139	Water Bottles	109.14	195.99	0
10085	OAK-CAR-6430	Carabiners & Hardware	102.78	182.99	0
10086	OAK-WAT-2473	Water Bottles	9.13	20.99	0
10087	OAK-TRE-8772	Trekking Poles	139.55	306.99	0
10088	OAK-BAS-5160	Base Layers	62.66	123.99	0
10089	OAK-SLE-8698	Sleeping Bags	13.07	28.99	0
10090	OAK-CAM-6180	Camp Kitchen	216.07	348.99	0
10091	OAK-CAM-7115	Camp Kitchen	214.91	478.99	0
10092	OAK-TRE-0135	Trekking Poles	155.89	287.99	0
10093	OAK-HIK-1547	Hiking Boots	101.37	190.99	0
10094	OAK-TRE-9820	Trekking Poles	176.65	305.99	0
10095	OAK-PAD-5241	Paddles & PFDs	22.70	47.99	0
10096	OAK-JAC-0623	Jackets	184.72	301.99	0
10097	OAK-BAS-6556	Base Layers	232.53	473.99	0
10098	OAK-CAR-9544	Carabiners & Hardware	100.21	192.99	0
10099	OAK-KAY-2568	Kayaks	40.04	89.99	0
10100	OAK-TRE-6839	Trekking Poles	210.81	365.99	0
10101	OAK-WAT-3554	Water Bottles	128.41	229.99	0
10102	OAK-TRA-0100	Trail Runners	125.63	288.99	0
10103	OAK-TRA-6684	Trail Runners	111.66	181.99	0
10104	OAK-ROP-7969	Ropes & Harnesses	94.77	174.99	0
10105	OAK-BAC-0435	Backpacks	121.81	257.99	0
10106	OAK-SKI-5139	Skis & Snowboards	174.96	300.99	0
10107	OAK-BAC-2508	Backpacks	5.58	11.99	0
10108	OAK-SLE-8696	Sleeping Bags	200.52	324.99	0
10109	SKU795683	Navigation	90.69	198.99	0
10110	OAK-CAM-8089	Camp Kitchen	62.07	136.99	0
10111	SKU736767	Sleeping Bags	196.89	428.99	0
10112	OAK-CAM-8833	Camp Kitchen	188.02	149.99	1
10113	OAK-KAY-6433	Kayaks	156.48	275.99	0
10114	OAK-JAC-9933	Jackets	146.95	284.99	0
10115	OAK-CAM-3396	Camp Kitchen	140.98	281.99	0
10116	OAK-CAM-8794	Camp Kitchen	79.94	151.99	0
10117	OAK-HIK-3410	Hiking Boots	18.26	36.99	0
10118	OAK-TRA-9608	Trail Runners	23.22	53.99	0
10119	OAK-PAD-5685	Paddles & PFDs	157.34	355.99	0
10120	OAK-BAS-9449	Base Layers	38.69	87.99	0
10121	SKU712350	Jackets	210.70	465.99	0
10122	OAK-WAT-0534	Water Bottles	237.35	462.99	0
10123	OAK-BAS-7557	Base Layers	145.75	304.99	0
10124	OAK-TEN-6293	Tents	183.22	352.99	0
10125	OAK-ROP-2640	Ropes & Harnesses	74.62	167.99	0
10126	OAK-NAV-0554	Navigation	167.44	391.99	0
10127	OAK-NAV-1884	Navigation	80.23	135.99	0
10128	OAK-TRA-1794	Trail Runners	175.88	362.99	0
10129	OAK-CAR-2263	Carabiners & Hardware	117.82	197.99	0
10130	OAK-SLE-8112	Sleeping Bags	131.03	259.99	0
10131	SKU874426	Ropes & Harnesses	160.56	269.99	0
10132	OAK-PAD-2918	Paddles & PFDs	156.39	268.99	0
10133	SKU114243	Sleeping Bags	237.95	443.99	0
10134	OAK-JAC-8304	Jackets	185.28	397.99	0
10135	OAK-HIK-1426	Hiking Boots	209.80	441.99	0
10136	OAK-CAR-9110	Carabiners & Hardware	162.23	284.99	0
10137	OAK-BAS-9124	Base Layers	20.27	43.99	0
10138	OAK-JAC-8947	Jackets	193.55	340.99	0
10139	OAK-BAC-0437	Backpacks	214.40	361.99	0
10140	OAK-KAY-0574	Kayaks	130.59	277.99	0
10141	OAK-TEN-5834	Tents	37.74	67.99	0
10142	OAK-TRA-6343	Trail Runners	223.57	524.99	0
10143	OAK-WAT-9859	Water Bottles	121.09	251.99	0
10144	OAK-TEN-1093	Tents	235.06	479.99	0
10145	OAK-BAC-5001	Backpacks	138.05	227.99	0
10146	OAK-TRA-9396	Trail Runners	224.27	388.99	0
10147	OAK-CAM-4733	Camp Kitchen	170.11	324.99	0
10148	OAK-TRE-6006	Trekking Poles	109.79	193.99	0
10149	OAK-NAV-3005	Navigation	146.64	270.99	0
10150	OAK-WAT-5703	Water Bottles	56.27	97.99	0
10151	SKU032905	Kayaks	90.76	162.99	0
10152	SKU523877	Jackets	21.38	46.99	0
10153	OAK-PAD-5080	Paddles & PFDs	144.13	297.99	0
10154	OAK-ROP-5274	Ropes & Harnesses	4.59	7.99	0
10155	OAK-CAR-7570	Carabiners & Hardware	136.57	232.99	0
10156	OAK-CAM-4481	Camp Kitchen	46.66	36.99	1
10157	OAK-TRA-5485	Trail Runners	183.82	362.99	0
10158	OAK-SLE-2615	Sleeping Bags	185.42	377.99	0
10159	OAK-SKI-9770	Skis & Snowboards	119.17	231.99	0
10160	OAK-KAY-3487	Kayaks	128.88	278.99	0
10161	OAK-TRA-6448	Trail Runners	181.87	357.99	0
10162	OAK-NAV-5867	Navigation	151.79	250.99	0
10163	OAK-SLE-0647	Sleeping Bags	35.15	81.99	0
10164	OAK-ROP-3997	Ropes & Harnesses	239.06	524.99	0
10165	OAK-ROP-3365	Ropes & Harnesses	179.68	430.99	0
10166	OAK-TRA-7769	Trail Runners	91.63	150.99	0
10167	OAK-PAD-7545	Paddles & PFDs	84.47	138.99	0
10168	OAK-TRE-3622	Trekking Poles	104.89	167.99	0
10169	OAK-ROP-9964	Ropes & Harnesses	144.70	304.99	0
10170	OAK-CAR-3213	Carabiners & Hardware	31.44	50.99	0
10171	OAK-CAM-0611	Camp Kitchen	14.12	26.99	0
10172	SKU335275	Tents	50.38	92.99	0
10173	OAK-ROP-7227	Ropes & Harnesses	236.31	399.99	0
10174	OAK-TEN-1539	Tents	112.88	234.99	0
10175	OAK-JAC-1450	Jackets	32.22	69.99	0
10176	OAK-HIK-8754	Hiking Boots	235.80	391.99	0
10177	OAK-JAC-0754	Jackets	129.65	103.99	1
10178	OAK-TRE-4450	Trekking Poles	196.67	433.99	0
10179	OAK-NAV-2157	Navigation	197.67	470.99	0
10180	OAK-JAC-3149	Jackets	111.65	194.99	0
10181	OAK-JAC-6873	Jackets	17.89	36.99	0
10182	OAK-SKI-6737	Skis & Snowboards	149.51	320.99	0
10183	SKU098380	Trekking Poles	113.84	213.99	0
10184	OAK-CAM-0721	Camp Kitchen	102.42	208.99	0
10185	SKU570042	Hiking Boots	15.27	26.99	0
10186	OAK-BAC-6764	Backpacks	181.49	333.99	0
10187	OAK-NAV-2199	Navigation	194.74	346.99	0
10188	OAK-KAY-0436	Kayaks	17.26	30.99	0
10189	OAK-ROP-5303	Ropes & Harnesses	79.31	141.99	0
10190	SKU563673	Skis & Snowboards	20.60	37.99	0
10191	OAK-PAD-1289	Paddles & PFDs	188.74	427.99	0
10192	OAK-HIK-9734	Hiking Boots	14.64	23.99	0
10193	SKU023412	Trekking Poles	27.53	47.99	0
10194	OAK-JAC-6530	Jackets	181.31	406.99	0
10195	OAK-WAT-6694	Water Bottles	154.81	274.99	0
10196	OAK-SLE-0259	Sleeping Bags	202.96	395.99	0
10197	OAK-HIK-9956	Hiking Boots	129.84	240.99	0
10198	SKU487490	Sleeping Bags	189.44	305.99	0
10199	OAK-KAY-1613	Kayaks	141.84	286.99	0
10200	OAK-WAT-4701	Water Bottles	210.26	429.99	0
10201	SKU153883	Trail Runners	88.79	194.99	0
10202	OAK-NAV-8113	Navigation	23.92	46.99	0
10203	OAK-JAC-1223	Jackets	185.35	421.99	0
10204	OAK-ROP-2233	Ropes & Harnesses	173.37	326.99	0
10205	OAK-ROP-1525	Ropes & Harnesses	85.45	189.99	0
10206	OAK-CAR-6580	Carabiners & Hardware	144.21	252.99	0
10207	OAK-BAS-1201	Base Layers	22.82	43.99	0
10208	OAK-JAC-5663	Jackets	179.48	407.99	0
10209	OAK-NAV-2093	Navigation	158.33	365.99	0
10210	OAK-SLE-2877	Sleeping Bags	232.82	514.99	0
10211	OAK-ROP-1837	Ropes & Harnesses	40.32	91.99	0
10212	SKU298673	Navigation	171.75	308.99	0
10213	OAK-CAR-3379	Carabiners & Hardware	48.54	102.99	0
10214	OAK-JAC-8591	Jackets	118.09	266.99	0
10215	OAK-JAC-9140	Jackets	65.49	136.99	0
10216	OAK-SKI-4906	Skis & Snowboards	138.54	287.99	0
10217	OAK-TRE-4738	Trekking Poles	15.32	32.99	0
10218	OAK-JAC-7359	Jackets	115.09	203.99	0
10219	OAK-HIK-5406	Hiking Boots	214.43	373.99	0
10220	OAK-CAM-4223	Camp Kitchen	10.66	19.99	0
10221	OAK-JAC-7239	Jackets	223.33	476.99	0
10222	OAK-KAY-5037	Kayaks	128.27	283.99	0
10223	OAK-SKI-2226	Skis & Snowboards	11.99	24.99	0
10224	OAK-TRE-2601	Trekking Poles	71.92	140.99	0
10225	OAK-BAC-1761	Backpacks	127.66	296.99	0
10226	OAK-BAC-9834	Backpacks	109.00	174.99	0
10227	SKU331453	Base Layers	79.15	62.99	1
10228	OAK-HIK-7621	Hiking Boots	8.42	16.99	0
10229	OAK-TRE-2490	Trekking Poles	23.85	48.99	0
10230	OAK-CAM-0646	Camp Kitchen	137.38	279.99	0
10231	SKU904245	Skis & Snowboards	8.10	16.99	0
10232	OAK-CAR-6421	Carabiners & Hardware	10.24	18.99	0
10233	OAK-BAC-0603	Backpacks	127.63	297.99	0
10234	OAK-ROP-3214	Ropes & Harnesses	218.49	503.99	0
10235	OAK-TRE-8552	Trekking Poles	203.76	358.99	0
10236	OAK-JAC-8935	Jackets	129.15	266.99	0
10237	OAK-KAY-4165	Kayaks	223.88	412.99	0
10238	SKU594992	Camp Kitchen	203.58	415.99	0
10239	OAK-HIK-6006	Hiking Boots	79.60	183.99	0
10240	OAK-CAM-7177	Camp Kitchen	125.97	297.99	0
10241	OAK-KAY-4781	Kayaks	190.07	436.99	0
10242	OAK-HIK-5240	Hiking Boots	212.48	474.99	0
10243	OAK-JAC-2678	Jackets	176.18	361.99	0
10244	OAK-ROP-4381	Ropes & Harnesses	209.65	439.99	0
10245	OAK-TEN-6853	Tents	38.28	74.99	0
10246	OAK-TRA-8775	Trail Runners	93.25	216.99	0
10247	SKU501782	Backpacks	119.83	257.99	0
10248	OAK-PAD-7211	Paddles & PFDs	141.61	326.99	0
10249	OAK-PAD-3772	Paddles & PFDs	130.89	247.99	0
10250	OAK-SLE-9693	Sleeping Bags	101.56	187.99	0
10251	OAK-KAY-5327	Kayaks	159.98	379.99	0
10252	OAK-SLE-5725	Sleeping Bags	52.24	91.99	0
10253	OAK-SLE-0260	Sleeping Bags	197.26	335.99	0
10254	OAK-CAM-3212	Camp Kitchen	27.44	63.99	0
10255	OAK-HIK-2034	Hiking Boots	67.87	123.99	0
10256	OAK-TRA-3290	Trail Runners	92.71	154.99	0
10257	OAK-ROP-1040	Ropes & Harnesses	193.21	359.99	0
10258	OAK-CAR-1600	Carabiners & Hardware	9.16	17.99	0
10259	SKU148421	Backpacks	18.58	38.99	0
10260	OAK-TRE-6821	Trekking Poles	169.52	399.99	0
10261	OAK-SLE-2258	Sleeping Bags	44.13	87.99	0
10262	OAK-WAT-4741	Water Bottles	149.66	311.99	0
10263	SKU541929	Jackets	173.20	316.99	0
10264	OAK-CAM-6760	Camp Kitchen	13.99	31.99	0
10265	OAK-NAV-9528	Navigation	46.25	104.99	0
10266	OAK-PAD-5379	Paddles & PFDs	121.84	209.99	0
10267	OAK-TRE-4002	Trekking Poles	33.30	76.99	0
10268	SKU366366	Skis & Snowboards	25.20	59.99	0
10269	OAK-HIK-6083	Hiking Boots	151.35	300.99	0
10270	SKU202942	Hiking Boots	186.72	438.99	0
10271	OAK-WAT-7311	Water Bottles	133.23	316.99	0
10272	OAK-CAR-8118	Carabiners & Hardware	238.43	411.99	0
10273	OAK-HIK-3445	Hiking Boots	229.21	372.99	0
10274	OAK-WAT-9464	Water Bottles	72.94	122.99	0
10275	OAK-ROP-1551	Ropes & Harnesses	47.57	92.99	0
10276	OAK-BAC-4140	Backpacks	46.90	95.99	0
10277	OAK-JAC-4756	Jackets	76.76	139.99	0
10278	OAK-JAC-9732	Jackets	22.28	39.99	0
10279	OAK-JAC-1858	Jackets	84.36	186.99	0
10280	OAK-SLE-8109	Sleeping Bags	31.68	61.99	0
10281	OAK-KAY-7804	Kayaks	95.51	225.99	0
10282	OAK-TEN-8568	Tents	57.74	94.99	0
10283	OAK-TRA-7024	Trail Runners	129.14	258.99	0
10284	OAK-BAS-4942	Base Layers	197.55	371.99	0
10285	OAK-KAY-9569	Kayaks	53.21	93.99	0
10286	OAK-BAC-6167	Backpacks	46.46	75.99	0
10287	OAK-TRE-4627	Trekking Poles	114.83	220.99	0
10288	OAK-HIK-0473	Hiking Boots	9.53	19.99	0
10289	OAK-TEN-2763	Tents	188.55	363.99	0
10290	OAK-NAV-8530	Navigation	14.43	34.99	0
10291	OAK-TRE-5331	Trekking Poles	110.06	212.99	0
10292	OAK-SLE-0250	Sleeping Bags	161.44	307.99	0
10293	OAK-TRA-2532	Trail Runners	225.50	375.99	0
10294	OAK-NAV-7172	Navigation	56.14	114.99	0
10295	OAK-TEN-2146	Tents	165.09	288.99	0
10296	OAK-CAR-3351	Carabiners & Hardware	157.97	319.99	0
10297	OAK-SKI-5760	Skis & Snowboards	100.38	170.99	0
10298	OAK-ROP-5033	Ropes & Harnesses	165.71	345.99	0
10299	OAK-BAC-5191	Backpacks	58.88	120.99	0
10300	OAK-ROP-9972	Ropes & Harnesses	36.89	75.99	0
10301	OAK-HIK-6866	Hiking Boots	107.44	205.99	0
10302	OAK-ROP-1705	Ropes & Harnesses	9.60	20.99	0
10303	OAK-TEN-6720	Tents	191.16	315.99	0
10304	OAK-KAY-1894	Kayaks	238.41	442.99	0
10305	OAK-BAC-2899	Backpacks	128.73	232.99	0
10306	SKU870886	Trail Runners	145.01	324.99	0
10307	OAK-WAT-8104	Water Bottles	135.12	276.99	0
10308	OAK-NAV-4425	Navigation	166.27	329.99	0
10309	SKU465512	Camp Kitchen	97.51	175.99	0
10310	OAK-SLE-0549	Sleeping Bags	11.87	26.99	0
10311	OAK-CAM-4819	Camp Kitchen	23.66	47.99	0
10312	SKU431969	Kayaks	182.31	412.99	0
10313	OAK-SLE-4554	Sleeping Bags	200.37	380.99	0
10314	OAK-PAD-1675	Paddles & PFDs	78.01	139.99	0
10315	OAK-SLE-0007	Sleeping Bags	217.87	522.99	0
10316	OAK-KAY-5134	Kayaks	61.33	113.99	0
10317	OAK-TRA-3795	Trail Runners	186.16	310.99	0
10318	OAK-TRE-5284	Trekking Poles	148.21	273.99	0
10319	OAK-BAS-3735	Base Layers	61.61	108.99	0
10320	OAK-SLE-1039	Sleeping Bags	13.46	28.99	0
10321	OAK-TRE-2278	Trekking Poles	216.20	426.99	0
10322	OAK-SLE-8179	Sleeping Bags	199.65	344.99	0
10323	SKU562338	Water Bottles	159.47	376.99	0
10324	OAK-CAR-4893	Carabiners & Hardware	85.71	194.99	0
10325	OAK-TRE-3681	Trekking Poles	138.56	313.99	0
10326	OAK-JAC-5773	Jackets	164.54	303.99	0
10327	OAK-TRE-9723	Trekking Poles	99.77	164.99	0
10328	OAK-SKI-6510	Skis & Snowboards	203.11	352.99	0
10329	OAK-SKI-3392	Skis & Snowboards	144.11	342.99	0
10330	OAK-BAC-0524	Backpacks	83.46	151.99	0
10331	OAK-JAC-0123	Jackets	130.90	210.99	0
10332	OAK-BAC-3472	Backpacks	33.91	74.99	0
10333	OAK-SKI-0836	Skis & Snowboards	103.99	181.99	0
10334	OAK-TRE-9620	Trekking Poles	192.36	316.99	0
10335	OAK-WAT-4643	Water Bottles	212.89	451.99	0
10336	OAK-BAS-0449	Base Layers	89.25	211.99	0
10337	OAK-PAD-4336	Paddles & PFDs	226.83	535.99	0
10338	OAK-TEN-5737	Tents	49.19	93.99	0
10339	OAK-BAC-1850	Backpacks	161.07	378.99	0
10340	OAK-TRA-3366	Trail Runners	201.57	323.99	0
10341	OAK-JAC-4237	Jackets	54.82	111.99	0
10342	OAK-KAY-7703	Kayaks	145.22	282.99	0
10343	OAK-TEN-6114	Tents	227.88	447.99	0
10344	OAK-WAT-8552	Water Bottles	90.99	174.99	0
10345	OAK-SLE-7467	Sleeping Bags	224.13	507.99	0
10346	OAK-ROP-7678	Ropes & Harnesses	178.99	301.99	0
10347	OAK-JAC-1481	Jackets	78.14	146.99	0
10348	OAK-SKI-5656	Skis & Snowboards	224.09	523.99	0
10349	OAK-WAT-0170	Water Bottles	207.37	372.99	0
10350	SKU026622	Trekking Poles	146.70	329.99	0
10351	OAK-BAC-3943	Backpacks	78.94	144.99	0
10352	OAK-JAC-0462	Jackets	8.38	15.99	0
10353	OAK-HIK-4299	Hiking Boots	17.22	29.99	0
10354	SKU064950	Camp Kitchen	29.38	67.99	0
10355	OAK-TEN-2558	Tents	154.94	273.99	0
10356	OAK-KAY-3751	Kayaks	23.78	47.99	0
10357	OAK-SLE-7457	Sleeping Bags	117.87	190.99	0
10358	OAK-TRE-2014	Trekking Poles	18.85	38.99	0
10359	OAK-CAR-5699	Carabiners & Hardware	132.85	282.99	0
10360	OAK-HIK-8610	Hiking Boots	214.82	429.99	0
10361	OAK-TRA-5832	Trail Runners	152.91	333.99	0
10362	SKU284437	Backpacks	194.65	387.99	0
10363	OAK-KAY-9498	Kayaks	160.28	285.99	0
10364	OAK-CAM-2516	Camp Kitchen	230.93	462.99	0
10365	OAK-PAD-8528	Paddles & PFDs	100.92	225.99	0
10366	OAK-TRA-6896	Trail Runners	74.08	135.99	0
10367	OAK-HIK-3309	Hiking Boots	212.26	478.99	0
10368	OAK-SLE-2766	Sleeping Bags	204.57	377.99	0
10369	OAK-BAC-0111	Backpacks	133.38	287.99	0
10370	OAK-CAR-1223	Carabiners & Hardware	13.94	29.99	0
10371	OAK-CAR-3533	Carabiners & Hardware	61.80	147.99	0
10372	SKU688127	Kayaks	231.27	500.99	0
10373	OAK-TRE-4053	Trekking Poles	102.59	205.99	0
10374	OAK-CAR-2318	Carabiners & Hardware	55.28	95.99	0
10375	OAK-ROP-4479	Ropes & Harnesses	142.28	302.99	0
10376	OAK-CAR-0392	Carabiners & Hardware	91.97	149.99	0
10377	OAK-SKI-9922	Skis & Snowboards	105.82	214.99	0
10378	OAK-TRA-8058	Trail Runners	102.79	211.99	0
10379	OAK-BAS-1172	Base Layers	158.00	331.99	0
10380	OAK-SLE-1362	Sleeping Bags	20.14	33.99	0
10381	OAK-HIK-7029	Hiking Boots	192.23	414.99	0
10382	OAK-SKI-8375	Skis & Snowboards	206.78	445.99	0
10383	OAK-HIK-4884	Hiking Boots	108.22	86.99	1
10384	OAK-TRA-7356	Trail Runners	238.17	503.99	0
10385	OAK-WAT-3765	Water Bottles	208.77	166.99	1
10386	OAK-CAM-2501	Camp Kitchen	65.10	146.99	0
10387	OAK-TRA-3010	Trail Runners	113.29	209.99	0
10388	OAK-TRA-1086	Trail Runners	86.30	167.99	0
10389	OAK-PAD-6969	Paddles & PFDs	77.51	130.99	0
10390	OAK-JAC-2202	Jackets	154.56	250.99	0
10391	OAK-BAS-4608	Base Layers	56.42	100.99	0
10392	OAK-SKI-1458	Skis & Snowboards	93.07	162.99	0
10393	OAK-SLE-2448	Sleeping Bags	7.61	12.99	0
10394	SKU410318	Trail Runners	10.66	18.99	0
10395	OAK-JAC-8221	Jackets	180.86	363.99	0
10396	OAK-TEN-8696	Tents	152.92	333.99	0
10397	OAK-PAD-4892	Paddles & PFDs	208.71	347.99	0
10398	OAK-KAY-6113	Kayaks	224.26	503.99	0
10399	OAK-PAD-1937	Paddles & PFDs	157.41	352.99	0
10400	OAK-CAM-9991	Camp Kitchen	204.64	451.99	0
10401	OAK-HIK-1668	Hiking Boots	97.82	211.99	0
10402	OAK-SKI-7405	Skis & Snowboards	211.56	386.99	0
10403	OAK-KAY-8190	Kayaks	51.45	88.99	0
10404	OAK-WAT-3338	Water Bottles	132.00	231.99	0
10405	OAK-SLE-2123	Sleeping Bags	214.29	354.99	0
10406	OAK-CAM-8653	Camp Kitchen	108.28	192.99	0
10407	OAK-BAS-0460	Base Layers	214.53	171.99	1
10408	OAK-SKI-4868	Skis & Snowboards	44.79	94.99	0
10409	OAK-SLE-2188	Sleeping Bags	26.69	58.99	0
10410	OAK-PAD-1996	Paddles & PFDs	207.27	332.99	0
10411	OAK-KAY-5656	Kayaks	62.07	112.99	0
10412	OAK-KAY-1063	Kayaks	63.94	138.99	0
10413	OAK-TRE-7122	Trekking Poles	21.80	48.99	0
10414	OAK-BAC-6078	Backpacks	115.09	267.99	0
10415	OAK-PAD-2404	Paddles & PFDs	61.88	145.99	0
10416	SKU537376	Skis & Snowboards	90.20	167.99	0
10417	OAK-SKI-1723	Skis & Snowboards	141.93	312.99	0
10418	OAK-WAT-4204	Water Bottles	197.95	347.99	0
10419	OAK-BAS-2676	Base Layers	38.31	72.99	0
10420	OAK-BAC-4355	Backpacks	87.39	168.99	0
10421	SKU981341	Hiking Boots	207.07	458.99	0
10422	OAK-CAR-1762	Carabiners & Hardware	220.70	435.99	0
10423	OAK-TRA-0887	Trail Runners	12.10	19.99	0
10424	OAK-CAM-5020	Camp Kitchen	201.00	399.99	0
10425	SKU778089	Water Bottles	176.83	310.99	0
10426	OAK-PAD-7420	Paddles & PFDs	58.10	123.99	0
10427	OAK-SKI-3325	Skis & Snowboards	62.58	144.99	0
10428	OAK-JAC-3039	Jackets	84.04	191.99	0
10429	OAK-CAR-0285	Carabiners & Hardware	9.12	16.99	0
10430	OAK-TEN-4874	Tents	150.24	319.99	0
10431	OAK-BAC-0533	Backpacks	11.96	22.99	0
10432	OAK-PAD-5845	Paddles & PFDs	18.41	33.99	0
10433	SKU387144	Water Bottles	55.55	120.99	0
10434	OAK-NAV-4414	Navigation	158.32	307.99	0
10435	SKU602987	Skis & Snowboards	8.66	16.99	0
10436	SKU725413	Navigation	132.21	246.99	0
10437	OAK-CAM-1108	Camp Kitchen	110.93	250.99	0
10438	OAK-ROP-5512	Ropes & Harnesses	17.21	29.99	0
10439	OAK-WAT-6929	Water Bottles	223.38	466.99	0
10440	OAK-WAT-2075	Water Bottles	237.62	501.99	0
10441	OAK-HIK-5171	Hiking Boots	156.12	349.99	0
10442	OAK-PAD-4891	Paddles & PFDs	210.40	366.99	0
10443	OAK-BAC-0440	Backpacks	79.56	137.99	0
10444	OAK-KAY-7076	Kayaks	236.51	446.99	0
10445	OAK-JAC-2847	Jackets	51.97	101.99	0
10446	OAK-SLE-4509	Sleeping Bags	48.68	82.99	0
10447	OAK-KAY-4276	Kayaks	138.74	312.99	0
10448	OAK-CAR-3080	Carabiners & Hardware	165.38	285.99	0
10449	OAK-HIK-2967	Hiking Boots	68.02	157.99	0
10450	OAK-JAC-9200	Jackets	188.29	378.99	0
10451	OAK-CAM-2320	Camp Kitchen	26.73	54.99	0
10452	OAK-BAS-0780	Base Layers	182.04	324.99	0
10453	OAK-SLE-8080	Sleeping Bags	163.03	296.99	0
10454	OAK-HIK-6635	Hiking Boots	111.35	184.99	0
10455	OAK-TRE-6899	Trekking Poles	90.70	216.99	0
10456	OAK-TEN-6584	Tents	109.57	213.99	0
10457	OAK-BAC-3829	Backpacks	157.08	264.99	0
10458	OAK-TEN-2450	Tents	44.44	81.99	0
10459	OAK-ROP-2287	Ropes & Harnesses	85.19	176.99	0
10460	OAK-CAR-8310	Carabiners & Hardware	44.85	84.99	0
10461	OAK-TEN-2375	Tents	136.70	287.99	0
10462	OAK-NAV-4556	Navigation	86.59	156.99	0
10463	OAK-HIK-4112	Hiking Boots	176.45	405.99	0
10464	OAK-TRE-7928	Trekking Poles	123.57	202.99	0
10465	OAK-BAS-1122	Base Layers	90.62	152.99	0
10466	OAK-NAV-6851	Navigation	209.25	381.99	0
10467	OAK-SLE-9002	Sleeping Bags	16.26	35.99	0
10468	OAK-BAC-5524	Backpacks	130.69	308.99	0
10469	OAK-BAC-0935	Backpacks	17.39	40.99	0
10470	OAK-SLE-7252	Sleeping Bags	208.74	456.99	0
10471	OAK-KAY-7634	Kayaks	18.78	43.99	0
10472	OAK-CAR-3025	Carabiners & Hardware	49.34	91.99	0
10473	OAK-SKI-7296	Skis & Snowboards	95.59	194.99	0
10474	OAK-CAR-7804	Carabiners & Hardware	173.51	285.99	0
10475	OAK-TRE-3174	Trekking Poles	141.13	310.99	0
10476	OAK-CAM-2439	Camp Kitchen	178.00	293.99	0
10477	OAK-TEN-9740	Tents	237.22	457.99	0
10478	SKU260793	Sleeping Bags	232.95	374.99	0
10479	OAK-SKI-8070	Skis & Snowboards	55.83	119.99	0
10480	OAK-CAM-6190	Camp Kitchen	110.35	231.99	0
10481	OAK-TEN-7604	Tents	12.18	9.99	1
10482	OAK-ROP-1483	Ropes & Harnesses	159.03	315.99	0
10483	OAK-TRE-3449	Trekking Poles	226.54	460.99	0
10484	OAK-BAC-6380	Backpacks	84.85	199.99	0
10485	OAK-PAD-7174	Paddles & PFDs	209.53	451.99	0
10486	OAK-SKI-8330	Skis & Snowboards	194.76	445.99	0
10487	OAK-HIK-3262	Hiking Boots	90.82	72.99	1
10488	OAK-CAR-0448	Carabiners & Hardware	160.49	380.99	0
10489	OAK-PAD-9398	Paddles & PFDs	165.00	290.99	0
10490	OAK-NAV-3817	Navigation	212.47	382.99	0
10491	SKU584645	Camp Kitchen	202.92	468.99	0
10492	SKU356312	Hiking Boots	168.58	349.99	0
10493	OAK-SKI-0708	Skis & Snowboards	141.73	112.99	1
10494	OAK-PAD-0805	Paddles & PFDs	41.36	81.99	0
10495	OAK-TRE-9587	Trekking Poles	211.38	357.99	0
10496	OAK-KAY-9766	Kayaks	132.34	311.99	0
10497	OAK-TRA-0055	Trail Runners	36.23	68.99	0
10498	OAK-WAT-9972	Water Bottles	20.92	37.99	0
10499	SKU636087	Carabiners & Hardware	200.91	372.99	0
10500	OAK-SLE-8431	Sleeping Bags	52.86	98.99	0
10501	OAK-HIK-1371	Hiking Boots	8.06	17.99	0
10502	OAK-JAC-8381	Jackets	143.76	318.99	0
10503	SKU884583	Jackets	200.72	358.99	0
10504	OAK-TEN-7821	Tents	202.66	480.99	0
10505	OAK-TRA-8214	Trail Runners	197.97	157.99	1
10506	OAK-PAD-5314	Paddles & PFDs	45.82	84.99	0
10507	OAK-NAV-1943	Navigation	192.78	331.99	0
10508	OAK-BAS-7559	Base Layers	180.02	331.99	0
10509	OAK-TRA-3013	Trail Runners	186.99	407.99	0
10510	OAK-NAV-6769	Navigation	81.81	188.99	0
10511	SKU684892	Trail Runners	101.85	171.99	0
10512	OAK-BAS-4386	Base Layers	96.80	177.99	0
10513	OAK-PAD-4406	Paddles & PFDs	120.79	268.99	0
10514	OAK-SLE-6117	Sleeping Bags	46.76	110.99	0
10515	OAK-HIK-6793	Hiking Boots	15.16	35.99	0
10516	OAK-PAD-2942	Paddles & PFDs	14.51	31.99	0
10517	OAK-NAV-0920	Navigation	78.65	152.99	0
10518	OAK-ROP-5559	Ropes & Harnesses	149.53	266.99	0
10519	OAK-BAS-8595	Base Layers	162.67	320.99	0
10520	SKU453852	Trail Runners	44.81	94.99	0
10521	SKU319902	Skis & Snowboards	219.20	429.99	0
10522	OAK-ROP-6998	Ropes & Harnesses	137.41	312.99	0
10523	OAK-CAR-4866	Carabiners & Hardware	164.27	281.99	0
10524	SKU199612	Kayaks	184.11	364.99	0
10525	OAK-KAY-9897	Kayaks	220.11	358.99	0
10526	OAK-ROP-1632	Ropes & Harnesses	66.72	112.99	0
10527	OAK-NAV-2228	Navigation	140.75	227.99	0
10528	OAK-PAD-6274	Paddles & PFDs	17.77	37.99	0
10529	OAK-TRE-4702	Trekking Poles	237.40	468.99	0
10530	OAK-JAC-1326	Jackets	58.74	106.99	0
10531	OAK-NAV-9513	Navigation	238.32	457.99	0
10532	OAK-PAD-5215	Paddles & PFDs	89.37	164.99	0
10533	OAK-BAC-3319	Backpacks	104.44	209.99	0
10534	OAK-NAV-3056	Navigation	88.41	143.99	0
10535	SKU702421	Trail Runners	232.28	429.99	0
10536	OAK-BAS-6059	Base Layers	16.18	31.99	0
10537	OAK-TRE-6042	Trekking Poles	16.37	28.99	0
10538	OAK-BAC-9220	Backpacks	190.70	453.99	0
10539	OAK-TRE-6755	Trekking Poles	126.15	225.99	0
10540	SKU001186	Navigation	138.40	231.99	0
10541	OAK-CAR-5017	Carabiners & Hardware	208.85	397.99	0
10542	OAK-BAC-4334	Backpacks	231.90	483.99	0
10543	OAK-BAS-0299	Base Layers	111.39	205.99	0
10544	OAK-PAD-7277	Paddles & PFDs	43.30	71.99	0
10545	OAK-TEN-1796	Tents	163.23	272.99	0
10546	SKU762150	Tents	116.83	92.99	1
10547	OAK-BAS-6184	Base Layers	211.83	400.99	0
10548	SKU330403	Sleeping Bags	177.37	324.99	0
10549	OAK-PAD-0728	Paddles & PFDs	200.82	473.99	0
10550	OAK-BAC-0639	Backpacks	78.87	176.99	0
10551	OAK-BAC-1879	Backpacks	123.13	274.99	0
10552	OAK-HIK-4581	Hiking Boots	22.37	48.99	0
10553	OAK-CAR-2247	Carabiners & Hardware	118.65	238.99	0
10554	OAK-KAY-0123	Kayaks	209.72	363.99	0
10555	OAK-TRE-8794	Trekking Poles	172.57	388.99	0
10556	OAK-CAM-3305	Camp Kitchen	121.23	266.99	0
10557	OAK-ROP-1531	Ropes & Harnesses	187.66	401.99	0
10558	SKU027778	Jackets	125.80	100.99	1
10559	OAK-NAV-8008	Navigation	99.52	229.99	0
10560	OAK-SKI-0329	Skis & Snowboards	163.01	336.99	0
10561	OAK-JAC-6953	Jackets	154.69	247.99	0
10562	OAK-SLE-1657	Sleeping Bags	70.41	160.99	0
10563	OAK-ROP-7487	Ropes & Harnesses	189.00	337.99	0
10564	OAK-SKI-8573	Skis & Snowboards	199.68	362.99	0
10565	OAK-CAR-7339	Carabiners & Hardware	117.22	221.99	0
10566	SKU874186	Trekking Poles	96.35	164.99	0
10567	OAK-SKI-2994	Skis & Snowboards	25.29	51.99	0
10568	OAK-HIK-4995	Hiking Boots	109.11	216.99	0
10569	OAK-JAC-6293	Jackets	5.65	9.99	0
10570	OAK-ROP-9973	Ropes & Harnesses	86.11	201.99	0
10571	OAK-SKI-5908	Skis & Snowboards	42.26	69.99	0
10572	OAK-WAT-3673	Water Bottles	45.98	100.99	0
10573	OAK-ROP-9454	Ropes & Harnesses	153.79	275.99	0
10574	OAK-WAT-2515	Water Bottles	73.46	136.99	0
10575	OAK-PAD-2934	Paddles & PFDs	145.40	341.99	0
10576	OAK-KAY-0378	Kayaks	231.73	401.99	0
10577	OAK-TRE-5295	Trekking Poles	137.80	283.99	0
10578	OAK-HIK-3961	Hiking Boots	79.80	130.99	0
10579	OAK-SKI-1994	Skis & Snowboards	162.62	349.99	0
10580	OAK-CAM-8441	Camp Kitchen	150.35	251.99	0
10581	OAK-CAM-7468	Camp Kitchen	193.98	395.99	0
10582	OAK-BAS-6935	Base Layers	125.31	285.99	0
10583	SKU220194	Ropes & Harnesses	54.18	100.99	0
10584	OAK-TRA-4282	Trail Runners	14.91	25.99	0
10585	OAK-SKI-7349	Skis & Snowboards	74.75	158.99	0
10586	OAK-CAM-5789	Camp Kitchen	204.55	486.99	0
10587	OAK-PAD-5934	Paddles & PFDs	128.30	211.99	0
10588	OAK-SLE-2566	Sleeping Bags	94.41	151.99	0
10589	OAK-PAD-2140	Paddles & PFDs	156.75	336.99	0
10590	OAK-CAM-1627	Camp Kitchen	70.62	112.99	0
10591	OAK-TRA-3823	Trail Runners	134.34	258.99	0
10592	OAK-BAC-8217	Backpacks	212.86	462.99	0
10593	OAK-CAM-1643	Camp Kitchen	19.32	38.99	0
10594	OAK-TEN-3066	Tents	77.64	132.99	0
10595	OAK-KAY-7407	Kayaks	47.01	106.99	0
10596	OAK-BAS-5573	Base Layers	228.67	393.99	0
10597	OAK-NAV-1002	Navigation	120.29	287.99	0
10598	OAK-NAV-4591	Navigation	194.48	452.99	0
10599	OAK-TRE-6015	Trekking Poles	236.08	405.99	0
10600	OAK-TRE-4640	Trekking Poles	72.06	145.99	0
10601	OAK-KAY-2090	Kayaks	78.46	173.99	0
10602	OAK-WAT-2024	Water Bottles	7.93	14.99	0
10603	OAK-BAS-5650	Base Layers	163.44	314.99	0
10604	OAK-SKI-8528	Skis & Snowboards	36.56	75.99	0
10605	OAK-JAC-6818	Jackets	107.97	186.99	0
10606	OAK-NAV-9262	Navigation	106.33	231.99	0
10607	OAK-TRE-8788	Trekking Poles	233.28	464.99	0
10608	OAK-JAC-8625	Jackets	95.78	226.99	0
10609	OAK-TRA-6223	Trail Runners	217.64	406.99	0
10610	OAK-BAC-5248	Backpacks	199.48	477.99	0
10611	OAK-BAC-0590	Backpacks	213.20	468.99	0
10612	OAK-TRE-3415	Trekking Poles	212.41	350.99	0
10613	OAK-JAC-3742	Jackets	120.76	254.99	0
10614	OAK-BAS-7290	Base Layers	17.99	36.99	0
10615	SKU270422	Water Bottles	129.40	236.99	0
10616	OAK-JAC-7497	Jackets	181.51	403.99	0
10617	OAK-TRE-8012	Trekking Poles	150.16	294.99	0
10618	SKU675208	Navigation	105.37	250.99	0
10619	OAK-CAM-6913	Camp Kitchen	157.09	369.99	0
10620	OAK-ROP-9519	Ropes & Harnesses	161.06	290.99	0
10621	OAK-CAM-9341	Camp Kitchen	207.81	443.99	0
10622	OAK-SKI-3986	Skis & Snowboards	131.39	247.99	0
10623	OAK-BAS-2621	Base Layers	115.72	264.99	0
10624	SKU789247	Sleeping Bags	89.55	150.99	0
10625	OAK-TRE-3212	Trekking Poles	177.95	357.99	0
10626	OAK-TRE-7219	Trekking Poles	133.49	263.99	0
10627	OAK-TRA-5408	Trail Runners	87.18	157.99	0
10628	OAK-BAC-6265	Backpacks	42.59	69.99	0
10629	OAK-WAT-0263	Water Bottles	64.73	122.99	0
10630	OAK-TRE-7119	Trekking Poles	234.32	399.99	0
10631	OAK-SKI-3048	Skis & Snowboards	80.54	148.99	0
10632	OAK-TEN-5970	Tents	91.25	160.99	0
10633	OAK-KAY-8122	Kayaks	188.96	407.99	0
10634	OAK-WAT-7028	Water Bottles	32.63	67.99	0
10635	OAK-ROP-5491	Ropes & Harnesses	158.41	339.99	0
10636	OAK-CAM-7936	Camp Kitchen	170.18	287.99	0
10637	OAK-CAR-8618	Carabiners & Hardware	129.21	257.99	0
10638	OAK-JAC-0867	Jackets	194.38	448.99	0
10639	OAK-PAD-8637	Paddles & PFDs	101.01	196.99	0
10640	OAK-NAV-6190	Navigation	157.35	257.99	0
10641	OAK-ROP-4483	Ropes & Harnesses	75.22	149.99	0
10642	OAK-HIK-0986	Hiking Boots	37.40	76.99	0
10643	OAK-KAY-9357	Kayaks	206.94	359.99	0
10644	OAK-PAD-0535	Paddles & PFDs	107.80	179.99	0
10645	OAK-NAV-4597	Navigation	26.10	57.99	0
10646	OAK-BAC-6973	Backpacks	28.84	47.99	0
10647	OAK-BAC-5162	Backpacks	31.12	55.99	0
10648	OAK-TEN-9363	Tents	108.92	243.99	0
10649	OAK-CAM-4167	Camp Kitchen	5.62	9.99	0
10650	OAK-SLE-8470	Sleeping Bags	82.65	182.99	0
10651	OAK-PAD-3014	Paddles & PFDs	51.07	84.99	0
10652	OAK-BAS-2243	Base Layers	234.74	427.99	0
10653	SKU632553	Navigation	123.17	251.99	0
10654	OAK-ROP-2462	Ropes & Harnesses	217.85	489.99	0
10655	SKU412437	Sleeping Bags	49.43	92.99	0
10656	OAK-CAR-1345	Carabiners & Hardware	48.09	112.99	0
10657	OAK-CAR-3652	Carabiners & Hardware	74.20	130.99	0
10658	OAK-NAV-2903	Navigation	162.62	283.99	0
10659	OAK-NAV-2421	Navigation	133.58	224.99	0
10660	SKU220627	Camp Kitchen	24.78	49.99	0
10661	OAK-SLE-3751	Sleeping Bags	82.47	164.99	0
10662	OAK-SKI-8862	Skis & Snowboards	113.03	250.99	0
10663	OAK-NAV-7712	Navigation	55.76	90.99	0
10664	OAK-PAD-4695	Paddles & PFDs	201.78	346.99	0
10665	OAK-BAS-1245	Base Layers	185.33	368.99	0
10666	OAK-SLE-4123	Sleeping Bags	181.30	328.99	0
10667	OAK-NAV-2398	Navigation	65.41	118.99	0
10668	OAK-TRA-9050	Trail Runners	54.75	100.99	0
10669	OAK-SLE-9743	Sleeping Bags	99.89	184.99	0
10670	OAK-JAC-6204	Jackets	10.88	17.99	0
10671	OAK-KAY-8780	Kayaks	16.07	31.99	0
10672	OAK-SKI-7336	Skis & Snowboards	59.66	114.99	0
10673	OAK-CAR-3090	Carabiners & Hardware	29.68	59.99	0
10674	OAK-WAT-0566	Water Bottles	20.69	43.99	0
10675	OAK-BAC-0454	Backpacks	161.15	277.99	0
10676	OAK-ROP-0113	Ropes & Harnesses	33.22	59.99	0
10677	OAK-ROP-3660	Ropes & Harnesses	112.17	89.99	1
10678	OAK-CAM-9756	Camp Kitchen	197.75	380.99	0
10679	OAK-SKI-8312	Skis & Snowboards	63.94	128.99	0
10680	OAK-SKI-8819	Skis & Snowboards	186.75	433.99	0
10681	OAK-BAC-3798	Backpacks	238.25	382.99	0
10682	OAK-SLE-1542	Sleeping Bags	133.46	265.99	0
10683	OAK-BAC-9532	Backpacks	164.50	379.99	0
10684	OAK-SKI-7099	Skis & Snowboards	167.54	280.99	0
10685	OAK-CAM-6885	Camp Kitchen	96.49	201.99	0
10686	OAK-WAT-6369	Water Bottles	123.39	273.99	0
10687	OAK-BAS-7357	Base Layers	198.46	407.99	0
10688	SKU747094	Trail Runners	136.57	319.99	0
10689	OAK-HIK-4290	Hiking Boots	230.99	407.99	0
10690	OAK-JAC-2670	Jackets	26.10	45.99	0
10691	OAK-SLE-3723	Sleeping Bags	125.87	271.99	0
10692	OAK-BAC-2358	Backpacks	182.99	367.99	0
10693	OAK-ROP-0725	Ropes & Harnesses	152.47	246.99	0
10694	OAK-SKI-7365	Skis & Snowboards	35.13	64.99	0
10695	OAK-JAC-9279	Jackets	109.23	204.99	0
10696	OAK-CAR-5875	Carabiners & Hardware	123.96	266.99	0
10697	SKU743466	Ropes & Harnesses	212.28	437.99	0
10698	OAK-WAT-1800	Water Bottles	126.82	224.99	0
10699	OAK-BAS-3436	Base Layers	120.21	243.99	0
10700	SKU966149	Hiking Boots	22.92	37.99	0
10701	OAK-TRE-8442	Trekking Poles	93.13	221.99	0
10702	OAK-WAT-5402	Water Bottles	32.68	67.99	0
10703	OAK-NAV-9429	Navigation	105.41	171.99	0
10704	OAK-KAY-3890	Kayaks	73.90	158.99	0
10705	OAK-JAC-4295	Jackets	195.73	373.99	0
10706	OAK-KAY-1805	Kayaks	128.70	275.99	0
10707	OAK-TRA-9690	Trail Runners	211.57	471.99	0
10708	OAK-BAS-6707	Base Layers	209.50	458.99	0
10709	OAK-BAS-7473	Base Layers	221.67	513.99	0
10710	OAK-HIK-0389	Hiking Boots	200.19	467.99	0
10711	OAK-ROP-9959	Ropes & Harnesses	67.61	142.99	0
10712	OAK-TRA-0464	Trail Runners	55.04	92.99	0
10713	OAK-KAY-0662	Kayaks	23.84	44.99	0
10714	OAK-HIK-2661	Hiking Boots	130.29	298.99	0
10715	OAK-BAS-2234	Base Layers	194.06	358.99	0
10716	OAK-TRA-3075	Trail Runners	140.34	290.99	0
10717	OAK-PAD-8906	Paddles & PFDs	7.50	16.99	0
10718	OAK-KAY-9470	Kayaks	87.67	149.99	0
10719	OAK-CAM-0199	Camp Kitchen	24.03	52.99	0
10720	OAK-KAY-7203	Kayaks	127.15	285.99	0
10721	OAK-CAR-7448	Carabiners & Hardware	100.39	165.99	0
10722	OAK-ROP-5498	Ropes & Harnesses	70.71	141.99	0
10723	OAK-KAY-6828	Kayaks	239.57	413.99	0
10724	OAK-BAC-6112	Backpacks	198.04	466.99	0
10725	OAK-TEN-3308	Tents	164.49	349.99	0
10726	OAK-KAY-4310	Kayaks	76.87	182.99	0
10727	OAK-KAY-9390	Kayaks	60.67	139.99	0
10728	SKU488977	Backpacks	74.69	128.99	0
10729	OAK-ROP-8315	Ropes & Harnesses	104.45	236.99	0
10730	OAK-ROP-3828	Ropes & Harnesses	179.03	299.99	0
10731	OAK-BAC-6445	Backpacks	184.38	357.99	0
10732	OAK-WAT-0419	Water Bottles	200.70	375.99	0
10733	OAK-WAT-1213	Water Bottles	27.60	46.99	0
10734	OAK-NAV-5949	Navigation	108.08	190.99	0
10735	OAK-KAY-6034	Kayaks	39.97	93.99	0
10736	OAK-CAM-6326	Camp Kitchen	22.48	41.99	0
10737	OAK-CAR-0522	Carabiners & Hardware	128.51	213.99	0
10738	OAK-BAC-0791	Backpacks	39.39	31.99	1
10739	OAK-TRA-2145	Trail Runners	54.38	94.99	0
10740	OAK-CAR-3980	Carabiners & Hardware	158.05	316.99	0
10741	OAK-NAV-8166	Navigation	137.88	300.99	0
10742	OAK-BAC-9174	Backpacks	9.99	19.99	0
10743	OAK-KAY-8900	Kayaks	85.27	165.99	0
10744	OAK-NAV-6609	Navigation	107.91	213.99	0
10745	OAK-NAV-5110	Navigation	163.36	321.99	0
10746	OAK-TRA-7598	Trail Runners	134.37	256.99	0
10747	OAK-WAT-6971	Water Bottles	181.22	321.99	0
10748	OAK-PAD-1722	Paddles & PFDs	201.03	411.99	0
10749	OAK-KAY-1370	Kayaks	212.08	430.99	0
10750	OAK-SKI-5032	Skis & Snowboards	54.84	90.99	0
10751	OAK-HIK-0231	Hiking Boots	163.44	358.99	0
10752	SKU062397	Trekking Poles	57.81	117.99	0
10753	SKU789386	Hiking Boots	21.83	38.99	0
10754	OAK-SKI-4302	Skis & Snowboards	128.49	233.99	0
10755	OAK-TEN-9116	Tents	72.16	168.99	0
10756	OAK-NAV-3734	Navigation	156.61	292.99	0
10757	OAK-TRA-0189	Trail Runners	213.73	458.99	0
10758	OAK-TEN-6684	Tents	179.38	363.99	0
10759	OAK-JAC-8151	Jackets	73.34	122.99	0
10760	OAK-TRE-7468	Trekking Poles	20.55	40.99	0
10761	OAK-CAM-3370	Camp Kitchen	197.22	364.99	0
10762	OAK-KAY-1145	Kayaks	34.19	71.99	0
10763	OAK-WAT-1573	Water Bottles	238.16	424.99	0
10764	OAK-TEN-2083	Tents	178.05	342.99	0
10765	OAK-TRA-9216	Trail Runners	216.47	505.99	0
10766	OAK-SLE-5088	Sleeping Bags	20.41	41.99	0
10767	OAK-KAY-0775	Kayaks	16.98	36.99	0
10768	OAK-SLE-1210	Sleeping Bags	32.86	54.99	0
10769	OAK-SLE-3306	Sleeping Bags	194.94	365.99	0
10770	OAK-ROP-4657	Ropes & Harnesses	120.93	240.99	0
10771	OAK-CAM-0310	Camp Kitchen	212.22	464.99	0
10772	OAK-SLE-1795	Sleeping Bags	50.72	97.99	0
10773	SKU279383	Camp Kitchen	223.57	497.99	0
10774	OAK-BAC-8704	Backpacks	216.87	467.99	0
10775	OAK-HIK-3563	Hiking Boots	124.42	232.99	0
10776	OAK-WAT-0243	Water Bottles	47.06	74.99	0
10777	SKU709038	Backpacks	196.03	426.99	0
10778	OAK-TEN-3868	Tents	166.38	382.99	0
10779	SKU069869	Water Bottles	146.40	268.99	0
10780	OAK-CAM-3278	Camp Kitchen	39.77	88.99	0
10781	OAK-HIK-2639	Hiking Boots	93.31	206.99	0
10782	OAK-SKI-7159	Skis & Snowboards	182.49	359.99	0
10783	OAK-BAC-7196	Backpacks	122.56	256.99	0
10784	OAK-ROP-1235	Ropes & Harnesses	43.44	97.99	0
10785	OAK-TEN-7614	Tents	140.70	229.99	0
10786	OAK-TEN-7171	Tents	64.78	153.99	0
10787	OAK-TEN-3211	Tents	78.86	173.99	0
10788	OAK-BAS-3792	Base Layers	55.00	112.99	0
10789	SKU358543	Trail Runners	190.76	410.99	0
10790	OAK-NAV-5657	Navigation	219.89	382.99	0
10791	OAK-JAC-8669	Jackets	37.53	83.99	0
10792	OAK-WAT-8406	Water Bottles	188.88	325.99	0
10793	OAK-TRA-9981	Trail Runners	152.46	250.99	0
10794	SKU061750	Base Layers	26.09	44.99	0
10795	OAK-PAD-0908	Paddles & PFDs	224.71	411.99	0
10796	OAK-PAD-9436	Paddles & PFDs	122.89	283.99	0
10797	OAK-PAD-2354	Paddles & PFDs	150.60	322.99	0
10798	OAK-BAC-7039	Backpacks	44.52	99.99	0
10799	OAK-TRA-5543	Trail Runners	194.42	440.99	0
10800	OAK-ROP-9069	Ropes & Harnesses	160.89	271.99	0
10801	OAK-PAD-4416	Paddles & PFDs	18.38	41.99	0
10802	OAK-ROP-9586	Ropes & Harnesses	152.68	333.99	0
10803	SKU337433	Ropes & Harnesses	103.89	174.99	0
10804	OAK-PAD-0020	Paddles & PFDs	229.05	453.99	0
10805	OAK-PAD-0463	Paddles & PFDs	102.10	180.99	0
10806	OAK-WAT-0382	Water Bottles	80.84	189.99	0
10807	OAK-WAT-8247	Water Bottles	137.11	265.99	0
10808	OAK-PAD-2235	Paddles & PFDs	46.64	92.99	0
10809	OAK-KAY-3954	Kayaks	78.02	157.99	0
10810	OAK-SLE-4672	Sleeping Bags	195.74	426.99	0
10811	OAK-TEN-6506	Tents	165.53	288.99	0
10812	OAK-SLE-4550	Sleeping Bags	216.69	504.99	0
10813	OAK-WAT-6619	Water Bottles	132.85	246.99	0
10814	SKU656247	Carabiners & Hardware	97.18	155.99	0
10815	OAK-TEN-4887	Tents	81.97	155.99	0
10816	OAK-CAR-8087	Carabiners & Hardware	183.06	323.99	0
10817	OAK-NAV-2682	Navigation	26.15	46.99	0
10818	OAK-TRE-4561	Trekking Poles	227.32	376.99	0
10819	OAK-SLE-9926	Sleeping Bags	180.43	412.99	0
10820	OAK-CAM-0684	Camp Kitchen	133.91	314.99	0
10821	OAK-KAY-8130	Kayaks	184.26	337.99	0
10822	OAK-SKI-3197	Skis & Snowboards	32.82	72.99	0
10823	OAK-NAV-5404	Navigation	232.38	545.99	0
10824	OAK-JAC-0732	Jackets	54.81	112.99	0
10825	OAK-TRE-6488	Trekking Poles	17.91	31.99	0
10826	SKU717153	Hiking Boots	223.30	497.99	0
10827	OAK-JAC-5049	Jackets	177.64	322.99	0
10828	OAK-TEN-0616	Tents	157.60	289.99	0
10829	SKU275175	Camp Kitchen	138.03	243.99	0
10830	OAK-BAC-7917	Backpacks	25.84	53.99	0
10831	OAK-BAS-6307	Base Layers	191.62	416.99	0
10832	OAK-TRA-9557	Trail Runners	211.56	357.99	0
10833	OAK-JAC-9853	Jackets	13.03	21.99	0
10834	OAK-ROP-3814	Ropes & Harnesses	36.80	59.99	0
10835	OAK-SKI-1204	Skis & Snowboards	45.00	85.99	0
10836	OAK-HIK-0001	Hiking Boots	191.28	393.99	0
10837	SKU765966	Carabiners & Hardware	137.21	245.99	0
10838	OAK-TRE-0391	Trekking Poles	184.75	406.99	0
10839	OAK-SLE-3667	Sleeping Bags	12.86	28.99	0
10840	OAK-HIK-8016	Hiking Boots	151.84	334.99	0
10841	OAK-ROP-9456	Ropes & Harnesses	52.37	41.99	1
10842	OAK-BAC-1706	Backpacks	215.54	408.99	0
10843	OAK-TRA-5290	Trail Runners	213.67	483.99	0
10844	OAK-CAM-2520	Camp Kitchen	145.35	332.99	0
10845	OAK-SKI-4845	Skis & Snowboards	147.67	264.99	0
10846	OAK-TEN-9483	Tents	230.63	477.99	0
10847	OAK-TRE-1303	Trekking Poles	159.76	358.99	0
10848	OAK-HIK-6938	Hiking Boots	205.06	339.99	0
10849	OAK-CAM-2722	Camp Kitchen	177.63	409.99	0
10850	OAK-WAT-5111	Water Bottles	104.77	200.99	0
```

---

## Q10_r2_top_bottom_products.sql

RS1 — top 15 by gross revenue; RS2 — bottom 15:
```
product_id	sku	product_name	category_name	units_sold	gross_revenue	unit_return_rate_pct	revenue_return_rate_pct
10066	SKU566158	Meridian Touring Kayak 14ft Lite	Kayaks	486	240616.56	2.06	1.98
10023	OAK-PAD-7369	Glacier Aluminum Kayak Paddle	Paddles & PFDs	493	237063.87	2.23	2.20
10337	OAK-PAD-4336	Nimbus Carbon Kayak Paddle	Paddles & PFDs	455	235861.66	2.20	2.27
10142	OAK-TRA-6343	Sable Zero-Drop Trail Runners II	Trail Runners	459	235377.11	2.18	2.28
10001	OAK-BAC-8218	Ridgeline Summit Pack 18L	Backpacks	458	233039.27	1.75	1.75
10812	OAK-SLE-4550	Timberline 0F Winter Sleeping Bag	Sleeping Bags	472	233027.25	1.69	1.70
10765	OAK-TRA-9216	Rainier Zero-Drop Trail Runners	Trail Runners	460	223258.56	2.83	2.92
10020	OAK-WAT-1373	Cinder Bike Bottle 24oz	Water Bottles	431	220342.19	0.23	0.24
10470	OAK-SLE-7252	Kestrel Ultralight Quilt	Sleeping Bags	494	219197.21	1.01	1.03
10504	OAK-TEN-7821	Granite 3-Season Tent	Tents	468	219165.13	1.92	1.58
10542	OAK-BAC-4334	Summit Travel Pack 35L	Backpacks	469	217388.52	1.07	1.11
10384	OAK-TRA-7356	Rainier Zero-Drop Trail Runners	Trail Runners	444	216901.58	1.80	1.90
10538	OAK-BAC-9220	Basalt Daypack 22L	Backpacks	494	215901.62	3.04	2.95
10846	OAK-TEN-9483	Cascade 4-Season Expedition Tent	Tents	468	215152.23	2.99	2.99
10709	OAK-BAS-7473	Timberline Merino Base Layer Top	Base Layers	432	214945.03	3.24	3.10
product_id	sku	product_name	category_name	units_sold	gross_revenue	unit_return_rate_pct	revenue_return_rate_pct
10154	OAK-ROP-5274	Olympic Climbing Harness	Ropes & Harnesses	429	3297.38	3.03	3.08
10481	OAK-TEN-7604	Wildwood 3-Season Tent	Tents	402	3880.63	1.49	1.45
10107	OAK-BAC-2508	Juniper Kids Daypack 	Backpacks	338	3890.35	2.96	3.03
10649	OAK-CAM-4167	Cascade 2-Burner Camp Stove XT	Camp Kitchen	416	4054.62	0.72	0.67
10569	OAK-JAC-6293	Fjord Wind Shell	Jackets	473	4499.80	3.81	3.73
10076	OAK-NAV-4468	Meridian Altimeter Watch	Navigation	449	4810.81	2.00	2.06
10393	OAK-SLE-2448	Juniper 20F Down Sleeping Bag	Sleeping Bags	438	5533.31	2.74	2.79
10602	OAK-WAT-2024	Juniper Steel Growler 64oz	Water Bottles	446	6463.22	1.79	1.56
10717	OAK-PAD-8906	Sable Aluminum Kayak Paddle	Paddles & PFDs	401	6633.77	2.49	2.49
10670	OAK-JAC-6204	Skyline Softshell Jacket	Jackets	387	6727.94	0.78	0.80
10435	SKU602987	Glacier Powder Skis	Skis & Snowboards	409	6757.25	3.67	3.34
10232	OAK-CAR-6421	Olympic Quickdraw Set	Carabiners & Hardware	375	6813.69	1.60	1.66
10429	OAK-CAR-0285	Cascade Nut Tool	Carabiners & Hardware	423	7012.41	1.42	1.44
10394	SKU410318	Solstice Waterproof Trail Shoes	Trail Runners	392	7217.64	2.55	2.22
10352	OAK-JAC-0462	Juniper Rain Jacket	Jackets	482	7478.85	0.83	0.88
```

---

## Q11_r3_dq_kpis.sql
```
silver_customers	canonical_customers	dupe_candidates	resolved_phone	resolved_email_birth_date	unresolved
12000	11866	150	134	0	16
anomaly	n
below_cost_products	17
orders_before_signup	24217
penny_lines_revenue_scope	291
```

RS1 = silver V06 exactly (150 candidates → 134 phone + 0 email_birth_date + 16 unresolved;
11,866 canonical customers). RS2: below-cost 17 and orders-before-signup 24,217 match B06;
penny_lines_revenue_scope = 291 is the DEF-003 subset of the B04 D17 census (297 across ALL
orders — the other 6 penny lines sit on cancelled/pending orders, outside gold's revenue scope).

---

## Q12_r3_before_after_examples.sql
```
def_id	transform	pk	raw_value	clean_value
DEF-009	customers.marketing_opt_in	9	TRUE	1
DEF-010	customers.phone	1	206.555.9858	2065559858
DEF-011	shipments.delivered_date	1	01/12/2019	2019-01-12
DEF-012	customers.state	3	Ore.	OR
DEF-013	payments.method	20	Master Card	mastercard
DEF-015	customers.email	36	none	NULL
DEF-016	orders.order_total (reconciliation-grade cast)	100004	4,937.73	4937.73
DEF-017	products.weight_kg (sentinel)	10023	-999.00	NULL
```

One deterministic (MIN-PK) bronze→silver example per lossy transform DEF. DEF-014 has no row
here by design — it is an id-resolution rule, not a value transform (its census is Q11 RS1).

---

## Q13_r1_revenue_by_tier.sql
```
loyalty_tier	loyalty_tier_rank	order_count	gross_revenue	net_revenue
basic	1	34930	49846202.15	48706061.46
silver	2	12363	17580320.38	17156261.74
gold	3	7778	11138543.79	10864100.67
platinum	4	3229	4595111.66	4482100.98
```

R1 by-tier breakdown, ordered by DEF-020 rank (basic → platinum), never alphabet. Gross across
the four tiers sums to 83,160,177.98 (= B05 to the cent) and order counts sum to 58,300
(= DEF-003 census) — every revenue order lands in exactly one tier (V06's zero-NULL-leak law).
Orders attribute to the canonical customer's tier (DEF-014).

---

## Q14_r2_margin_kpis.sql
```
n_revenue_lines	median_unit_margin	min_unit_margin	max_unit_margin	below_cost_lines
151818	103.47	-239.05	340.80	3444
```

R2 margin KPI row: median unit margin 103.47 (DEF-021, median over the 151,818 DEF-003 revenue
lines; n is even, so the median is the ROUND-2dp arithmetic mean of the two middle values at
sorted positions 75,909 and 75,910 — the even-count rule documented in the file header).
Distribution bounds −239.05 … 340.80; 3,444 realized below-cost lines (= V07 RS2, RULE-008
feature).

---

## Q15_r2_margin_distribution.sql
```
band_start	band_label	line_count	line_share_pct	is_below_cost_band
-250	[-250, -225)	15	0.01	1
-225	[-225, -200)	39	0.03	1
-200	[-200, -175)	26	0.02	1
-175	[-175, -150)	25	0.02	1
-150	[-150, -125)	33	0.02	1
-125	[-125, -100)	42	0.03	1
-100	[-100, -75)	74	0.05	1
-75	[-75, -50)	142	0.09	1
-50	[-50, -25)	1150	0.76	1
-25	[-25, 0)	1898	1.25	1
0	[0, 25)	19602	12.91	0
25	[25, 50)	18636	12.28	0
50	[50, 75)	17494	11.52	0
75	[75, 100)	14617	9.63	0
100	[100, 125)	16041	10.57	0
125	[125, 150)	16704	11.00	0
150	[150, 175)	14541	9.58	0
175	[175, 200)	9773	6.44	0
200	[200, 225)	6594	4.34	0
225	[225, 250)	6439	4.24	0
250	[250, 275)	4444	2.93	0
275	[275, 300)	2541	1.67	0
300	[300, 325)	849	0.56	0
325	[325, 350)	99	0.07	0
```

24 populated $25-wide bands with constant edges anchored at $0 (band = [start, start+25)),
spanning −250 … 325 and covering the full Q14 range. The ten negative bands (is_below_cost_band
= 1) sum to 3,444 lines = V07's revenue-scope below-cost census; line_count sums to 151,818 and
line_share_pct to 100.00 (±rounding). The distribution's mass sits in [0, 200) with the
below-cost tail as the R2 call-out series (RULE-008).
