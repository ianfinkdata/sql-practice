# 4. Designing a Dimension

## The idea

A well-designed dimension is a **conformed** lookup table: one row per
instance of the entity it describes, with a stable key that any fact
table can join to, and a consistent set of attributes that mean the
same thing everywhere they're used. "Conformed" is the technical term
for "this dimension means the same thing no matter which fact table
references it" — if Oakhaven ever added a `fact_support_tickets` table
alongside `fact_sales`, both could join to the *same* `dim_customer`
and get identical customer attributes, rather than each fact
maintaining its own slightly-different customer lookup. That
reusability is the entire economic case for building dimensions as
separate objects instead of just embedding customer details directly
into every fact table.

Designing a dimension well means answering a short checklist:

1. What's the key other tables will join on?
2. What are the descriptive attributes worth carrying?
3. Is it really one row per entity — or does it just look that way?

That third question is where things get interesting, and Oakhaven's
`dim_customer` is a real, working example of a dimension that
*doesn't* fully answer it.

## Dissecting `dim_customer`

```sql
-- project/gold/dim_customer.sql
CREATE VIEW dim_customer AS
SELECT
    customer_id,
    first_name,
    last_name,
    full_name,
    email,
    phone,
    state,
    signup_date,
    is_active,
    customer_segment
FROM silver_customers;
```

This is about as simple as a dimension gets: a straight `SELECT` over
the cleaned `silver_customers` view, with no filtering, deduplication,
or aggregation. `customer_id` is the natural key (module 2) other
tables join on — `fact_sales.customer_id` references it directly. Every
other column is a plain attribute: name fields, contact info, `state`,
`signup_date`, `is_active`, `customer_segment`. None of them are
measures; nothing here gets summed.

The view's own header comment is explicit about the one thing it
deliberately does *not* do:

> One row per bronze_customers row (including the intentional
> near-duplicate people — deduping them is a dedicated ROW_NUMBER
> lesson, not baked in here).

That's worth taking seriously as a real design gap, not just a
throwaway comment — verify it.

## The open modeling question: does `dim_customer` really have one row per customer?

```sql
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_ids
FROM dim_customer;
```

| total_rows | distinct_ids |
|---|---|
| 600 | 600 |

Every row has a unique `customer_id` — as a *key*, this dimension is
fine. But `customer_id` uniqueness only proves "one row per ID," not
"one row per real person." Check by normalized email instead, which is
a much better proxy for "the same human being":

```sql
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT LOWER(TRIM(email))) AS distinct_people_by_email
FROM dim_customer
WHERE email IS NOT NULL AND email <> '';
```

| total_rows | distinct_people_by_email |
|---|---|
| 565 | 536 |

565 rows have a usable email, but only 536 distinct normalized email
addresses among them — 29 rows are redundant. Here's one concrete
pair:

```sql
SELECT customer_id, first_name, last_name, email, signup_date, customer_segment
FROM dim_customer
WHERE LOWER(TRIM(email)) = 'alexandra.wang@yahoo.com'
ORDER BY customer_id;
```

| customer_id | first_name | last_name | email | signup_date | customer_segment |
|---|---|---|---|---|---|
| 165 | Alexandra | Wang | alexandra.wang@yahoo.com | 2019-05-29 | Wholesale |
| 581 | Alexandra | Wang | alexandra.wang@yahoo.com | 2025-05-27 | Retail |

Same person (same normalized email, same name), two `customer_id`
values, two different `customer_segment` values (`Wholesale` vs.
`Retail`) and two different signup dates. This is documented directly
in `project/docs/data_dictionary.md`: `customer_id` 571–600 (30 rows)
are intentional near-duplicates of 30 of the base 1–570 rows —
"same underlying person... but with varied name casing/whitespace...
mirroring a person who signed up twice."

`dim_customer` passes all 600 rows through untouched. **This is an
open modeling question, not a bug** — it's flagged in the source
comment precisely so you notice it and reason about the trade-off
yourself.

## Previewing the fix (without changing `dim_customer.sql`)

Tier 3 taught the `ROW_NUMBER()` deduplication pattern for exactly
this situation. Here's what applying it *would* look like — a
`SELECT`-only preview, not a change to the actual gold view:

