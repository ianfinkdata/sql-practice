# EXPECTED_OUTPUTS.md — TASK-20260704-03 silver layer

Captured 2026-07-04 via actual `--batch` runs against the live server (RULE-006 — pasted
verbatim, never hand-typed). Connection: `Get-Content <file>.sql -Raw | & "C:\Program
Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf"
--batch oakhaven`.

Preconditions: `S00_create_schema.sql` then `S01…S14` (ddl/) executed in filename order.
S01 creates TWO views: the DEF-014 helper `oakhaven_silver.customer_dupe_map` (150 rows,
one per candidate) and `oakhaven_silver.customers`. All 15 CREATE statements completed
without error against MySQL 8.0.39.

The full verify pack (V01–V07, concatenated in filename order) was run TWICE in this
session and diffed byte-for-byte identical (`Compare-Object` produced no output) —
reproducibility confirmed per medallion-spec §Reproducibility rule 5.

---

## V01_row_parity.sql

Grain preservation (RULE-005): every silver view = its bronze table = the B01 capture.

```
table_name	bronze_rows	silver_rows	is_match
calendar	4748	4748	1
customers	12000	12000	1
employees	240	240	1
inventory_movements	90000	90000	1
order_items	156190	156190	1
orders	60000	60000	1
payments	66663	66663	1
product_categories	24	24	1
products	850	850	1
promotions	70	70	1
returns	5010	5010	1
shipments	29784	29784	1
stores	13	13	1
suppliers	45	45	1
```

All 14 rows `is_match = 1`; counts equal `medallion/a_bronze/EXPECTED_OUTPUTS.md` B01 exactly.

---

## V02_def009_boolean_leaks.sql

DEF-009 zero-leak proof (bronze columns are NOT NULL, so any silver NULL = unmapped value):

```
bool_column	total_rows	mapped_1	mapped_0	null_leaks
customers.marketing_opt_in	12000	6728	5272	0
products.discontinued_flag	850	260	590	0
suppliers.active_flag	45	31	14	0
```

Reconciles to the B03 census arithmetic: marketing_opt_in 1s = 3715+1567+1446 = 6728,
0s = 2926+1177+1169 = 5272; discontinued_flag 1s = 70+130+60 = 260, 0s = 85+460+45 = 590;
active_flag 1s = 8+18+5 = 31, 0s = 4+7+3 = 14. Zero NULL leaks on all three.

---

## V03_def012_state.sql

Result set 1 — post-clean census (binary collation):

```
state_clean	n
CA	2027
ID	1162
MT	989
OR	2939
WA	4883
```

Result set 2 — explicit leak count:

```
state_null_leaks
0
```

Post-clean distinct set is exactly {CA, ID, MT, OR, WA} per the DEF-012 v1.1 assertion;
counts are the B03 raw-value rollups (CA 1723+102+202 · ID 1007+56+99 · MT 849+44+96 ·
OR 2504+146+289 · WA 4117+252+514) and sum to 12,000. Zero NULLs — every bronze value maps.

---

## V04_def013_method.sql

Result set 1 — post-clean census (binary collation):

```
method_clean	n
amex	6143
cash	11203
gift	3087
mastercard	19068
visa	27162
```

Result set 2 — explicit leak count:

```
method_null_leaks
0
```

Exactly the DEF-013 v1.1 mapped totals (visa 27,162 · mastercard 19,068 · cash 11,203 ·
amex 6,143 · gift 3,087), summing to 66,663 = the full payments row count. Zero NULLs.

---

## V05_def017_sentinels.sql

Flag counts (rows 1–5) vs the B04 census, plus NULLing-integrity checks (rows 6–9):

```
check_name	n
1 products.is_weight_sentinel	9
2 suppliers.is_lead_time_sentinel	2
3 customers.is_birth_date_sentinel	60
4 customers.is_birth_date_future	24
5 customers.is_age_outlier	36
6 weight flagged but not NULLed	0
7 lead_time flagged but not NULLed	0
8 birth_date flagged but not NULLed	0
9 age outlier wrongly NULLed	0
```

Matches B04 exactly: D13 -999 sentinel 9 · D21 -999 sentinel 2 · D5 1900-01-01 sentinel 60 ·
D5 future date 24 · D5 age > 95 outlier 36 (kept-not-NULLed per the DEF-017 caveat, row 9 = 0).
Every flagged sentinel value was NULLed in its cleaned column (rows 6–8 = 0).

---

## V06_def014_dupes.sql

Result set 1 — resolution census over the 150 candidates (customer_id 11851–12000):

```
resolution	n
phone	134
unresolved	16
```

Result set 2 — candidate accounting:

```
candidates_total	resolved	unresolved	resolved_beyond_originals	distinct_originals	unresolved_not_self
150	134	16	0	134	0
```

Result set 3 — non-candidates (ids ≤ 11850):

```
noncandidate_canonical_mismatches	noncandidate_resolution_labels
0	0
```

DEF-014 accounts for exactly 150 candidates: 134 resolved + 16 unresolved = 150.
All 134 resolved originals are ≤ 11850 (`resolved_beyond_originals` 0) and distinct
(`distinct_originals` 134 = resolved 134 — the mapping is 1:1, no two candidates share an
original). All 11,850 non-candidates are self-canonical with NULL `dupe_resolution`.

NOTE on the email fallback (DEF-014 rule 3): on live data it resolves ZERO candidates —
hence no `email_birth_date` row in result set 1. Probed in-session: of the 16 candidates not
resolved by phone, 6 have a phone10 shared by exactly TWO originals (correctly excluded by
rule 2's "unique among originals"), 10 have no original phone match at all (1 NULL phone),
and none has ANY original with an exactly-equal normalized-email local part (the generator
mutated the copies' email local parts), so the `+ same birth_date` condition is never even
reached. Per rule 4 these 16 are flagged `unresolved`, never guessed. The `email_birth_date`
branch remains live in the view for reproducibility of the rule as specified.

---

## V07_def011_delivered_date.sql

```
total_rows	raw_null	raw_pending	parsed_null	pending_flag_sum	parse_failures
29784	1840	1165	3005	1165	0
```

DEF-011 verification target holds exactly: parsed NULLs 3,005 = raw NULL 1,840 + 'PENDING'
1,165 (the B04 D10 counts); `is_delivery_pending` sums to 1,165; zero parse failures — all
26,779 non-NULL/non-PENDING raw values produced a DATE.
