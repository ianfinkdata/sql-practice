# Medallion Architecture: Refining Data in Layers

> Move data through bronze, silver, and gold — raw to clean to ready-to-use.

## The idea

Think about how an ore becomes a wedding ring. You don't pull gold from the ground ready to wear. It arrives as raw rock. You crush and wash it into refined metal. Only then do you shape it into something a person actually wants. Three stages, each adding value, each building on the one before.

Data works the same way, and the **medallion architecture** names those stages after medals: **bronze, silver, gold.**

**Bronze — the raw landing zone.** Data arrives exactly as the source sent it: messy, duplicated, full of odd nulls and inconsistent date formats. You change *nothing*. You just capture it, append-only, with a timestamp of when it landed. Bronze is your system of record — if anything downstream goes wrong, the original is always here, untouched, to replay from.

**Silver — the cleaned, conformed layer.** Now you refine. You deduplicate, fix types, standardize date formats, trim whitespace, reject or quarantine bad rows, and join related sources together. Silver is trustworthy, query-able data that faithfully represents the business entities — customers are real customers, amounts are real numbers. It's the "refined metal": not yet a finished product, but clean and dependable.

**Gold — the business-ready layer.** Here you shape data for *consumption*: the star schemas, the aggregated tables, the metrics a dashboard reads directly. Gold answers business questions fast. "Monthly revenue by region" lives here, pre-computed and pre-joined, so the dashboard never has to grind through raw data. This is the ring.

Data flows one way: bronze → silver → gold. Each layer reads from the one before and never reaches backward.

```
   sources --> [ BRONZE ] --> [ SILVER ] --> [ GOLD ] --> dashboards
                raw           cleaned        business-ready
```

## Why it matters

Layering buys you something precious: **separation of concerns.** Each stage has one job. When ingestion breaks, you look at bronze. When numbers look wrong, you look at silver's cleaning rules. When a dashboard is confusing, you look at gold's shaping. Problems stay local instead of tangling into one giant unmaintainable query.

It also buys **replayability.** Because bronze keeps the raw truth forever, you can change a cleaning rule and rebuild silver and gold from scratch — without ever re-fetching from the source, which may be slow, expensive, or simply gone. And it buys **trust through transparency**: anyone can trace a gold number back through silver to the exact bronze row it came from.

## See it: you've already built this

Here's the reassuring part — you already know this pattern. You just called it something else.

Remember building **views** that wrapped a messy table in a clean interface? Remember a *second* view that joined and aggregated the first into a report? That layering — raw table, cleaning view, reporting view — *is* a medallion architecture in miniature. Medallion just gives it names, discipline, and scale.

Mapped to tools you've already used:

| Layer | What you do | Tools you know |
|---|---|---|
| **Bronze** | Land raw data, append-only, untouched | `CREATE TABLE`, bulk load, a `loaded_at` timestamp |
| **Silver** | Clean, dedupe, conform types, join sources | `VIEW`s, `CTE`s, `CAST`, `ROW_NUMBER()` to dedupe, filters |
| **Gold** | Aggregate, build star schemas, pre-join metrics | `GROUP BY`, dimensional models, materialized views |

A silver cleaning step you could write today, deduping bronze with a window function you learned two tiers ago:

```sql
-- SILVER: keep the latest record per customer from raw bronze
CREATE VIEW silver_customers AS
SELECT customer_id, customer_name, region, email, signup_date
FROM (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY customer_id
           ORDER BY loaded_at DESC
         ) AS rn
  FROM bronze_customers
) deduped
WHERE rn = 1;
```

```sql
-- GOLD: the business-ready metric a dashboard reads directly
CREATE VIEW gold_monthly_revenue AS
SELECT c.region,
       DATE_TRUNC('month', s.sale_date) AS month,
       SUM(s.amount) AS revenue
FROM silver_sales s
JOIN silver_customers c ON c.customer_id = s.customer_id
GROUP BY c.region, DATE_TRUNC('month', s.sale_date);
```

Gold reads from silver, silver reads from bronze, bronze holds the raw truth. Same skills you already have — now arranged with intent.

## The lakehouse context

This pattern became famous in the **lakehouse** world, especially **Databricks** with the **Delta Lake** format. A "lakehouse" blends the cheap, flexible storage of a data *lake* (just files in cloud storage) with the reliability and structure of a data *ware*house (transactions, schemas, fast queries). Medallion is the standard way to bring order to that vast, file-based storage: bronze, silver, and gold each become Delta tables, and the layers turn a sprawling lake into something you can actually trust and govern.

You don't need Databricks to use medallion — it works just as well with plain views in Postgres, as the example above shows. The *idea* is portable; the lakehouse is just where it got its name.

> **Dialect note:** The layering concept is engine-agnostic, but the table format (Delta, Iceberg, Hudi) and refresh mechanics differ — see the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Never clean data in bronze.** The instant you "fix" raw data, you've lost your ability to replay. Bronze is read-only history.
- **Don't let business logic leak into silver.** Silver makes data *correct*; gold makes it *useful*. Metric definitions belong in gold.
- **Don't skip silver and clean inside gold queries.** That scatters the same cleaning logic across every report and guarantees they'll drift apart.
- **Layers flow one way.** Gold reading from bronze directly is a smell — it bypasses every quality check silver provides.
- **Name things by layer.** `bronze_`, `silver_`, `gold_` prefixes save future-you hours of confusion.

## Practice

1. Take our four sample tables and describe what lands in bronze, what cleaning happens in silver, and what gold tables a sales dashboard would need.
2. You discover signup dates arrive in three different formats from three sources. Which layer fixes this, and why not the others?
3. Sketch (in views) a silver step that rejects sales with a negative amount into a quarantine table while passing the good rows through.
4. A teammate proposes computing "customer lifetime value" inside a silver view. Argue where that logic actually belongs and why.

---
**Prev:** [Slowly Changing Dimensions](./03-slowly-changing-dimensions.md) · **Next:** [Partitioning & Distribution](./05-partitioning-distribution.md)
