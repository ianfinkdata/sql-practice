# 9. The Medallion Pipeline, Start to Finish

<!-- nav -->
Previous: [8. Star vs. Snowflake Schema](08-star-vs-snowflake-schema.md). Next: [10. Capstone: Design a Novel Gold View](10-capstone-build-a-novel-gold-view.md). Exercises: [9. The Medallion Pipeline, Start to Finish](../../exercises/05-master/09-medallion-pipeline-recap.md).
<!-- /nav -->

## The idea

Every lesson in this repo has been building one pipeline, one layer at
a time: **bronze** (raw, as-ingested, unclean, unconstrained) → **silver**
(cleaned, standardized, conformed to consistent types and values) →
**gold** (business-ready, star-schema-shaped, what BI tools and
analysts actually query). This is the **medallion architecture**, and
it's not an Oakhaven invention or a SQLite trick — it's the standard
pattern for building lakehouses on Databricks, Snowflake, BigQuery, and
just about every modern data platform. The names differ occasionally
(some shops say "raw / clean / curated," Databricks popularized
"bronze / silver / gold" specifically), but the three-layer shape and
the reasoning behind it are the same everywhere.

This module doesn't teach a new technique. It walks the *entire*
pipeline end to end, using two concrete threads — sales and customers —
so the whole shape clicks into place at once, right before the
capstone asks you to extend it yourself.

## Why three layers, not one

You could, in principle, write one enormous query that goes straight
from `bronze_sales` to a finished revenue-by-category report. Nobody
who has actually tried this at scale does it that way, for the same
reasons this repo doesn't:

- **Bronze exists to be an honest, auditable copy of what arrived.**
  No cleaning, no filtering, no constraints (`project/bronze/schema.sql`
  declares plain column types with no `PRIMARY KEY`/`FOREIGN
  KEY`/`CHECK`). If a downstream number ever looks wrong, you can
  always go back to bronze and see exactly what the source system
  handed you, untouched. Skip this layer and you lose your ability to
  audit — "clean" data with no raw copy behind it can't be checked
  against reality.
- **Silver exists to make one decision about each kind of messiness,
  once, in one place.** `silver_sales` parses three different date
  formats, fixes the `discount_pct` whole-number bug, and recomputes a
  trustworthy `net_amount` — all one time, in one view. Skip this layer
  and every downstream query has to re-solve "which of these three date
  formats is this row in" for itself, inconsistently, forever.
- **Gold exists to be shaped for the question, not the source system.**
  `fact_sales` and the `dim_*` views aren't "silver, but renamed" — they
  add a grain declaration, foreign keys resolved (or explicitly flagged
  as unresolved), and measures ready to aggregate. Skip this layer and
  every analyst reinvents "how do I get net sales by category" from
  scratch, joining raw-ish tables by hand each time.

Each layer earns its keep by doing one job well, so the layer after it
doesn't have to redo that job.

## Thread 1: sales, bronze → silver → gold

Follow order 99, line 1, through all three layers.

**Bronze** — raw, as generated, `order_total` deliberately untrustworthy:

```sql
SELECT order_id, order_line_id, quantity, unit_price, discount_pct, order_total
FROM bronze_sales
WHERE order_id = 99 AND order_line_id = 1;
```

| order_id | order_line_id | quantity | unit_price | discount_pct | order_total |
|---|---|---|---|---|---|
| 99 | 1 | 1 | 536.26 | 0.0 | TBD |

`order_total` is the literal string `"TBD"` — one of the deliberate
placeholder values the data dictionary documents (~0.3% of rows).
Bronze doesn't fix this. It's not bronze's job to fix anything.

**Silver** — cleaned, and critically, `net_amount` is *recomputed* from
`quantity * unit_price * (1 - discount_pct)` rather than trusting the
untrustworthy `order_total`:

```sql
SELECT order_id, order_line_id, quantity, unit_price, discount_pct, net_amount, order_total_raw
FROM silver_sales
WHERE order_id = 99 AND order_line_id = 1;
```

