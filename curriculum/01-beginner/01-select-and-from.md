# 1. SELECT and FROM

<!-- nav -->
Previous: [Tier 0 — Orientation](../00-orientation/README.md). Next: [2. Filtering with WHERE](02-filtering-with-where.md). Exercises: [1. SELECT and FROM](../../exercises/01-beginner/01-select-and-from.md).
<!-- /nav -->

## The idea

Almost every query you write in this course starts the same way: pick
a table, pick some columns. `SELECT` says *what columns you want to
see*. `FROM` says *which table to get them from*. Everything else in
SQL — filtering, sorting, grouping, joining — is extra machinery bolted
onto this basic shape.

```sql
SELECT column_list
FROM table_name;
```

That's genuinely most of it. The rest of Tier 1 is about refining what
`SELECT ... FROM` gives you back.

## Why it matters

You'll be tempted, especially early on, to always type `SELECT *` —
"give me everything" — because it's less to type and you don't have to
remember column names. It's a fine habit while exploring a table for
the first time (you did exactly this in Tier 0). But once you know
what a table contains, naming specific columns is almost always
better:

- **Readability.** `SELECT product_name, unit_price FROM
  bronze_products;` tells a reader exactly what you care about.
  `SELECT *` tells them nothing except "everything, I guess."
- **Performance.** On a real production database, pulling columns you
  don't need wastes work, especially on wide tables or over a network.
  It rarely matters on a small practice database like Oakhaven, but
  the habit is worth building now.
- **Stability.** If someone adds a new column to a table later, code
  that named its columns explicitly keeps working unchanged. Code that
  did `SELECT *` and depended on column *order* or *count* can quietly
  break.

A good default: use `SELECT *` to explore a table you don't know yet,
then switch to naming columns once you know what you actually need.

## Syntax

```sql
SELECT *
FROM table_name;
```

```sql
SELECT column_a, column_b, column_c
FROM table_name;
```

Column names are separated by commas. There's no comma after the last
one, and no comma before `FROM`. SQL keywords (`SELECT`, `FROM`) are
conventionally written in uppercase and table/column names in
lowercase — this is a style convention, not a rule SQLite enforces, but
it's what this course uses throughout, since it makes queries easier
to scan.

## Try it

### Every column, a handful of rows

You already did this in Tier 0, but it's worth repeating as the
baseline to compare against:

```sql
SELECT * FROM bronze_products LIMIT 5;
```

| product_id | product_name | category | subcategory | brand | unit_cost | unit_price | is_discontinued | sku | weight_kg | created_at |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Canyon Hiking Boots | footwear | Hiking Boots | Stonepine Gear | 269.63 | 649.26 | true | FOO-0001 | 24.7 kg | 2019-12-09 |
| 2 | Ridge Jackets | APPAREL | Jackets | Northfell | 231.98 | 348.55 | false | APP-0002 | 5.3 | 2024-01-30 06:07:49 |
| 3 | Trailhead Trekking Pole | CAMPING & HIKING | Trekking Poles | Kestrel Outdoor | 136.25 | 286.86 | n | CAM-0003 | 3.43 kg | 2022-01-18 09:54:16 |
| 4 | Meridian Chalk Bags | Climbing | Chalk Bags | Highmark Supply Co. | 72.33 | 155.94 | false | CLI-0004 | 18.5 kg | 03/04/2024 |
| 5 | Canyon Life Jackets | Water Sports |  | Thistledown Outfitters | 193.92 | 310.93 | N | WAT-0005 | 9.01 | 2023-08-18 |

Eleven columns, most of which you don't care about if all you want is
"what does this product cost."

### Naming just the columns you want

```sql
SELECT product_name, brand, unit_price
FROM bronze_products
LIMIT 5;
```

| product_name | brand | unit_price |
|---|---|---|
| Canyon Hiking Boots | Stonepine Gear | 649.26 |
| Ridge Jackets | Northfell | 348.55 |
| Trailhead Trekking Pole | Kestrel Outdoor | 286.86 |
| Meridian Chalk Bags | Highmark Supply Co. | 155.94 |
| Canyon Life Jackets | Thistledown Outfitters | 310.93 |

Same underlying rows, much easier to read at a glance. Note the column
order in the output follows the order you listed them in `SELECT` —
not their order in the table.

### A different table, a different handful of columns

```sql
SELECT first_name, last_name, department
FROM bronze_employees
LIMIT 5;
```

| first_name | last_name | department |
|---|---|---|
| Alexa | garcia | Management |
| sandra | Thompson | WAREHOUSE |
| Alexandria | CUNNINGHAM | management |
| Laura | williams | Support |
| stephanie | REID | Warehouse |

(You'll deal with that casing inconsistency in `department` — and in
`first_name`/`last_name` — starting in Tier 2. For now, just notice
it's there.)

### Reordering columns

The output order is entirely up to you — it doesn't have to match the
table's column order:

```sql
SELECT brand, product_name
FROM bronze_products
LIMIT 3;
```

| brand | product_name |
|---|---|
| Stonepine Gear | Canyon Hiking Boots |
| Northfell | Ridge Jackets |
| Kestrel Outdoor | Trailhead Trekking Pole |

## Common mistakes

- **Forgetting the semicolon.** Most SQL clients (including
  `sqlite3`) expect a `;` to know a statement is finished. Leaving it
  off at the interactive prompt will just leave you hanging, waiting
  for more input.
- **Misspelling a column name.** `SELECT product_nam FROM
  bronze_products;` will error with something like `no such column:
  product_nam`. SQLite won't guess what you meant.
- **Trailing comma.** `SELECT product_name, brand, FROM
  bronze_products;` — that extra comma before `FROM` is a syntax
  error. Only put commas *between* column names.
- **Assuming `SELECT *` column order is meaningful/stable.** It
  reflects the table's `CREATE TABLE` definition order, which is fine
  to rely on for exploring, but don't build logic that depends on
  position (like "the 3rd column") instead of name.

## Key takeaways

- `SELECT columns FROM table;` is the skeleton of nearly every query
  you'll write.
- `SELECT *` is great for first-look exploration; naming columns
  explicitly is better once you know what you need.
- The order of columns in `SELECT` controls the order in your output —
  independent of the table's actual column order.

---

<!-- nav -->
Previous: [Tier 0 — Orientation](../00-orientation/README.md). Next: [2. Filtering with WHERE](02-filtering-with-where.md). Exercises: [1. SELECT and FROM](../../exercises/01-beginner/01-select-and-from.md).
<!-- /nav -->
