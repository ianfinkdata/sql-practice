# 4. Limiting with LIMIT (and OFFSET)

## The idea

You've already used `LIMIT` in every module so far, almost in
passing — it's time to make it explicit. `LIMIT` caps how many rows a
query returns. `OFFSET`, used alongside it, skips a number of rows
before starting to return results. Together they let you grab a
specific "page" of results out of a larger set.

```sql
SELECT columns FROM table_name
ORDER BY column_name
LIMIT n;
```

## Why it matters

Two big reasons to reach for `LIMIT`:

1. **Exploration.** When you're getting to know a table, you rarely
   want all 12,000 rows dumped to your screen — `LIMIT 5` or `LIMIT
   10` gives you a manageable taste. You've been doing exactly this
   since Tier 0.
2. **Real questions that only want a "top N."** "What are our 5
   best-selling products?" "Who are the 3 most senior employees?"
   These are naturally `ORDER BY ... LIMIT n` questions — sort by the
   thing that matters, then take only as many as you need.

`OFFSET` builds on that for pagination — "give me the next page of
results" — the same technique that powers "page 2" of search results
or a paginated report.

## Syntax

```sql
SELECT columns FROM table_name
ORDER BY column_name
LIMIT n;                 -- first n rows

SELECT columns FROM table_name
ORDER BY column_name
LIMIT n OFFSET m;         -- skip the first m rows, then take the next n
```

`LIMIT` without `ORDER BY` will still cap your row count, but *which*
rows you get is not guaranteed to be meaningful or stable — always
pair `LIMIT`/`OFFSET` with `ORDER BY` when the specific rows matter
(which is almost always).

## Try it

### The top 5

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price DESC
LIMIT 5;
```

| product_name | unit_price |
|---|---|
| Highline Backpacks | 812.71 |
| Foothill Electrolyte Mixes | 782.32 |
| Highline Paddle | 696.3 |
| Canyon Backpacks | 687.96 |
| Meridian Chalk Bags | 669.02 |

### The next 5 — "page 2" via OFFSET

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price DESC
LIMIT 5 OFFSET 5;
```

| product_name | unit_price |
|---|---|
| Canyon Hiking Boots | 649.26 |
| Ridge Paddles | 645.99 |
| Highline Harnesse | 642.05 |
| Alpine Harnesse | 640.45 |
| Switchback Carabiner | 618.29 |

Same sort order as before, but this time skipping the top 5 and
starting from rank 6. Products #6–10 by price, in other words.

### Page 3

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price DESC
LIMIT 5 OFFSET 10;
```

| product_name | unit_price |
|---|---|
| Cascade Carabiners | 584.4 |
| Highline Rain Shells | 567.3 |
| Canyon Energy Bars | 565.0 |
| Backcountry Climbing Shoes | 563.18 |
| Ironpeak Hiking Boot | 553.01 |

Notice the pattern: `OFFSET 0` (page 1), `OFFSET 5` (page 2), `OFFSET
10` (page 3) — each page's offset is `page_size * (page_number - 1)`.

### "The 2nd cheapest" — LIMIT and OFFSET together for a single row

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price ASC
LIMIT 1 OFFSET 1;
```

| product_name | unit_price |
|---|---|
| Canyon Hats | 21.03 |

`LIMIT 1` alone would give you the single cheapest product (Cascade
Hiking Boots, from module 3). Adding `OFFSET 1` skips past that one
and gives you the next — the 2nd cheapest.

## Common mistakes

- **Using LIMIT without ORDER BY when you care which rows you get.**
  `SELECT * FROM bronze_products LIMIT 5;` will return *some* 5 rows,
  but there's no guarantee they're a meaningful 5 (e.g. "the 5
  cheapest") unless you sort first.
- **Off-by-one errors with OFFSET.** `OFFSET 5` skips the first 5 rows
  and starts at the 6th — it's easy to accidentally write `OFFSET 6`
  and skip one row too many, or forget you need `OFFSET 0` (or no
  `OFFSET` at all) for page 1.
- **Forgetting LIMIT entirely on a big table.** `SELECT * FROM
  bronze_sales;` with no `LIMIT` dumps all 12,000 rows to your
  terminal — harmless but usually not what you meant while exploring.

## Key takeaways

- `LIMIT n` caps the number of rows returned.
- `OFFSET m` skips the first `m` rows before applying the limit — the
  combination gives you pagination.
- Always pair `LIMIT`/`OFFSET` with `ORDER BY` when *which* rows you
  get actually matters.
