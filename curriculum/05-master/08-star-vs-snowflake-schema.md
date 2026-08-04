# 8. Star vs. Snowflake Schema

## The idea

Once you have a fact table with foreign keys to several dimensions,
you face a design choice for *those dimensions themselves*: keep each
one flat and denormalized (a **star schema** — fact in the middle,
dimensions radiating out one join away, like points on a star), or
break shared attributes out into their own sub-tables and link them
with further foreign keys (a **snowflake schema** — dimensions that
themselves branch into smaller dimensions, several joins deep).

Oakhaven's gold layer is a star. `dim_product` stores `category`,
`subcategory`, and `brand` as plain text columns sitting directly on
the product row — not as foreign keys into separate `dim_category`,
`dim_subcategory`, and `dim_brand` tables. This module explains why
that's the right call here, what a snowflaked version would look like,
and the (narrower) cases where snowflaking earns its keep.

## Star: one hop, denormalized, and repetitive on purpose

```sql
SELECT product_id, product_name, category, subcategory, brand, unit_price
FROM dim_product
LIMIT 5;
```

Every one of the 150 rows in `dim_product` carries its own copy of
`category`, `subcategory`, and `brand` as literal text — "Climbing"
appears on every climbing product's row, over and over. In a normalized
OLTP schema that repetition would be a design flaw (Tier 5 module 1
covered exactly why: update anomalies, wasted storage). In a star
schema it's the point: any query that wants product attributes gets
them with **one join**, full stop.

```sql
SELECT p.category, COUNT(*) AS lines, ROUND(SUM(f.net_amount), 2) AS net_amount
FROM fact_sales f
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY p.category
ORDER BY net_amount DESC;
```

| category | lines | net_amount |
|---|---|---|
| Climbing | 1858 | 1389650.95 |
| Winter Sports | 1834 | 1249691.54 |
| Apparel | 1556 | 1237729.99 |
| Nutrition & Hydration | 1548 | 1164289.69 |
| Footwear | 1402 | 1077941.52 |
| Accessories | 1543 | 938846.45 |
| Camping & Hiking | 1277 | 911945.48 |
| Water Sports | 860 | 722662.14 |

Category rollup, `fact_sales JOIN dim_product`, one hop. Want it by
brand instead?

```sql
SELECT p.brand, COUNT(*) AS lines, ROUND(SUM(f.net_amount), 2) AS net_amount
FROM fact_sales f
JOIN dim_product p ON p.product_id = f.product_id
GROUP BY p.brand
ORDER BY net_amount DESC
LIMIT 5;
```

| brand | lines | net_amount |
|---|---|---|
| Foghorn Supply | 644 | 633719.91 |
| Tundraworks | 568 | 514288.21 |
| Ridgeway Co. | 582 | 510918.96 |
| Northfell | 697 | 487175.42 |
| Marrowpeak | 674 | 434031.88 |

Same shape, same single join — just group by a different flat column
on the same dimension row. That's the whole appeal of a star schema:
every one of `dim_product`'s attributes (category, subcategory, brand,
`sku_is_duplicate`, `is_discontinued`, ...) is reachable from
`fact_sales` in exactly one join, so an analyst — or a BI tool
generating SQL automatically — never has to know or care how many
sub-dimensions a "properly normalized" version might have split it
into.

## What snowflaking this would look like

Cardinality check first, since it explains the trade-off:

```sql
SELECT COUNT(*) AS products, COUNT(DISTINCT category) AS categories,
       COUNT(DISTINCT brand) AS brands, COUNT(DISTINCT subcategory) AS subcategories
FROM dim_product;
```

| products | categories | brands | subcategories |
|---|---|---|---|
| 150 | 8 | 24 | 38 |

