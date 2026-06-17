# SELECT and FROM: Choosing Columns and a Table

> After this module you'll be able to pull specific columns out of a table — and rename them for readability.

## The idea

Every question you ask a database starts the same way: "Which columns do I want, and which table do they live in?"

Think of a table as a giant spreadsheet. `SELECT` is you pointing at the column headers you care about — "give me the name and the email, please." `FROM` is you saying which spreadsheet to look in. That's the whole core of reading data.

**SELECT** is the keyword that lists the columns you want back. **FROM** is the keyword that names the table those columns come from. Almost every query you ever write will have both.

If you want *every* column, you don't have to list them all by hand. You write an asterisk `*`, which is shorthand for "all columns." It's handy for a quick look, but in real work you usually name the exact columns you need — it's clearer and faster.

Sometimes a column name is technical or ugly, and you'd like the results labeled with something friendlier. You can give a column a temporary nickname using the keyword **AS**. That nickname is called an **alias** — a display name that exists just for this one query. It doesn't change the real column; it only changes the header on your results.

## Why it matters

This is the bread and butter of working with data. Pulling a customer list, exporting email addresses, building a report — they all begin with choosing columns from a table.

Naming columns explicitly (instead of always using `*`) also makes your intent obvious to anyone reading your query later, including future you. And aliases make raw results presentable, which matters the moment you hand them to someone else.

## See it

Grab two specific columns from the customers table:

```sql
SELECT customer_name, email
FROM customers;
```

Grab everything, for a quick peek:

```sql
SELECT *
FROM customers;
```

Rename a column in the output using an alias:

```sql
SELECT customer_name AS name,
       email AS contact_email
FROM customers;
```

Now the results come back with headers `name` and `contact_email` instead of the original column names. The table itself is untouched.

> **Dialect note:** The word `AS` is optional in most databases — `customer_name name` works too — but writing `AS` is clearer, so we'll always use it. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Spelling counts.** If you type `custmer_name`, the database won't guess — it'll error. Column and table names must match exactly.
- **Commas between columns, not after the last one.** `SELECT a, b, c` is right; a trailing comma before `FROM` is a common error.
- **`SELECT *` is convenient but lazy.** It returns columns you may not need and makes queries harder to read. Prefer naming columns in real work.
- **An alias is just a label.** It doesn't rename the actual column in the table — only the results of this one query.

## Practice

1. Write a query that returns just the `region` and `signup_date` columns for all customers.
2. Show every column of the `products` table.
3. Return `product_name` and `unit_price` from `products`, but label `unit_price` as `price` in the output.
4. Pull the `rep_name` and `hire_date` from `sales_rep`, giving `hire_date` the alias `started_on`.

---
**Prev:** [The Relational Model](01-relational-model.md) · **Next:** [WHERE: Filtering Rows](03-where.md)