```sql
WITH ranked AS (
  SELECT
    customer_id, first_name, last_name, email, signup_date, customer_segment,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(TRIM(email))
      ORDER BY signup_date ASC, customer_id ASC
    ) AS rn
  FROM dim_customer
  WHERE email IS NOT NULL AND email <> ''
)
SELECT customer_id, first_name, last_name, email, signup_date, customer_segment, rn
FROM ranked
WHERE LOWER(TRIM(email)) = 'alexandra.wang@yahoo.com'
ORDER BY customer_id;
```

| customer_id | first_name | last_name | email | signup_date | customer_segment | rn |
|---|---|---|---|---|---|---|
| 165 | Alexandra | Wang | alexandra.wang@yahoo.com | 2019-05-29 | Wholesale | 1 |
| 581 | Alexandra | Wang | alexandra.wang@yahoo.com | 2025-05-27 | Retail | 2 |

Keeping only `rn = 1` (earliest signup) per normalized email would
remove:

```sql
WITH ranked AS (
  SELECT customer_id,
         ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ORDER BY signup_date ASC, customer_id ASC) AS rn
  FROM dim_customer
  WHERE email IS NOT NULL AND email <> ''
)
SELECT COUNT(*) AS rows_that_would_be_removed FROM ranked WHERE rn > 1;
```

| rows_that_would_be_removed |
|---|---|
| 29 |

## Why this isn't a trivial fix — the real trade-off

Deduplicating `dim_customer` sounds free, but it isn't, and this is
exactly the kind of judgment call real dimensional modeling requires:

- **Conflict resolution.** The two Alexandra Wang rows disagree on
  `customer_segment` (`Wholesale` vs. `Retail`) and `state`. Which one
  is "true"? Earliest? Most recent? Some business rule you'd need to
  ask a stakeholder about?
- **Fact table impact.** `fact_sales.customer_id` references *both*
  `customer_id` values (165 and 581) for orders placed under either
  registration. If you dedupe the dimension down to one canonical row,
  you must also redirect the fact table's foreign keys to point at the
  surviving ID — otherwise you've created orphan foreign keys pointing
  at rows that no longer exist in the dimension. That redirect step
  (a "customer_id crosswalk") is itself real work, and it's the core
  of what's called **master data management (MDM)** in industry.
- **It compounds with grain and key design (modules 2–3).** Once you
  dedupe, `customer_id` alone is no longer a trustworthy natural key
  for "one row per person" — which is exactly the kind of situation
  that motivates introducing a proper surrogate key, decoupled from
  the source system's ID.

This tier leaves `dim_customer` as-is deliberately, so you can treat
"should this dimension be deduplicated, and what would it cost to do
correctly" as a genuine open design exercise rather than a solved
problem.

## Common mistakes

- **Assuming a dimension is conformed just because it has a primary
  key.** A unique key guarantees row identity, not entity identity —
  `dim_customer` proves this directly.
- **Deduping a dimension without updating the fact table's foreign
  keys.** Removing "loser" rows from a dimension without redirecting
  the fact rows that pointed at them creates orphans where none
  existed before.
- **Picking a dedup "winner" without a documented rule.** "Keep the
  first one" and "keep the most complete one" produce different
  results — pick a rule deliberately and write it down, don't let it
  be whatever `ROW_NUMBER()`'s default ordering happens to do.
- **Treating a dimension design as finished just because it compiles.**
  `dim_customer.sql` runs fine and returns 600 clean-looking rows. It
  still has an unresolved identity question baked in — "does it run
  without error" and "is it correctly modeled" are different bars.

## Key takeaways

- A well-designed dimension is **conformed**: reusable across any fact
  table that needs the same entity, with a stable key and consistent
  attributes.
- `dim_customer` is a real, working dimension that intentionally
  carries an unresolved data quality issue: 30 of its 600 rows are
  near-duplicate people, verifiable by comparing `COUNT(DISTINCT
  customer_id)` (600 — looks fine) against `COUNT(DISTINCT
  LOWER(TRIM(email)))` (536 — reveals the overlap).
- The `ROW_NUMBER() OVER (PARTITION BY ...)` pattern from Tier 3 is the
  right tool to dedupe it — but doing so correctly requires a
  conflict-resolution rule and a fact-table key redirect, not just a
  `WHERE rn = 1` filter.
- "Does it have a unique key" and "is it correctly modeled" are
  different questions — always ask the second one too.