| order_id | order_line_id | quantity | unit_price | discount_pct | net_amount | order_total_raw |
|---|---|---|---|---|---|---|
| 99 | 1 | 1 | 536.26 | 0.0 | 536.26 | TBD |

`order_total_raw` is carried along (renamed, not deleted — you can
still see bronze said "TBD" if you need to), but `net_amount` is now a
number you can trust and sum, computed once, correctly, in this one
view. Every downstream query gets this for free instead of re-deriving
it.

**Gold** — `fact_sales` takes `net_amount` as-is from silver, adds the
FK scaffolding (grain, `datekey`, orphan flags — covered in module 7),
and does nothing further to this measure:

```sql
SELECT order_id, order_line_id, net_amount
FROM fact_sales
WHERE order_id = 99 AND order_line_id = 1;
```

| order_id | order_line_id | net_amount |
|---|---|---|
| 99 | 1 | 536.26 |

Same number, three layers later — because by the time gold sees it,
the hard work (recomputing a trustworthy value from a deliberately
unreliable source column) is already done. Gold's job here isn't
cleaning, it's *shaping*.

## Thread 2: customers, bronze → silver → gold

Same idea, different messiness. Customer 6's `state` and `is_active`:

**Bronze:**

```sql
SELECT customer_id, first_name, last_name, state, is_active
FROM bronze_customers
WHERE customer_id = 6;
```

| customer_id | first_name | last_name | state | is_active |
|---|---|---|---|---|
| 6 | ANTHONY | Reed | Calif. | Y |

`ANTHONY` is all-caps, `state` is the dotted abbreviation `Calif.`, and
`is_active` is the letter `Y` — one of eleven different spellings of
"true" the bronze layer might produce for this column.

**Silver:**

```sql
SELECT customer_id, first_name, last_name, state, is_active
FROM silver_customers
WHERE customer_id = 6;
```

| customer_id | first_name | last_name | state | is_active |
|---|---|---|---|---|
| 6 | Anthony | Reed | CA | 1 |

Name title-cased, `state` mapped to its canonical 2-letter code via the
`state_map` lookup, `is_active` coalesced from the 11-value mixed-boolean
text pool down to a real `0`/`1` integer.

**Gold:**

```sql
SELECT customer_id, first_name, last_name, state, is_active
FROM dim_customer
WHERE customer_id = 6;
```

| customer_id | first_name | last_name | state | is_active |
|---|---|---|---|---|
| 6 | Anthony | Reed | CA | 1 |

Identical to silver. `dim_customer` is a thin pass-through
(`SELECT ... FROM silver_customers`, no additional transformation) —
because by the time you're two layers into a well-designed pipeline,
"clean" and "business-ready" are often the same thing for a dimension
this simple. Gold's contribution here is conceptual, not
computational: this view is what a `JOIN`s against `fact_sales`, not
`silver_customers` — the naming and role (a *dimension*, not a
*cleaned table*) is gold's whole value-add for this particular object.

## Layers clean and reshape; mostly, they don't filter

```sql
SELECT 'sales' AS thread,
       (SELECT COUNT(*) FROM bronze_sales) AS bronze,
       (SELECT COUNT(*) FROM silver_sales) AS silver,
       (SELECT COUNT(*) FROM fact_sales) AS gold
UNION ALL
SELECT 'customers',
       (SELECT COUNT(*) FROM bronze_customers),
       (SELECT COUNT(*) FROM silver_customers),
       (SELECT COUNT(*) FROM dim_customer);
```

| thread | bronze | silver | gold |
|---|---|---|---|
| sales | 12000 | 12000 | 12000 |
| customers | 600 | 600 | 600 |

Same row count, all three layers, both threads. That's not a
coincidence — it's the same discipline module 7 covered for
`fact_sales`'s orphans and NULLs: bad rows are *flagged*, not
*dropped*, all the way from bronze through gold. (`agg_*` views are the
exception, and deliberately so — `agg_monthly_sales_by_category` inner
joins and does lose rows, but that's a downstream aggregate making an
explicit choice, not silver or the fact table hiding data by default.)
A pipeline that quietly shrinks row counts between layers, with no
explicit filter or documented reason, is usually a pipeline losing
data nobody meant to lose — always compare row counts across layers as
a sanity check.

