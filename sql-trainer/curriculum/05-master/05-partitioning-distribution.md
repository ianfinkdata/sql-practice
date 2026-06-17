# Partitioning & Distribution: Splitting Data for Speed

> Big systems go fast by never reading data they don't need — and by spreading work evenly.

## The idea

Imagine a library with ten million books in one enormous unsorted pile. To find a book, you'd search the whole pile every time. Now imagine the same books shelved by genre, then by author. Suddenly you walk straight to the right shelf and ignore the other 99% of the building. You didn't make the library smaller — you made most of it *irrelevant* to any given question.

That's the entire idea behind partitioning, clustering, and distribution. When data gets big, the way you *win* is not by reading faster — it's by reading *less*, and by spreading the reading evenly across many workers.

There are a few related tools here, and people mix up the words, so let's separate them cleanly.

**Partitioning** physically splits one logical table into chunks based on a column — most often a date. All of January's sales live in one partition, February's in another. When a query asks for "March sales," the engine skips January and February entirely. This skipping is called **partition pruning**, and it's the single biggest performance lever in large analytical systems.

**Clustering** (or sorting) controls the *order* of data *within* the storage. If rows are sorted by region, all the "West" rows sit physically together, so a region filter reads a tight band instead of scattered rows everywhere. Partitioning chooses which boxes to open; clustering arranges the items inside each box.

**Bucketing** (or hash distribution) splits data into a *fixed number* of buckets by hashing a column — say, `customer_id` into 32 buckets. The same customer always lands in the same bucket. This is gold for joins: if two tables are bucketed the same way on the same key, the engine can join bucket-to-bucket without shuffling data across the network.

**Distribution** is the big-system cousin: when a table is spread across many machines, the distribution key decides *which machine* each row lives on. Choose it well and joins happen locally on each machine. Choose it badly and the system spends all its time shipping rows between machines.

## Why it matters

At a thousand rows, none of this matters — scan it all, who cares. At a billion rows, it's the difference between a query that returns in two seconds and one that times out after an hour. The skill ceiling of working at scale is mostly *this*: arranging data so the engine can ignore most of it and so the work splits evenly.

## See it: pruning in action

A table partitioned by month, and a query that touches only one partition:

```sql
-- Conceptually: sales split into monthly partitions
-- A filter on the partition column lets the engine prune
SELECT region, SUM(amount)
FROM sales
WHERE sale_date >= DATE '2026-03-01'
  AND sale_date <  DATE '2026-04-01'   -- only the March partition is read
GROUP BY region;
```

The magic word is **pruning**: because the filter is on the partition column, the engine reads one partition and skips the rest. Write the *same* logic in a way that hides the partition column — say, `WHERE EXTRACT(MONTH FROM sale_date) = 3` — and pruning often breaks, because the engine can no longer match the filter to a partition. The lesson: *filter on the raw partition column directly* whenever you want pruning.

## The skew problem

Splitting only helps if the splits are *even*. **Data skew** is when one partition or one machine gets far more data than the others — so while nine workers finish instantly, the tenth grinds for an hour and everyone waits for it. The classic cause is partitioning on a lopsided key: if 80% of your sales come from one region, partitioning by region makes that one partition a monster.

The cure is to choose split keys that spread data evenly. High-cardinality, well-distributed columns (a customer ID, a hashed key) make better distribution keys than a column with a few dominant values. Watching for skew is a permanent part of operating at scale — we'll return to it in the next module.

## Choosing well, in three questions

- **Partition by what you filter on most** — usually a date. Aim for partitions that aren't too small (thousands of tiny partitions create their own problems) nor too large.
- **Cluster by your secondary filters** — the columns you often add after the date, like region.
- **Bucket/distribute by your join keys** — so big joins happen without shuffling rows across the network.

> **Dialect note:** the mechanics vary widely by engine.
> - **Postgres** uses *declarative partitioning* — `CREATE TABLE ... PARTITION BY RANGE (sale_date)` with child partition tables.
> - **MySQL** has built-in `PARTITION BY RANGE/HASH/KEY (...)` clauses on the table definition.
> - **Oracle** offers rich partitioning (range, list, hash, composite) plus local/global partitioned indexes.
> - **Databricks / Delta Lake** historically used `PARTITIONED BY` plus **Z-ORDER** for multi-column clustering, and now favors **liquid clustering**, which adapts the data layout automatically without rigid partition folders.
>
> See the [Dialect Decoder](../../dialect-decoder/) for the exact syntax per engine.

## Watch out

- **Hiding the partition column kills pruning.** Wrapping it in a function (`EXTRACT`, `CAST`) in your `WHERE` often forces a full scan.
- **Over-partitioning is its own disease.** Thousands of tiny partitions create overhead and the "small files problem" (next module).
- **Skew silently wrecks parallelism.** One fat partition means one slow worker holds everyone hostage.
- **Bucketing pays off only when join keys and bucket counts match** on both sides of the join.
- **Re-partitioning huge tables is expensive.** Choose the key thoughtfully up front; changing it later means rewriting everything.

## Practice

1. Our `sales` table grows to a billion rows. Pick a partition column, a clustering column, and a bucket/distribution column, and justify each in one sentence.
2. Explain in plain English why `WHERE sale_date BETWEEN '2026-03-01' AND '2026-03-31'` can prune but `WHERE MONTH(sale_date) = 3` often cannot.
3. 70% of sales come from the "West" region. Describe what happens if you partition by region, and propose a better split.
4. Two big tables are joined on `customer_id` constantly. Describe how bucketing both on that key changes how the join executes.

---
**Prev:** [Medallion Architecture](./04-medallion-architecture.md) · **Next:** [Performance at Scale](./06-performance-at-scale.md)
