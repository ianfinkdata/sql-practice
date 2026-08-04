# 1. Why We Model Data: OLTP vs. Analytical Schemas

## The idea

Every database serves one of two very different jobs, and the shape
that fits one job badly fits the other.

**OLTP** (Online Transaction Processing) systems run the business
minute to minute: ringing up a sale, updating an address, marking an
order shipped. They're optimized for a huge number of small, fast
writes touching one entity at a time, and they're designed — usually
via normalization (3NF and friends) — so that a fact is stored in
exactly one place. If a customer moves, you update *one* row in a
`customers` table, and every order that references that customer
automatically "sees" the new address through a foreign key. That's the
whole point of normalization: eliminate duplication so updates can't
go inconsistent.

**Analytical** systems (OLAP, data warehouses, BI layers) run the
business over weeks, quarters, years: "how much did we sell by
category last quarter," "which customers are most valuable," "is
revenue trending up." They're optimized for a small number of very
large reads that scan and aggregate millions of rows. Nobody is
updating a single customer's address here — they're summing
`net_amount` across a hundred thousand orders. This is a completely
different access pattern, and it wants a completely different shape:
**dimensional modeling**, organized around wide, denormalized fact and
dimension tables (the "star schema" this whole tier is about).

This tier teaches you to design that second shape — and to do it in a
way that transfers to any dataset, any warehouse engine, any industry.
Dimensional modeling is one of the most portable skills in data work:
the same handful of concepts (fact, dimension, grain, measure,
surrogate key) show up whether you're modeling retail sales, hospital
admissions, or ad impressions.

## Why a normalized OLTP schema is wrong for analytics

Imagine Oakhaven's real production system stores orders the way a
transactional app would: an `orders` header table (one row per order,
holding `order_date`, `customer_id`, `payment_method`, `channel`) and
a separate `order_items` table (one row per line, holding
`product_id`, `quantity`, `unit_price`). That's the *correct* design
for the app that takes orders — it avoids repeating `order_date` and
`payment_method` on every line.

Now ask an analytical question against it: "total net sales by product
category, by month." You'd need to join `order_items` → `orders` (for
the date) → `products` (for the category), then group and aggregate.
That's a three-table join for one of the simplest possible business
questions. Now add customer segment, employee region, and a
year-over-year comparison, and the query becomes a wall of joins that
every analyst has to re-derive by hand, every time, correctly.

Normalization optimizes for **write safety** (no duplicate data to go
stale) at the cost of **read complexity** (many joins to reassemble
the full picture). Analytics inverts that trade: reads vastly
outnumber writes, correctness is enforced upstream once during
loading, and duplication in a dimension table is a deliberate,
accepted cost in exchange for one-join, star-shaped queries.

## Why Oakhaven's bronze tables are a reasonable OLTP stand-in

Oakhaven doesn't literally ship an `orders` + `order_items` pair. But
`bronze_sales` is built to *behave* like a flattened export from one:
its grain is one row per order line, and every order-level attribute
(`order_date`, `customer_id`, `employee_id`, `payment_method`,
`order_status`, `channel`) is generated once per `order_id` and
repeated identically across that order's lines. That repetition is
exactly what you'd get if you took a normalized `orders` +
`order_items` system and joined them flat for an extract — which is a
very common shape for real-world data arriving in a warehouse's raw
layer. `bronze_sales` also has no primary keys, foreign keys, or CHECK
constraints (see `project/bronze/schema.sql`), which mirrors how raw,
as-ingested source extracts usually look: unconstrained, structurally
loose, and only made trustworthy by the transformation layers built on
top of them (`silver_*`, then `gold/*`).

Oakhaven's gold layer — `dim_customer`, `dim_product`, `dim_employee`,
`dim_date`, and `fact_sales` — is the analytical shape built *from*
that raw layer. That's the journey this tier is about: taking
OLTP-shaped (or OLTP-flattened) source data and deliberately
re-modeling it into a star schema built for fast, simple aggregate
queries.

## Examples

### 1. An order's lines repeat their header attributes (the "flattened OLTP export" signature)

```sql
SELECT order_id, order_line_id, product_id, quantity, unit_price,
       order_date, customer_id, channel
FROM bronze_sales
WHERE order_id = 13
ORDER BY order_line_id;
```