## Examples

### 1. The full thread, one query, sales

```sql
SELECT b.order_total AS bronze_order_total, s.net_amount AS silver_net_amount, f.net_amount AS gold_net_amount
FROM bronze_sales b
JOIN silver_sales s ON s.order_id = b.order_id AND s.order_line_id = b.order_line_id
JOIN fact_sales f ON f.order_id = b.order_id AND f.order_line_id = b.order_line_id
WHERE b.order_id = 99 AND b.order_line_id = 1;
```

| bronze_order_total | silver_net_amount | gold_net_amount |
|---|---|---|
| TBD | 536.26 | 536.26 |

All three layers, one query, one row — the whole pipeline compressed
into a single self-join across the layer boundary, which is a handy way
to spot-check any specific row's journey when debugging.

### 2. This pattern is engine-agnostic

The exact same three-layer reasoning shows up whether the underlying
tables are SQLite views (as here), Delta tables in a Databricks
lakehouse, materialized views in Snowflake, or scheduled `dbt` models
building tables in BigQuery. What changes across engines is the
*mechanics* — how you schedule the bronze ingestion, whether silver is
a view or a materialized table, how gold gets refreshed — not the
*shape*. Module 11 covers those mechanical differences directly; this
module is about the shape that survives the move to any of them.

## Common mistakes

- **Skipping straight to gold.** Writing gold views directly against
  bronze (instead of against silver) means re-solving every messiness
  problem — mixed date formats, the discount bug, mixed booleans — in
  every gold object that needs it, inconsistently. Oakhaven's gold
  layer is built entirely on `silver_*`, never on `bronze_*` directly,
  for exactly this reason.
  ```sql
  SELECT sql FROM sqlite_master WHERE name = 'fact_sales';
  ```
  confirms this: `fact_sales` selects `FROM silver_sales`, not `FROM
  bronze_sales`.
- **Treating bronze as disposable.** Bronze is the audit trail. If
  silver's cleaning logic ever has a bug, bronze is how you prove what
  the source system actually sent, and re-derive silver correctly.
  Deleting or overwriting bronze after silver is built removes your
  ability to ever check that.
- **Expecting row counts to shrink layer over layer as a matter of
  course.** A shrinking count between bronze and silver (or silver and
  gold, for a dimension or a passthrough fact) usually means a bug
  (an accidental `INNER JOIN`, an over-aggressive `WHERE`), not
  "cleaning working as intended." Cleaning changes values; it's the
  *aggregate* layer's job to intentionally drop rows, and it should do
  so visibly (via `JOIN` choice) and for a stated reason.
- **Assuming this is a small-data/SQLite-only pattern.** The medallion
  shape is exactly how production lakehouses handling terabytes are
  built. The scale changes; the three-layer reasoning doesn't.

## Key takeaways

- Bronze = raw and auditable, silver = cleaned and conformed, gold =
  business-ready and star-schema-shaped. Each layer solves one problem
  once so later layers and every downstream query don't have to.
- Following one row (or one customer) through all three layers — as
  this module did for order 99's `net_amount` and customer 6's `state`
  — is a good habit for understanding *or debugging* any medallion
  pipeline, not just this one.
- Row counts should stay stable across bronze → silver → gold (both
  threads here: 12000 → 12000 → 12000 and 600 → 600 → 600); shrinkage
  belongs to explicit, visible choices in aggregate views, not to
  silver or the fact/dimension layer.
- This is the exact pattern used to build medallion lakehouses on
  Databricks, Snowflake, and BigQuery — the mechanics of *how* each
  layer gets built differ by engine (module 11), but the shape and the
  reasoning for having three layers instead of one is portable
  everywhere.

---

<!-- nav -->
Previous: [8. Star vs. Snowflake Schema](08-star-vs-snowflake-schema.md). Next: [10. Capstone: Design a Novel Gold View](10-capstone-build-a-novel-gold-view.md). Exercises: [9. The Medallion Pipeline, Start to Finish](../../exercises/05-master/09-medallion-pipeline-recap.md).
<!-- /nav -->
