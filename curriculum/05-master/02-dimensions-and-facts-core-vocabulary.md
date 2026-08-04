# 2. Dimensions and Facts: Core Vocabulary

## The idea

Dimensional modeling has a small, precise vocabulary. Once you have
these six terms — **dimension**, **fact**, **measure**, **attribute**,
**grain**, and **surrogate vs. natural key** — pinned down exactly,
you can look at almost any warehouse schema in the world (retail,
finance, healthcare, ad tech) and immediately know what you're looking
at. This module defines each term precisely against Oakhaven's real
gold-layer objects, so the definitions aren't abstract — they're
things you can point at.

## The vocabulary

**Dimension** — a table of descriptive context you slice, filter, or
group by. Dimensions answer "who / what / where / when," not "how
much." Oakhaven has four: `dim_customer`, `dim_product`,
`dim_employee`, `dim_date`. Each is a lookup table of attributes about
one kind of business entity.

**Fact** — a table recording business events or measurements, at a
stated grain, referencing dimensions via key columns. Oakhaven has
one: `fact_sales`, where each row is one order line. Fact tables are
usually much taller (more rows) and much narrower (fewer descriptive
columns) than dimension tables, because they mostly hold keys and
numbers, not text.

**Measure** — a numeric column on a fact table meant to be aggregated
(`SUM`, `AVG`, etc.) across many rows. In `fact_sales`, `net_amount`
and `quantity` are measures. Not every numeric fact column is a clean
measure, though — `discount_pct` is numeric but **non-additive**:
summing it across rows produces a meaningless number (see Example 3).
Good measures are usually **additive** (safely summed across any
dimension, like `net_amount`) or at worst **semi-additive** (summable
across some dimensions but not others — Oakhaven doesn't have one, but
a classic example is an account balance, which you can sum across
customers but not across time).

**Attribute** — a descriptive, non-numeric-or-non-summable column on a
dimension, used for filtering, labeling, and grouping. `dim_product`'s
`category`, `brand`, and `is_discontinued` are attributes. Attributes
answer "what kind," not "how much."

**Grain** — the precise business statement of what one row in a fact
table represents. `fact_sales`'s grain is "one row per order line."
Grain is the single most important design decision in a star schema —
important enough to get its own lesson (module 3).