| order_id | order_line_id | product_id | quantity | unit_price | order_date | customer_id | channel |
|---|---|---|---|---|---|---|---|
| 13 | 1 | 21 | 4 | 412.55 | 2022-01-16 | 523 | in store |
| 13 | 2 | 46 | 1 | 623.11 | 2022-01-16 | 523 | in store |
| 13 | 3 | 67 | 5 | 88.99 | 2022-01-16 | 523 | in store |

`order_date`, `customer_id`, and `channel` are identical across all
three lines — they're order-level facts, generated once and copied
down to every line. `product_id`, `quantity`, and `unit_price` vary
per line. This split between "shared per order" and "varies per line"
is the exact seam a real OLTP header/detail table pair would have —
Oakhaven just delivers it already flattened, which is what module 3
will formalize as **grain**.

### 2. What normalization would have cost you here

If Oakhaven really stored orders normalized, answering "total sales
lines per order" would require a join. Flattened, you can just count:

```sql
SELECT COUNT(*) AS total_order_lines,
       COUNT(DISTINCT order_id) AS total_orders
FROM fact_sales;
```

| total_order_lines | total_orders |
|---|---|
| 12000 | 7199 |

12,000 line-grain fact rows collapse from 7,199 distinct orders — in a
normalized system this is literally two tables (`orders` with 7,199
rows, `order_items` with 12,000). The dimensional model keeps them as
one fact table at a clearly stated grain (module 3), trading the
"single source of truth per order attribute" guarantee for
"everything's in one place, one join away."

### 3. The payoff: one join answers a real business question

```sql
SELECT p.category, COUNT(*) AS lines, ROUND(SUM(f.net_amount), 2) AS total_net_amount
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY total_net_amount DESC
LIMIT 5;
```

| category | lines | total_net_amount |
|---|---|---|
| Climbing | 1858 | 1389650.95 |
| Winter Sports | 1834 | 1249691.54 |
| Apparel | 1556 | 1237729.99 |
| Nutrition & Hydration | 1548 | 1164289.69 |
| Footwear | 1402 | 1077941.52 |

One fact table, one dimension, one join. This is the entire value
proposition of dimensional modeling: business questions that would
require several joins across a normalized OLTP schema collapse to a
`fact JOIN dim ... GROUP BY` pattern that any analyst, any BI tool, and
any SQL engine can execute efficiently and predictably.

### 4. Bronze tables have no constraints — by design, like a raw export

```sql
SELECT sql FROM sqlite_master WHERE name = 'bronze_sales';
```

Running this shows `bronze_sales` declared with plain column types and
no `PRIMARY KEY`, `FOREIGN KEY`, or `NOT NULL` — because it's meant to
represent data as it lands from an external system, before anyone has
vouched for its integrity. Compare that to `fact_sales`, which is
built entirely on top of the cleaned `silver_sales` view, never
directly on `bronze_sales` — the messiness gets handled once, upstream,
not re-solved by every analytical query.

## Common mistakes

- **Designing a warehouse fact table in 3NF.** If your analytical
  schema needs five joins to answer "revenue by category by month,"
  you've built an OLTP schema and put a BI tool in front of it. Star
  schemas denormalize on purpose.
- **Assuming "normalized" always means "better."** Normalization is
  the right call for the system taking the order. It's the wrong call
  for the system reporting on a year of orders. Context — read volume
  vs. write volume — decides, not a universal rule.
- **Querying bronze directly for analysis.** Bronze tables are
  intentionally unclean and unconstrained. Real questions should be
  asked of the silver/gold layers, which is exactly why those layers
  exist.
- **Treating "flat" as automatically "denormalized correctly."** A
  flattened OLTP export like `bronze_sales` looks superficially like a
  fact table already, but it isn't one yet — it hasn't had its grain
  declared, its measures identified, or its keys connected to real
  dimensions. That transformation is the rest of this tier.

## Key takeaways

- OLTP schemas optimize for many small, safe writes; analytical
  schemas optimize for large, fast aggregate reads. They're solving
  different problems and should not share a design.
- Normalization (3NF) is the right tool for OLTP because it prevents
  update anomalies. It's the wrong tool for analytics because it
  forces every question through many joins.
- Dimensional modeling deliberately denormalizes: wide dimension
  tables and fact tables joined in as few hops as possible.
- Oakhaven's `bronze_sales` table — one row per order line, with
  order-level attributes repeated across lines, no constraints — is a
  realistic stand-in for a flattened OLTP export, and the gold layer
  (`dim_*` + `fact_sales`) is the analytical re-modeling of it.
- The skills in this tier — thinking in facts, dimensions, and grain —
  apply to any dataset you'll ever model, not just Oakhaven.
