# Performance at Scale: Tuning the Big Machine

> At a billion rows, the wins come from helping the engine plan well, read less, and split work evenly.

## The idea

Tuning a small query is like tuning a bicycle — adjust the brakes, oil the chain, done. Tuning a system that processes billions of rows across dozens of machines is like tuning a freight train. The instincts carry over, but the stakes and the failure modes are different. A bad choice here doesn't slow you by milliseconds; it slows you by hours, or it falls over entirely.

The good news: a handful of ideas explain almost every big-system performance problem you'll meet. Master these and you'll diagnose slow queries the way a doctor reads symptoms.

## The core ideas, one at a time

**Statistics are the engine's map of your data.** Before running a query, the engine *plans* it — and to plan well it needs to know roughly how many rows match each filter, how values are distributed, how many distinct customers exist. These estimates come from **statistics** the database gathers about your tables. When stats are stale or missing, the planner guesses badly: it might pick the wrong join order, the wrong index, or the wrong join strategy. *Lesson: after big data loads, refresh statistics. A planner with a current map makes good decisions; a planner guessing blindly makes terrible ones.*

**Partition pruning — read less.** You met this last module: filter on the partition column so the engine skips partitions it doesn't need. It bears repeating because it's the highest-leverage tuning move at scale. The fastest way to process data is to never touch it.

**Predicate pushdown — filter early, filter low.** A *predicate* is just a filter condition. "Pushdown" means pushing that filter as close to the data as possible — ideally into the storage layer itself, so rows are discarded *before* they're ever read into memory or shipped across the network. Modern columnar formats (Parquet, Delta) store min/max stats per chunk, so a `WHERE amount > 1000` can skip entire chunks whose maximum is below 1000. You enable pushdown by writing simple, direct filters on raw columns — the same habit that enables pruning.

**Broadcast vs. shuffle joins — how big joins actually run.** This is the heart of distributed query tuning. When you join two tables spread across many machines, the engine has two strategies:

- A **broadcast join** copies the *small* table in full to every machine, so each one joins its slice of the big table against the local copy. No big data moves across the network. Fast — *when one side is genuinely small.*
- A **shuffle join** re-distributes *both* tables across the network so matching keys land on the same machine, then joins locally. Necessary when both sides are large, but expensive — moving billions of rows over the network is the slowest thing a cluster does.

The classic win: a huge fact table joined to a small dimension should **broadcast** the dimension. If the engine doesn't realize the dimension is small (stale stats again!), it may shuffle both — and a two-second query becomes a twenty-minute one. *Lesson: keep dimensions small and stats fresh so the planner chooses broadcast.*

**Skew — the one slow worker.** From last module: if work splits unevenly, the most overloaded worker sets the pace and the rest sit idle. At scale, a single hot key (one giant customer, a flood of `NULL`s landing in the same bucket) can stall an entire job. Watch for the task that runs 50× longer than its siblings — that's skew, and it usually means a lopsided join or grouping key.

**The small-files problem.** In file-based lakehouses, data lands as files. Thousands of *tiny* files are a quiet disaster: the engine pays a fixed cost to open, read metadata for, and close *each* file, so ten thousand 1 KB files are dramatically slower than ten 1 MB files holding the same data. Streaming ingestion is the usual culprit. The cure is **compaction** — periodically merging small files into larger ones (Delta's `OPTIMIZE`, for instance).

**Caching and materialization — trade storage for speed.** Sometimes the smartest tuning is to *not recompute*. **Caching** keeps a query's result in fast memory so a repeat runs instantly. **Materialization** goes further: you persist the result of an expensive query (a materialized view, a gold table) so every reader gets the pre-computed answer. The trade is always the same: you spend storage and accept some *staleness* — the materialized copy is only as fresh as its last refresh — in exchange for speed. Materialize what's expensive and read often; leave cheap or rarely-read queries to run live.

## See it: nudging toward a broadcast join

A giant fact joined to a tiny dimension. The aim is for the small side to broadcast.

```sql
-- Big sales fact, tiny sales_rep dimension.
-- Filter early (pushdown), join the small side (broadcast candidate).
SELECT r.rep_name, SUM(s.amount) AS total
FROM sales s
JOIN sales_rep r ON r.rep_id = s.rep_id
WHERE s.sale_date >= DATE '2026-01-01'   -- prunes + pushes down
GROUP BY r.rep_name;
```

`sales_rep` has a few hundred rows; `sales` has billions. With fresh statistics, the planner sees this and broadcasts `sales_rep` to every worker — no shuffle of the giant table. The date filter prunes partitions and pushes down into storage. Two small habits, a massive difference.

> **Dialect note:** stats refresh commands (`ANALYZE`, `DBMS_STATS`, `ANALYZE TABLE ... COMPUTE STATISTICS`), join hints, and compaction commands differ by engine — see the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Stale statistics cause most "mysteriously slow" queries.** Refresh stats after big loads before blaming anything else.
- **Functions on filter columns block both pruning and pushdown.** Keep `WHERE` conditions on raw columns.
- **A shuffle where a broadcast belonged** is the classic scale-up failure — check that the planner knows your dimension is small.
- **Skew hides in the average.** A job's *average* task time looks fine while one task runs for hours. Look at the slowest task, not the mean.
- **Over-materializing creates staleness debt.** Every materialized table is another thing that can silently go out of date.

## Practice

1. A nightly report joining the billion-row `sales` to the tiny `products` table suddenly runs 30× slower. List three things you'd check, in order.
2. Explain, in plain English, the difference between a broadcast and a shuffle join, and the one condition that decides which is right.
3. A streaming pipeline writes a new file every few seconds and queries have gotten sluggish. Diagnose the likely cause and the fix.
4. You're asked to speed up a dashboard that runs the same expensive aggregation every page load. Propose a materialization strategy and name the trade-off you're accepting.

---
**Prev:** [Partitioning & Distribution](./05-partitioning-distribution.md) · **Next:** [Anti-Patterns](./07-anti-patterns.md)
