# DISTINCT and Expressions: Unique Values and Computed Columns

> After this module you'll be able to list unique values and create new columns by calculating or combining existing ones.

## The idea

### Unique values with DISTINCT

Suppose your `customers` table has 500 rows, but customers only live in four regions. If you just select the `region` column, you'll get the word "West" hundreds of times. Usually you want the *distinct* list: West, East, North, South — each once.

**DISTINCT** does exactly that. Place it right after `SELECT`, and the database removes duplicate rows from the result, leaving one of each. Think of it like pouring a bag of mixed marbles onto a table and keeping just one marble of each color.

### Computed columns

So far every column you've selected already existed in the table. But you can also *make* new columns on the fly by doing math or combining text. A column you calculate rather than store is called an **expression** (or "computed column").

For math, the usual symbols work: `+`, `-`, `*` (multiply), `/` (divide). If you have `unit_price` and you want to know the price with a 10% markup, you can compute `unit_price * 1.1` right in your `SELECT`. The table doesn't change — you're just showing a calculated value.

### Joining text together

You can also glue strings together — for example, combining a region and a name into one label. Sticking strings end to end is called **concatenation**. Give the result a friendly alias (using `AS`, from module 2) so the new column has a readable header.

## Why it matters

`DISTINCT` answers "what are the possible values?" — the regions we sell to, the product categories we carry. It's how you take stock of your data.

Computed columns let the database do arithmetic for you instead of exporting to a spreadsheet: totals, markups, discounts, formatted labels. Doing it in the query keeps everything in one place and always up to date.

## See it

List each region once:

```sql
SELECT DISTINCT region
FROM customers;
```

Compute a marked-up price as a new column:

```sql
SELECT product_name,
       unit_price,
       unit_price * 1.1 AS price_with_markup
FROM products;
```

Combine text into one label (standard ANSI SQL uses `||`):

```sql
SELECT customer_name || ' (' || region || ')' AS customer_label
FROM customers;
```

That last query produces values like `Sam Lee (West)` in a single column called `customer_label`.

> **Dialect note:** Standard SQL and PostgreSQL/SQLite/Oracle use `||` to concatenate. MySQL uses the `CONCAT(...)` function instead — `CONCAT(customer_name, ' (', region, ')')` — because by default `||` means "or" there. SQL Server uses `+` for strings (or `CONCAT`). See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **`DISTINCT` applies to the whole row you select, not one column.** `SELECT DISTINCT region, customer_name` gives unique *combinations*, which is rarely "one row per region."
- **Don't divide by zero.** An expression like `amount / something` will error or misbehave if `something` is 0.
- **Concatenation needs the right operator for your database.** `||`, `CONCAT`, or `+` — pick the one your database understands (see the dialect note).
- **Name your computed columns.** Without an alias, the header for an expression looks messy. Add `AS something` to keep results readable.

## Practice

1. List every distinct `category` in the `products` table.
2. Show each product's name, its `unit_price`, and a column that computes a 15% discount price (`unit_price * 0.85`), aliased as `sale_price`.
3. List the distinct regions customers come from, sorted alphabetically.
4. Create a single label column combining `rep_name` and `commission_rate` from `sales_rep`, with a readable alias. (Use whichever concatenation style you like; note which database it assumes.)

---
**Prev:** [ORDER BY and LIMIT](04-order-by-limit.md) · **Next:** [Operators and Logic](06-operators-logic.md)
