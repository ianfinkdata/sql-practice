# Export Guide — Bronze Full-Row Export Pack (TASK-20260706-01)

Purpose: export every row of all 14 `oakhaven` bronze tables to tab-separated flat files, so
they can be loaded into Power BI for local, low-code exploration alongside a local Claude
session. This is a full-fidelity export of the bronze layer as-is — no cleaning, no filtering,
no business logic applied (bronze is read-as-is; see `grounding/medallion-spec.md` §Bronze
rules). Grounding: `grounding/schema.md` (IDX-004), `grounding/medallion-spec.md` §Reproducibility,
`grounding/lessons.md` RULE-001/002/010.

## 1. How to run

From this `exports/` directory, in PowerShell on the machine with the local MySQL80 service
and the established `.my.cnf`:

```powershell
.\run_all_exports.ps1
```

This runs each of the 14 `E01_*.sql` … `E14_*.sql` files through the standard Windows mysql
invocation (`process/mysql-setup.md`):

```powershell
Get-Content <file>.sql -Raw |
  & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
```

and writes each result set to `exports\csv\<table>.tsv` (tab-separated, header row included —
mysql's native `--batch` rendering, not a hand-rolled CSV writer, so embedded tabs/newlines are
handled by the client's own escaping). The `csv/` subdirectory is created automatically if it
doesn't already exist.

Each individual `.sql` file can also be run standalone the same way, one table at a time, if
you only need to refresh a single export.

No file uses `LIMIT`. This is the one deliverable in this project where a full, unbounded
export is the explicit point — every row of every table, every time. Do not add a `LIMIT` to
any of these files.

## 2. Expected row counts (verify after running)

After the script finishes, compare the line count of each `.tsv` file (minus 1 for the header
row) against the counts below. These are transcribed verbatim from `grounding/schema.md`'s
"Exact row counts" section (COUNT(*), verified 2026-07-04) — the same numbers the rest of the
bronze query pack (`medallion/a_bronze/B01_row_counts.sql`) reconciles against.

| Export file | Table | Expected rows |
|---|---|---|
| E01_stores.sql | stores | 13 |
| E02_employees.sql | employees | 240 |
| E03_suppliers.sql | suppliers | 45 |
| E04_product_categories.sql | product_categories | 24 |
| E05_products.sql | products | 850 |
| E06_customers.sql | customers | 12,000 |
| E07_promotions.sql | promotions | 70 |
| E08_calendar.sql | calendar | 4,748 |
| E09_orders.sql | orders | 60,000 |
| E10_order_items.sql | order_items | 156,190 |
| E11_payments.sql | payments | 66,663 |
| E12_shipments.sql | shipments | 29,784 |
| E13_returns.sql | returns | 5,010 |
| E14_inventory_movements.sql | inventory_movements | 90,000 |

A quick PowerShell way to check one file's row count (subtract 1 for the header):

```powershell
(Get-Content .\csv\customers.tsv | Measure-Object -Line).Lines - 1
```

If any count doesn't match, do not "fix" the data — stop and compare against
`medallion/a_bronze/B01_row_counts.sql`'s captured output, then escalate per CLAUDE.md's
escalation triggers (a re-run producing different output is a determinism leak).

## 3. IMPORTANT: how mysql `--batch` renders NULL

mysql's `--batch` mode renders SQL `NULL` as the **literal 4-character string `NULL`** — not
an empty cell. Every nullable column exported here (e.g. `stores.square_feet`,
`customers.birth_date`, `products.weight_kg`, `shipments.delivered_date_raw`, `orders.promo_id`,
`employees.manager_id`/`termination_date`, and others — see `grounding/schema.md`'s DDL for the
full nullable-column list per table) can contain this literal text.

**Power BI's Text/CSV connector will import this as the literal text string `"NULL"`, not as a
blank/null value, unless you tell it otherwise.** Left unhandled, this silently corrupts any
numeric/date column that has nulls (the column gets typed as text, or averages/sums quietly
exclude those rows in unexpected ways). Flag this in your report/model build — it's an easy
footgun.

**Fix (Power Query, at import time):**
- Simplest: after loading, select the affected column(s) → **Transform** → **Replace Values** →
  replace `NULL` with nothing, then let Power Query re-detect the type — or explicitly set the
  replaced value to `null` via the formula bar (`= Table.ReplaceValue(#"Previous Step", "NULL",
  null, Replacer.ReplaceValue, {"column_name"})`).
- To handle it once for all columns/files: add a **Replace Values** step scoped to "NULL" → the
  M `null` value across every text column before type-detection, e.g.
  `= Table.TransformColumns(#"Promoted Headers", List.Transform(Table.ColumnNames(#"Promoted
  Headers"), each {_, each if _ = "NULL" then null else _}))`.
- Do this **before** Power BI infers column data types, otherwise a numeric/date column with
  `NULL` strings mixed in will get typed as Text and silently fail to aggregate correctly.

## 4. Power BI import — step by step

**Recommended: import one file at a time (Option B below).** These 14 files have 14
different schemas (different column sets), and Power BI's **Get Data → Folder →
"Combine & Transform Data"** button is built to *stack same-schema files into one table*
(e.g. 12 monthly CSVs of the same report) — it is **not** a way to load 14 different tables
in one step. Used here, it would try to combine `orders.tsv` and `customers.tsv` (etc.) as if
they were the same table and either error or silently produce a garbage combined result.
Don't use "Combine & Transform Data" for this export pack.

**Option A: browse the folder, then import files individually from Power Query**

1. Power BI Desktop → **Get Data** → **Folder**.
2. Browse to `exports/csv/` (the folder `run_all_exports.ps1` populates) → **OK**.
3. In the folder preview, click **Transform Data** (NOT "Combine & Transform Data") — this
   opens Power Query showing one row per file (file paths + binary content), not yet the
   actual table data.
4. For each file you want as its own table: right-click its row → **Add as New Query**, then
   in that new query expand the binary content as a delimited file (Tab-delimited). Repeat
   per file. This gets you to the same place as Option B, just reached via the folder browser
   — it does not save real effort over Option B for 14 differently-shaped files, which is why
   Option B is the recommended path below.

**Option B (recommended): import one file at a time**

1. Power BI Desktop → **Get Data** → **Text/CSV**.
2. Select one file, e.g. `exports/csv/orders.tsv`.
3. In the preview dialog, set **Delimiter** = **Tab** (not comma — these are `.tsv` files from
   mysql's native `--batch` output).
4. Confirm **First Row as Headers** is checked.
5. Click **Transform Data** (not Load) so you land in Power Query.
6. **Apply the NULL-string fix from §3 above** on any nullable column in this table, before
   type detection.
7. Set/confirm column data types (date, decimal, int, text) once nulls are handled correctly.
8. **Close & Apply**. Repeat for each of the 14 files.

Option B is the reliable path for this pack (14 tables, 14 different schemas) and gives full
per-table control over data types — use it as the default. Option A is documented above only
because the folder browser is a common first instinct; it doesn't save meaningful effort here.

## 5. Notes

- These are raw bronze rows — dirty by design (see `grounding/schema.md`'s "Dirty columns at a
  glance" and `oakhaven/DATA_CONTRACT.md` §4 for the full dirt catalog: sentinel values like
  `-999`, flag chaos, format chaos, planted anomalies). Do not clean these in Power Query beyond
  the NULL-string fix above — that's what the silver/gold layers exist for
  (`oakhaven_silver`/`oakhaven_gold`, see `medallion/b_silver/` and `medallion/c_gold/`). This
  export is intentionally a bronze mirror, nothing more.
- `orders.order_total_text` and `shipments.delivered_date_raw` are exported as raw text columns
  — do not derive money or dates from them directly in Power BI; they are reconciliation
  material, not truth (RULE-003, `grounding/definitions.md` DEF-002/DEF-016).
