# Tier 5 — Master Challenges

> These aren't quiz questions with one keystroke answer — they're **design
> challenges**. For each, sketch your model first, then open the worked
> discussion. The solutions argue trade-offs and show SQL where it makes the
> idea concrete.

Built on the [shared dataset](README.md#the-shared-dataset): `customers`,
`sales`, `sales_rep`, `products`.

← Back to [Exercises](README.md) · matching curriculum: [`05-master`](../curriculum/05-master/)

---

## 1. Normalize a denormalized table

A team hands you one flat table:

```
sales_flat(sale_id, sale_date, amount,
           customer_name, customer_region, customer_email,
           rep_name, rep_commission_rate)
```

Customer and rep details repeat on every sale. Refactor it to a clean
normalized model and explain what each normal form bought you.

<details><summary>Show solution</summary>

**Model answer.** The flat table violates **3NF**: `customer_*` columns depend on
the customer, not on the sale's key, and `rep_*` columns depend on the rep — these
are *transitive dependencies*. Split them into their own tables:

```sql
CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    region        VARCHAR(50),
    email         VARCHAR(255)
);

CREATE TABLE sales_rep (
    rep_id          INTEGER PRIMARY KEY,
    rep_name        VARCHAR(100) NOT NULL,
    commission_rate NUMERIC(4,3)
);

CREATE TABLE sales (
    sale_id     INTEGER PRIMARY KEY,
    sale_date   DATE NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    customer_id INTEGER REFERENCES customers,
    rep_id      INTEGER REFERENCES sales_rep
);
```

**What you gained**

- **No update anomalies.** A customer's email lives in exactly one row; renaming a
  region is one `UPDATE`, not thousands.
- **No insertion anomaly.** You can register a rep before they've closed a sale.
- **No deletion anomaly.** Deleting their last sale no longer erases the
  customer's details.
- **Integrity** via foreign keys; **storage** drops because details stop
  repeating.

Trade-off: reads now need joins. That's the right call for an **OLTP**
(write-heavy) system — and it sets up Challenge 2, where analytics deliberately
goes the *other* way.

</details>

---

## 2. Design a star schema

The flat data from #1 now feeds a BI dashboard slicing revenue by customer
region, rep, product category, and date. Design a **star schema** for it.

<details><summary>Show solution</summary>

**Model answer.** Put one **fact** at the center, surrounded by **dimensions**;
analytics favors a few wide, denormalized dimensions over many normalized tables
because it minimizes joins and is intuitive to slice.

```sql
-- Fact: one row per sale line, all measures + foreign keys to dims
CREATE TABLE fact_sales (
    sale_id        BIGINT PRIMARY KEY,
    date_key       INTEGER  REFERENCES dim_date,
    customer_key   INTEGER  REFERENCES dim_customer,
    rep_key        INTEGER  REFERENCES dim_rep,
    product_key    INTEGER  REFERENCES dim_product,
    amount         NUMERIC(12,2),    -- additive measure
    quantity       INTEGER
);

CREATE TABLE dim_date (
    date_key   INTEGER PRIMARY KEY,   -- e.g. 20240115
    full_date  DATE,
    year       INTEGER,
    quarter    INTEGER,
    month      INTEGER,
    day_name   VARCHAR(10)
);

CREATE TABLE dim_customer (
    customer_key INTEGER PRIMARY KEY, -- surrogate key
    customer_id  INTEGER,             -- natural/business key
    customer_name VARCHAR(100),
    region        VARCHAR(50)
);
-- dim_rep, dim_product follow the same shape.
```

**Design notes**

- **Surrogate keys** (`*_key`) decouple the warehouse from source ids and are
  required for slowly changing dimensions (Challenge 3).
- **Grain:** "one row per sale line." Decide the grain *first* — every measure
  must be true at that grain.
- **Additive measures** (`amount`, `quantity`) sum cleanly across any dimension.
- A `dim_date` table beats date functions: it pre-computes fiscal periods,
  holidays, weekday flags.
- Keep dimensions denormalized (star), not snowflaked, unless a dimension is huge
  and volatile.

A dashboard query is then a wide-but-shallow join:

```sql
SELECT d.year, c.region, SUM(f.amount) AS revenue
FROM fact_sales f
JOIN dim_date d     ON f.date_key = d.date_key
JOIN dim_customer c ON f.customer_key = c.customer_key
GROUP BY d.year, c.region;
```

</details>

---

## 3. Implement an SCD Type 2 with MERGE

Customers move regions. The business wants **history**: revenue should be
attributed to the region the customer was in *at the time of each sale*. Design a
Type 2 slowly changing dimension and load it with `MERGE`.

<details><summary>Show solution</summary>

**Model answer.** SCD2 keeps a *new row* per version of a customer, bounded by
effective dates and flagged with `is_current`.

```sql
CREATE TABLE dim_customer (
    customer_key  BIGINT PRIMARY KEY,   -- surrogate, new per version
    customer_id   INTEGER NOT NULL,     -- business key (repeats across versions)
    customer_name VARCHAR(100),
    region        VARCHAR(50),
    valid_from    DATE NOT NULL,
    valid_to      DATE,                 -- NULL = open-ended
    is_current    BOOLEAN NOT NULL
);
```

The classic two-step load: **(1)** expire the current row when an attribute
changed, then **(2)** insert the new version.

```sql
-- Step 1: close out rows whose tracked attributes changed
MERGE INTO dim_customer AS tgt
USING staging_customers AS src
   ON tgt.customer_id = src.customer_id
  AND tgt.is_current  = TRUE
 WHEN MATCHED AND tgt.region <> src.region THEN
     UPDATE SET valid_to   = CURRENT_DATE,
                is_current = FALSE;

-- Step 2: insert brand-new customers and new versions of changed ones
INSERT INTO dim_customer
    (customer_key, customer_id, customer_name, region,
     valid_from, valid_to, is_current)
SELECT nextval('cust_key_seq'), s.customer_id, s.customer_name, s.region,
       CURRENT_DATE, NULL, TRUE
FROM staging_customers s
LEFT JOIN dim_customer d
       ON d.customer_id = s.customer_id AND d.is_current = TRUE
WHERE d.customer_id IS NULL          -- truly new
   OR d.region <> s.region;          -- changed region
```

The **fact** stores the `customer_key` that was current at sale time, so a sale
stays glued to the *historical* region forever. To query "as of" a date, filter
`valid_from <= :asof AND (valid_to IS NULL OR valid_to > :asof)`.

Pick the SCD type per column: Type 1 (overwrite) for typo fixes, Type 2 for
attributes whose history matters — region here.

</details>

---

## 4. Design medallion layers

You're standing up a lakehouse. Map our sales data through **Bronze → Silver →
Gold** layers and say what each layer owns.

<details><summary>Show solution</summary>

**Model answer.** The medallion architecture is progressive refinement; each layer
has a single job so failures and reprocessing are isolated.

| Layer | Purpose | Our data |
|-------|---------|----------|
| **Bronze** | Raw, append-only landing — exactly as ingested, plus load metadata | Raw `sales`, `customers`, `rep` files/CDC, with `_ingested_at`, `_source_file`. Schema-on-read, nothing dropped. |
| **Silver** | Cleaned, conformed, deduplicated, typed; business keys resolved | Validated `sales` joined to good `customers`/`reps`; bad rows quarantined; `amount` cast to decimal; one row per sale. |
| **Gold** | Business-level aggregates / star schema for consumption | `fact_sales` + dims from Challenge 2; pre-aggregated revenue-by-region-by-month marts. |

**Why layer at all**

- **Reprocessability:** Bronze is immutable, so you can rebuild Silver/Gold after
  a logic fix without re-ingesting from the source.
- **Separation of concerns:** cleaning lives in Silver, business logic in Gold —
  debugging is localized.
- **Trust gradient:** analysts query Gold; engineers debug in Silver; auditors
  trace back to Bronze.

```sql
-- Silver: dedupe + type + conform, idempotently
CREATE TABLE silver_sales AS
SELECT CAST(sale_id AS BIGINT)        AS sale_id,
       CAST(sale_date AS DATE)        AS sale_date,
       customer_id,
       rep_id,
       CAST(amount AS NUMERIC(12,2))  AS amount
FROM (
    SELECT *, ROW_NUMBER() OVER (
               PARTITION BY sale_id ORDER BY _ingested_at DESC) AS rn
    FROM bronze_sales
) x
WHERE rn = 1                    -- keep latest version of each sale
  AND amount IS NOT NULL;       -- quarantine the rest
```

</details>

---

## 5. Partitioning strategy

`fact_sales` is heading toward a billion rows and most queries filter on a date
range. Propose a partitioning strategy and its trade-offs.

<details><summary>Show solution</summary>

**Model answer.** **Range-partition the fact by date** (typically monthly), since
date is the dominant predicate.

```sql
CREATE TABLE fact_sales (
    sale_id   BIGINT,
    sale_date DATE NOT NULL,
    amount    NUMERIC(12,2)
    -- ...
) PARTITION BY RANGE (sale_date);

CREATE TABLE fact_sales_2024_01
    PARTITION OF fact_sales
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
-- one child per month...
```

**Why it pays off**

- **Partition pruning:** a query for January only touches the January partition —
  the rest is skipped entirely.
- **Cheap lifecycle:** archiving/dropping old data is a metadata `DROP PARTITION`,
  not a billion-row `DELETE`.
- **Maintenance** (vacuum, stats, index rebuild) runs per partition.

**Trade-offs / pitfalls**

- **Granularity:** too fine (daily) → thousands of tiny partitions and planning
  overhead; too coarse (yearly) → no pruning. Monthly is a common sweet spot;
  target partitions in the ~GB range, not KB.
- Queries that **don't** filter on the partition key get no pruning — choose the
  key for the *common* access pattern.
- **Skew:** a hot recent partition can still be huge; consider sub-partitioning or
  clustering by `customer_id` within a partition.
- On lakehouses, beware the **small-files problem** from over-partitioning;
  compact regularly.

Sibling technique: **clustering/Z-ordering** by a secondary column
(e.g. `customer_id`) co-locates related rows *inside* a partition for the
non-date filters.

</details>

---

## 6. Anti-pattern refactor

You inherit this nightly report. Critique it and refactor it into something
correct, fast, and maintainable.

```sql
SELECT *
FROM sales s, customers c
WHERE s.customer_id = c.customer_id
  AND s.amount = (SELECT MAX(amount) FROM sales WHERE customer_id = s.customer_id)
  AND s.sale_date > '01/06/2024'
ORDER BY (SELECT region FROM customers WHERE customer_id = s.customer_id);
```

<details><summary>Show solution</summary>

**Model answer — the smells**

1. **Implicit comma join** with the filter in `WHERE` — easy to forget the join
   condition and produce a cartesian explosion. Use explicit `JOIN ... ON`.
2. **`SELECT *`** in a report — fragile, wide, and ambiguous across two tables.
   Name the columns you need.
3. **Correlated subquery per row** for the per-customer max — a window function
   does it in one pass.
4. **Ambiguous date literal** `'01/06/2024'` — is that June 1 or Jan 6? Use ISO
   `DATE '2024-06-01'` and a sargable comparison.
5. **Subquery in `ORDER BY`** re-reads `customers` for every row — just sort by the
   already-joined column.

**Refactor**

```sql
WITH ranked AS (
    SELECT s.sale_id,
           s.sale_date,
           s.amount,
           c.customer_name,
           c.region,
           ROW_NUMBER() OVER (
               PARTITION BY s.customer_id
               ORDER BY s.amount DESC
           ) AS rn
    FROM sales AS s
    JOIN customers AS c ON c.customer_id = s.customer_id
    WHERE s.sale_date > DATE '2024-06-01'
)
SELECT sale_id, sale_date, amount, customer_name, region
FROM ranked
WHERE rn = 1            -- each customer's largest qualifying sale
ORDER BY region;
```

**What improved:** one scan instead of N correlated subqueries, an explicit and
safe join, an unambiguous sargable date predicate, an explicit column list, and
a clean sort — plus a CTE that reads like its intent. (One subtlety: `ROW_NUMBER`
picks one row on ties; switch to `RANK` and keep `rn = 1` if you want *all* tied
top sales.)

</details>

---

You've reached the top of the ladder. Loop back to the
[curriculum](../curriculum/) to deepen any tier, or revisit
[Tier 4](tier-4-expert.md) to drill the mechanics these designs rely on.
