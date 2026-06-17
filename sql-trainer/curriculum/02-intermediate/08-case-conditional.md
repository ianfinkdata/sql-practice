# CASE & Conditional Logic

> If-this-then-that, right inside your query — label, bucket, and count by condition.

## The idea

Plain SQL columns just report what's stored. But often you want to *react* to a value: if an amount is large, call it "high"; otherwise "low." If a region is blank, show "Unknown." That's decision-making, and `CASE` is how SQL makes decisions.

`CASE` is SQL's version of "if / else if / else." You give it a ladder of conditions. It checks them top to bottom, and the **first** one that's true wins. If none match, it falls back to an optional `ELSE` (or returns NULL if there's no ELSE).

Think of sorting mail into pigeonholes. You look at each letter and decide: bills here, personal there, junk in the bin. Each letter goes in exactly one slot, based on the first rule it satisfies. CASE sorts values the same way.

There are two forms:

- **Searched CASE** — each branch has its own full condition. The flexible, general form.
- **Simple CASE** — you name one column up front and just list values to match against it. Shorter, but only for equality checks.

## Why it matters

CASE turns raw values into meaningful labels and buckets — the difference between a column of numbers and a readable report. And paired with aggregates, it unlocks **conditional aggregation**: counting or summing only the rows that meet a condition, all within a single query. That technique alone replaces a surprising number of clumsy multi-query workarounds.

## See it

**Searched CASE in SELECT** — label each sale by size:

```sql
SELECT
  sale_id,
  amount,
  CASE
    WHEN amount >= 1000 THEN 'large'
    WHEN amount >= 100  THEN 'medium'
    ELSE 'small'
  END AS sale_size
FROM sales;
```

It checks top to bottom; a sale of 1500 matches the first branch and stops there.

**Simple CASE** — when you're just matching one column against fixed values:

```sql
SELECT
  customer_name,
  CASE region
    WHEN 'West' THEN 'Pacific'
    WHEN 'East' THEN 'Atlantic'
    ELSE 'Other'
  END AS coast
FROM customers;
```

**CASE in ORDER BY** — sort by a custom priority that doesn't exist as a column. Here, put 'West' first, then 'East', then the rest:

```sql
SELECT customer_name, region
FROM customers
ORDER BY
  CASE region
    WHEN 'West' THEN 1
    WHEN 'East' THEN 2
    ELSE 3
  END;
```

**Conditional aggregation** — the powerful one. Wrap a CASE inside SUM or COUNT to total only matching rows. Get total revenue split into large and small sales, side by side, in one query:

```sql
SELECT
  SUM(CASE WHEN amount >= 1000 THEN amount ELSE 0 END) AS large_sales_total,
  SUM(CASE WHEN amount <  1000 THEN amount ELSE 0 END) AS small_sales_total,
  COUNT(CASE WHEN amount >= 1000 THEN 1 END)           AS large_sale_count
FROM sales;
```

The trick: the CASE produces a value (or 0, or NULL) per row, and the aggregate adds up only the ones you care about. This is how you build "pivot-style" summaries — multiple conditional columns from one table scan.

## Watch out

- **Order matters in a searched CASE.** The first matching branch wins, so put narrower conditions before broader ones. `WHEN amount >= 100` placed above `WHEN amount >= 1000` would catch the big ones too early.
- **No ELSE means NULL.** Unmatched rows return NULL, which can quietly skew later calculations. Add an explicit ELSE when in doubt.
- **For COUNT, use `THEN 1` (no ELSE)** so unmatched rows become NULL and aren't counted. For SUM, use `ELSE 0` so they add nothing. Mixing these up gives wrong totals.
- **Every branch should return a compatible type.** Don't return a number in one branch and text in another.
- **Simple CASE can't do ranges or IS NULL.** It only does equality. For `>=`, `<`, or NULL checks, use the searched form.

## Practice

1. Label each sale as 'large', 'medium', or 'small' based on its amount.
2. Add a column that translates each customer's region into a friendlier label of your choosing.
3. Sort customers so a chosen priority region appears first, with all others after.
4. In a single query, produce the count of large sales (amount ≥ 1000) and the count of small sales using conditional aggregation.

---
**Prev:** [Subqueries](./07-subqueries.md) · **Next:** [Working with NULLs](./09-nulls.md)
