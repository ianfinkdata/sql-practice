# EXPECTED_OUTPUTS.md — TASK-20260705-01 gold amendment (DEF-020 loyalty tier + DEF-021 unit margin)

This file is the COMPLETE updated capture set for the gold layer and supersedes the
TASK-20260704-04 version (medallion/c_gold/EXPECTED_OUTPUTS.md).

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

Long results (Q07 ≈ 450 rows, Q09 = 850 rows) are captured as AGGREGATE SIGNATURES, stated
as such per medallion-spec §Reproducibility rule 4; the exact signature SQL is included so
the validator can re-run it verbatim.

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

~450 rows (90 months × top-5 categories) — captured as an aggregate signature per
medallion-spec §Reproducibility rule 4. Signature query (run verbatim):
```sql
-- Aggregate signature for Q07_r2_monthly_units_top5_categories.sql (medallion-spec §Reproducibility rule 4)
WITH category_totals AS (
  SELECT m.category_id,
         SUM(m.units_sold) AS total_units
  FROM oakhaven_gold.mart_category_sales m
  GROUP BY m.category_id
),
top5 AS (
  SELECT category_id
  FROM category_totals
  ORDER BY total_units DESC, category_id
  LIMIT 5
)
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT m.sales_month) AS n_months,
  COUNT(DISTINCT m.category_id) AS n_categories,
  GROUP_CONCAT(DISTINCT m.category_id ORDER BY m.category_id) AS category_ids,
  SUM(m.units_sold) AS total_units,
  SUM(m.gross_revenue) AS total_gross
FROM oakhaven_gold.mart_category_sales m
JOIN top5 t ON t.category_id = m.category_id;
```

Signature output (actual --batch run):

```
n_rows	n_months	n_categories	category_ids	total_units	total_gross
450	90	5	10,11,12,17,19	124694	28938760.99
```

450 rows exactly; top-5 categories by total units are category_ids 10, 11, 12, 17, 19
(Sleeping Bags, Camp Kitchen, Backpacks, Kayaks, Jackets), 124,694 units, 28,938,760.99 gross.

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

850 rows (one per product) — captured as an aggregate signature per medallion-spec
§Reproducibility rule 4. Signature query (run verbatim):
```sql
-- Aggregate signature for Q09_r2_price_vs_cost.sql (medallion-spec §Reproducibility rule 4)
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT p.product_id) AS n_products,
  SUM(p.unit_cost) AS sum_unit_cost,
  SUM(p.list_price) AS sum_list_price,
  SUM(p.is_below_cost) AS below_cost_products
FROM oakhaven_gold.dim_product p;
```

Signature output (actual --batch run):

```
n_rows	n_products	sum_unit_cost	sum_list_price	below_cost_products
850	850	103962.91	203872.50	17
```

850 scatter points; below_cost_products = 17 = the B06 D16 census exactly.

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