A snowflaked design would pull `category` out into its own table —
`dim_category(category_id, category_name)`, 8 rows — and similarly for
`brand` (24 rows) and `subcategory` (38 rows), with `dim_product`
holding `category_id`/`brand_id`/`subcategory_id` foreign keys instead
of the text values themselves (illustrative DDL, not something built
in this repo's read-only database):

```sql
-- illustrative only — not created in Oakhaven's database
CREATE TABLE dim_category (category_id INTEGER PRIMARY KEY, category_name TEXT);
CREATE TABLE dim_brand (brand_id INTEGER PRIMARY KEY, brand_name TEXT);
CREATE TABLE dim_product_snowflaked (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT,
    category_id INTEGER REFERENCES dim_category(category_id),
    brand_id INTEGER REFERENCES dim_brand(brand_id),
    unit_price REAL
);
```

Now the "net sales by category" query needs a second join:
`fact_sales → dim_product_snowflaked → dim_category`. That's the
snowflake trade explicitly: you save storage (the string `"Climbing"`
is written once instead of 1,858 times across the fact join path) at
the cost of one more join for *every single query* that wants a
category name. For 8 distinct category strings sitting on 150 product
rows, that storage savings is trivial — a few hundred bytes — and the
extra join cost is paid by every analyst, every BI dashboard, every
downstream query, forever. The star wins here by a wide margin.

## When snowflaking actually earns its keep

Snowflaking isn't wrong, it's situational. It tends to be justified
when:

- **A sub-dimension is large, independently maintained, and shared
  across many fact tables.** A full geography hierarchy
  (country → state → city → postal code) with its own attributes
  (population, timezone, tax rate) is a legitimate candidate for its
  own table if a dozen different fact tables across the warehouse all
  need to join to it consistently — you want one canonical geography
  table, not that hierarchy re-flattened and copy-pasted into every
  dimension that touches a location. This is the *conformed
  dimension* idea from earlier in this tier applied at the
  sub-dimension level.
- **The sub-dimension changes on its own schedule and needs its own
  history/versioning** — e.g., a product category taxonomy that
  Oakhaven's merchandising team revises quarterly, independent of when
  individual products are added. Splitting it out lets you version the
  taxonomy (SCD Type 2) without touching every product row.
- **Storage genuinely matters and cardinality is high** — a dimension
  with millions of rows and a handful of very repetitive high-cardinality
  text attributes can make normalizing those attributes out a real,
  measurable win. This was a much stronger argument in the era of
  expensive spinning disk than it is today.

In modern columnar cloud warehouses (Snowflake, BigQuery, Databricks),
storage is cheap and compressed columnar formats make repeated string
values compress extremely well, while joins remain one of the more
expensive operations a query planner does. That shifts the default
firmly toward star schemas almost everywhere — Oakhaven's `dim_*`
views are a realistic reflection of how gold layers are actually built
in production, not a simplification for teaching purposes.

## Examples

### 1. One hop reaches every dimension attribute at once

```sql
SELECT f.order_id, p.category, p.brand, c.customer_segment, e.region
FROM fact_sales f
JOIN dim_product p ON p.product_id = f.product_id
JOIN dim_customer c ON c.customer_id = f.customer_id
JOIN dim_employee e ON e.employee_id = f.employee_id
WHERE f.order_id = 13;
```

| order_id | category | brand | customer_segment | region |
|---|---|---|---|---|
| 13 | Apparel | Crestline Outdoor | (NULL) | West |
| 13 | Climbing | Pinepack | (NULL) | West |
| 13 | Climbing | Elkstone | (NULL) | West |

(This customer's `customer_segment` happens to be NULL — one of the
~3% of `bronze_customers` rows with a missing segment, passed straight
through the star join same as any other attribute.) Three separate
one-hop joins, each reaching a fully denormalized
dimension row — no sub-joins needed to get category, segment, or
region. This is the star schema's defining shape: fact in the middle,
every dimension attribute exactly one join away, regardless of how
many logical "categories of category" a normalized purist might
imagine.

### 2. Cardinality is the deciding number

```sql
SELECT COUNT(DISTINCT department) AS depts, COUNT(DISTINCT region) AS regions
FROM dim_employee;
```

| depts | regions |
|---|---|
| 4 | 5 |

4 departments and 5 regions sitting on 35 employee rows — splitting
these into `dim_department`/`dim_region` tables would save essentially
nothing and cost a join on every query that touches `dim_employee`.
When you're deciding whether to snowflake an attribute, this is the
first number to check: how many distinct values does it actually have,
relative to the dimension's row count? Low cardinality relative to the
dimension almost always means "leave it flat."

## Common mistakes

- **Snowflaking out of habit from OLTP training.** If your instinct
  says "this string repeats, normalize it," remember you're in the
  dimensional-modeling world now, where repetition inside a dimension
  is an accepted, deliberate cost paid to keep queries at one join.
- **Confusing "the fact table has many foreign keys" with
  "snowflaked."** A star schema can have a dozen dimensions
  radiating off one fact table — that's still a star. Snowflaking is
  specifically about a *dimension* branching into further
  sub-dimensions, not about how many dimensions a fact table has.
- **Snowflaking a dimension that isn't shared or high-cardinality.**
  If nothing else in the warehouse needs `dim_category` as its own
  table, and it only has 8 distinct values, breaking it out just adds
  a join with no corresponding benefit.
- **Assuming snowflaking is never right.** Shared conformed
  sub-dimensions (geography, a versioned product taxonomy) are real,
  legitimate reasons to snowflake — the mistake is doing it reflexively
  rather than for one of those specific reasons.

## Key takeaways

- Star schema: dimensions are flat and denormalized, one join away
  from the fact table. Snowflake schema: dimensions branch into
  further normalized sub-dimensions, adding joins.
- Oakhaven's `dim_product`, `dim_customer`, and `dim_employee` are all
  stars — `category`/`brand`/`department`/`region` are plain text
  columns, not foreign keys to sub-dimension tables — because their
  attribute cardinality is low relative to the dimension itself.
- The trade is storage/redundancy (star pays more) vs. join complexity
  (snowflake pays more). Modern columnar warehouses make storage cheap
  and joins comparatively expensive, which is why star is the default
  in production gold layers, not just in this repo.
- Snowflaking is justified when a sub-dimension is large, independently
  versioned, and genuinely shared/conformed across multiple fact
  tables — not just because a value repeats.
- This is a reusable design heuristic: before normalizing an attribute
  out of a dimension, check its cardinality relative to the dimension's
  row count, and ask whether any other fact table in the warehouse
  needs to share it.
