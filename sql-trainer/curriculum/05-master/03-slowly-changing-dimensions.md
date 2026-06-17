# Slowly Changing Dimensions: Keeping the Past Honest

> When a customer's region changes, do you overwrite history — or remember it?

## The idea

A customer named Ada lives in the West region. You report her sales under "West" all year. Then in July she moves, and her region becomes "East."

Here's the quiet, important question: *what should happen to January's sales?* Should they now show as "East" — because that's where Ada is? Or stay as "West" — because that's where she *was* when those sales happened? There's no universally right answer. There's only the answer your business needs. And the patterns for handling this are called **Slowly Changing Dimensions**, or SCD.

The name says it: dimension data (region, name, category) changes — but *slowly*, occasionally, not every second like a fact. The art is in deciding how to remember, or forget, those changes. Kimball numbered the strategies, and three of them cover almost everything.

## Why it matters

Reports are promises about the past. If your dimension silently rewrites history every time someone moves, your year-over-year comparisons quietly lie, and nobody notices until an executive asks why the numbers shifted. Choosing an SCD strategy *on purpose* — per attribute, per business need — is what separates a warehouse you can trust from one you merely hope is right.

## The types, in plain English

**Type 1 — Overwrite.** Ada moves; you update her region to "East" and the old value is gone. Simple, cheap, no history. Use it when the past genuinely doesn't matter — fixing a typo in a name, correcting a bad email. After a Type 1 change, *all* of Ada's sales report as "East," including January's. You've decided the present truth is the only truth.

**Type 2 — Add a new row.** This is the workhorse for real history. Instead of changing Ada's row, you *close* the old one and *open* a new one. Ada now has two rows in the dimension: one for her West life, one for her East life, distinguished by date ranges and a flag. Each sale, via its surrogate key, points at the version of Ada that was current *when the sale happened.* January stays "West"; August is "East." History is preserved perfectly. The cost is more rows and a bit more machinery.

**Type 3 — Keep a previous-value column.** Add a `previous_region` column alongside `region`. You can see *one* step back — where Ada was before her latest move — but not her full history. Useful when you want to compare "current org vs. prior org" without the full weight of Type 2. Limited memory, by design.

**A note on Types 4 and 6.** *Type 4* moves the fast-changing attributes into a separate "history" mini-dimension, keeping the main dimension lean. *Type 6* is the popular hybrid — its name is literally 1 + 2 + 3 — combining a Type 2 row-versioning backbone with a Type 1 "current value" column and a Type 3 "previous value" column, so you can ask both "what was true then?" and "what's true now?" from the same table. You'll reach for these rarely, but it's good to know they exist.

## See it: the shape of a Type 2 dimension

A Type 2 dimension carries three extra columns: when this version became valid, when it stopped, and whether it's the live one.

```sql
CREATE TABLE dim_customer (
  customer_key   INTEGER PRIMARY KEY,   -- surrogate key, unique per VERSION
  customer_id    INTEGER,               -- the natural/business key
  customer_name  VARCHAR(120),
  region         VARCHAR(40),
  valid_from     DATE,                  -- this version's start
  valid_to       DATE,                  -- end (or 9999-12-31 if current)
  is_current     BOOLEAN                -- true for exactly one row per customer_id
);
```

Ada's two lives, side by side:

| customer_key | customer_id | region | valid_from | valid_to | is_current |
|---|---|---|---|---|---|
| 4471 | 12 | West | 2026-01-01 | 2026-06-30 | false |
| 5588 | 12 | East | 2026-07-01 | 9999-12-31 | true |

Two rules make this trustworthy: the date ranges never overlap (each day maps to exactly one version), and `is_current` is true for **exactly one** row per `customer_id`. To find today's customers, filter `WHERE is_current`. To reconstruct any past date, filter `WHERE that_date BETWEEN valid_from AND valid_to`.

## The MERGE pattern for SCD2

How do you *apply* a change? You compare incoming source data against the current rows and do two things at once: close the row that changed, and insert the new version. The `MERGE` statement is built for exactly this "match, then update-or-insert" logic.

```sql
-- Step 1: expire the current row when the incoming region differs
MERGE INTO dim_customer AS d
USING staging_customer AS s
  ON d.customer_id = s.customer_id
 AND d.is_current = TRUE
WHEN MATCHED AND d.region <> s.region THEN
  UPDATE SET d.valid_to = CURRENT_DATE - 1,
             d.is_current = FALSE;

-- Step 2: insert the new current version for anyone changed or brand-new
INSERT INTO dim_customer
  (customer_id, customer_name, region, valid_from, valid_to, is_current)
SELECT s.customer_id, s.customer_name, s.region,
       CURRENT_DATE, DATE '9999-12-31', TRUE
FROM staging_customer s
LEFT JOIN dim_customer d
  ON d.customer_id = s.customer_id AND d.is_current = TRUE
WHERE d.customer_id IS NULL          -- brand new customer
   OR d.region <> s.region;          -- changed region
```

The honest truth: doing SCD2 in pure `MERGE` with both the expire *and* the insert in one statement is fiddly, because a single `MERGE` can't easily update one row and insert another for the same match. The robust, readable pattern is the two-step above — expire, then insert. Many ETL tools wrap this for you, but knowing the moving parts means you'll never be mystified when the tool misbehaves.

> **Dialect note:** `MERGE` exists in Oracle, SQL Server, Postgres 15+, and Databricks/Delta; MySQL lacks it and uses `INSERT ... ON DUPLICATE KEY UPDATE` for the simpler cases. Syntax and capabilities vary — see the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Pick the SCD type per attribute, not per table.** A name typo might be Type 1 while region is Type 2, in the very same dimension.
- **Overlapping date ranges are silent poison.** A single day mapping to two versions double-counts everything. Guard the boundaries.
- **More than one `is_current` per customer means your pipeline broke.** Add a check for it.
- **Facts must join to the right version.** A fact joins to the dimension row whose date range contains the fact's date — not just `is_current`.
- **Type 2 grows forever.** Plan for the row count, and consider Type 4 if an attribute changes too often.

## Practice

1. For our `customers` table, classify each attribute (name, region, email, signup_date) as Type 1, 2, or 3, and justify each choice in one sentence.
2. Ada moves regions twice in one year. Draw the rows a Type 2 dimension would hold, with valid_from, valid_to, and is_current filled in.
3. Explain, without code, why a sales fact must join on the dimension version's date range rather than simply on `is_current`.
4. Design the staging-and-merge steps for tracking commission-rate changes on `sales_rep` as Type 2. What columns do you add, and what does your nightly load do?

---
**Prev:** [Dimensional Modeling](./02-dimensional-modeling.md) · **Next:** [Medallion Architecture](./04-medallion-architecture.md)
