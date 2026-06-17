# WHERE: Filtering Rows

> After this module you'll be able to keep only the rows that match a condition — and quote text correctly.

## The idea

So far you've been choosing *columns*. `WHERE` lets you choose *rows*.

Picture a bouncer at a door holding a guest list. Everyone wants in, but only people who match the rule get through. **WHERE** is that bouncer: it checks each row against a condition and lets through only the rows where the condition is true.

The condition is usually a simple comparison. You pick a column, a comparison operator, and a value to compare against. A **comparison operator** is just a symbol that asks a yes/no question about two values:

- `=` equals
- `<>` not equal (some databases also accept `!=`)
- `<` less than
- `>` greater than
- `<=` less than or equal to
- `>=` greater than or equal to

The row passes if the comparison is true, and it's dropped if it's false. That's the entire mechanism.

One crucial detail: **numbers and text are quoted differently.** A number is written bare, like `500`. A piece of text (called a **string**) must be wrapped in single quotes, like `'West'`. Forgetting the quotes around text is the single most common beginner mistake here. And it's single quotes — not double quotes, which mean something different in many databases.

## Why it matters

You almost never want every row. You want the sales over $1,000, the customers in one region, the reps hired this year. `WHERE` is how you narrow a huge table down to the handful of rows that actually answer your question. It's one of the most-used pieces of SQL there is.

## See it

Keep only the sales worth more than 1000 (a number — no quotes):

```sql
SELECT sale_id, amount
FROM sales
WHERE amount > 1000;
```

Keep only the customers in the West region (text — single quotes):

```sql
SELECT customer_name, region
FROM customers
WHERE region = 'West';
```

Keep everyone *not* in the West region:

```sql
SELECT customer_name, region
FROM customers
WHERE region <> 'West';
```

`WHERE` always comes after `FROM`. The database first knows which table to look in, then filters its rows.

## Watch out

- **Quote your text, leave numbers bare.** `region = 'West'` is right; `region = West` makes the database look for a column called `West` and fail.
- **Use single quotes for strings.** `'West'`, not `"West"`. Double quotes often mean "column name," not text.
- **`=` compares; it doesn't assign.** In SQL, `=` asks "are these equal?" There's no separate `==`.
- **Text comparisons can be case-sensitive.** Depending on the database, `'west'` may not match `'West'`. When in doubt, match the exact casing in your data.
- **WHERE filters rows, SELECT chooses columns.** They do different jobs; you'll often use both together.

## Practice

1. Write a query for all customers whose `region` is `'East'`, returning their name and region.
2. Find every sale where the `amount` is at least 250. Return the sale id and amount.
3. List products whose `unit_price` is less than 20. Return the product name and price.
4. Return the names of all sales reps whose `rep_name` is not `'Jordan Pike'`.

---
**Prev:** [SELECT and FROM](02-select-from.md) · **Next:** [ORDER BY and LIMIT](04-order-by-limit.md)