**Surrogate key vs. natural key** — a **natural key** is an identifier
that's meaningful in the source system: `customer_id` in
`bronze_customers`, assigned by whatever system originally created the
customer record. A **surrogate key** is a warehouse-generated,
business-meaningless key (often just an auto-incrementing integer)
assigned purely to identify a row *inside the dimension table itself*,
independent of the source system's ID. Surrogate keys matter most once
you need to track history (module 5's Slowly Changing Dimensions):
if one customer's row changes over time and you keep multiple versions
of it, `customer_id` alone can no longer uniquely identify a version —
you need a separate key per version.

Notably: **Oakhaven's gold dimensions don't currently use surrogate
keys.** Look at `project/gold/dim_customer.sql` — the view selects
`customer_id` straight out of `silver_customers` and uses it as the
join key `fact_sales` relies on. That's a natural key doing a
surrogate key's job. It's a defensible simplification *because* none
of Oakhaven's dimensions are actually historized yet — every `dim_*`
view reflects only the current state of its source rows (Type 1
behavior, whether or not anyone labeled it that way). Module 5 covers
exactly what would need to change if you wanted true version history.

## Examples

### 1. Classify `fact_sales`'s columns: keys vs. measures vs. pass-through attributes

```sql
PRAGMA table_info(fact_sales);
```

| cid | name | notes |
|---|---|---|
| 0-4 | `order_id`, `order_line_id`, `customer_id`, `product_id`, `employee_id` | grain + foreign keys into dimensions |
| 5 | `datekey` | foreign key into `dim_date` |
| 8-9 | `quantity`, `unit_price` | measures (additive) |
| 10 | `discount_pct` | numeric, but **not** a safe measure (non-additive — see Example 3) |
| 11 | `net_amount` | the primary measure — additive, recomputed from `quantity * unit_price * (1 - discount_pct)` in `silver_sales`, not trusted from raw `order_total` |
| 12-14 | `payment_method`, `order_status`, `channel` | degenerate attributes — descriptive text that lives directly on the fact row because it has no dimension of its own (there's no `dim_channel` table) |
| 15-16 | `is_customer_orphan`, `is_product_orphan` | data-quality flags, not measures — don't `SUM` these for a business number |

`payment_method`, `order_status`, and `channel` are worth calling out:
they're attributes, but they live on the fact table itself instead of
in a separate dimension. This is a legitimate, common pattern called a
**degenerate dimension** — an attribute with no other descriptive
columns worth breaking into its own table. You'll recognize this
pattern in real warehouses constantly (order numbers, invoice numbers,
ticket IDs).

### 2. Classify `dim_product`'s columns: pure attributes, no measures

```sql
PRAGMA table_info(dim_product);
```

| column | role |
|---|---|
| `product_id` | natural key (join target for `fact_sales.product_id`) |
| `product_name`, `category`, `subcategory`, `brand`, `is_discontinued`, `sku`, `weight_kg` | attributes |
| `unit_cost`, `unit_price` | numeric, but these describe the *product* (its current list price), not a *sale event* — they're attributes of the dimension, not measures of a fact. (`fact_sales.unit_price` is a different, related column: the price actually charged at time of sale — see the data dictionary's note on price drift.) |
| `sku_is_duplicate` | data-quality flag attribute |

This is the general rule: a numeric column's *role* — measure vs.
attribute — depends on which table it lives in and what it describes,
not on its data type. `unit_price` appears in both `dim_product`
(current catalog price, an attribute) and `fact_sales` (transaction
price, a measure of what happened).

### 3. Why `discount_pct` is not a safe measure

```sql
SELECT
  ROUND(SUM(discount_pct), 2) AS nonsense_sum_of_discount,
  ROUND(AVG(discount_pct), 4) AS simple_avg_discount,
  ROUND(SUM(quantity * unit_price * discount_pct) / SUM(quantity * unit_price), 4) AS true_weighted_avg_discount
FROM fact_sales
WHERE discount_pct IS NOT NULL;
```

| nonsense_sum_of_discount | simple_avg_discount | true_weighted_avg_discount |
|---|---|---|
| 1375.35 | 0.1146 | 0.1152 |

`SUM(discount_pct)` produces `1375.35` — a number with no business
meaning whatsoever. Even a plain `AVG` (0.1146) is a *rough*
approximation; the mathematically correct "overall discount rate" is
the dollar-weighted average (0.1152), because a 10-unit order
discounted 20% should count more than a 1-unit order discounted 20%.
This is the difference between a **measure** (safe to aggregate
directly, like `net_amount`) and a **ratio/rate stored on the fact
row** (must be recomputed from its underlying components, never summed
directly).

### 4. Natural keys aren't the same thing as real-world entity identity

```sql
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_ids
FROM dim_customer;
```

| total_rows | distinct_ids |
|---|---|
| 600 | 600 |

`customer_id` is unique per row — every row has its own ID, so as a
*key* it works fine. But "unique key" and "one row per real person"
are different guarantees: `dim_customer` has 30 rows (`customer_id`
571–600) that are near-duplicates of 30 earlier rows — the same real
person, re-registered under a new `customer_id`. The natural key
faithfully identifies *rows*; it says nothing about whether two rows
represent the same underlying business entity. Module 4 digs into this
directly.

## Common mistakes

- **Confusing "numeric" with "measure."** `discount_pct` is numeric
  and lives on a fact table, but summing it is meaningless. Ask "does
  aggregating this produce a number a business person could use?"
  before treating any numeric fact column as a measure.
- **Putting measures in a dimension or attributes in a fact without
  noticing.** `dim_product.unit_price` (catalog price, an attribute)
  and `fact_sales.unit_price` (transaction price, a measure input) are
  easy to conflate because they share a name — check which table
  you're in.
- **Assuming a unique key means one row per real-world thing.** Keys
  guarantee row identity, not entity identity. Near-duplicate rows
  (like Oakhaven's 30 re-registered customers) can each have a
  perfectly valid, perfectly unique natural key.
- **Not noticing when a dimension is missing.** `payment_method`,
  `order_status`, and `channel` sit directly on `fact_sales` with no
  backing dimension table. That's fine as a degenerate dimension when
  there's nothing more to describe about them — but if you found
  yourself wanting to add descriptive columns to `channel` (say, a
  channel owner or a launch date), that would be your signal it needs
  to become a real dimension.

## Key takeaways

- **Dimension** = descriptive context you group/filter by.
  **Fact** = an event/measurement at a stated grain, referencing
  dimensions by key.
- **Measure** = an aggregatable number on a fact (ideally additive).
  **Attribute** = a descriptive, non-aggregated column on a dimension
  (or, for a degenerate dimension, directly on a fact).
- **Grain** is the precise statement of what one fact row represents —
  the foundational decision, covered next.
- **Natural key** = meaningful in the source system. **Surrogate key**
  = warehouse-generated, meaningless, row-versioning identifier.
  Oakhaven's gold dimensions currently use natural keys directly
  because none of them are historized yet — a deliberate simplification
  worth noticing, not an oversight.
