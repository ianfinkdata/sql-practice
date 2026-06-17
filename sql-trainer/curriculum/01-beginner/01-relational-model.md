# The Relational Model in Plain English

> After this module you'll understand how data is organized into tables, rows, and columns — and why that structure makes questions easy to answer.

## The idea

Imagine a well-organized filing cabinet. Each **drawer** holds one kind of thing: one drawer for customers, another for sales, another for sales reps. In databases, each of these drawers is called a **table** — a collection of information about one type of thing.

Inside a drawer, every record is on its own index card. One card per customer, one card per sale. In a table, each of these cards is called a **row** (sometimes "record"). A row is one single item: one customer, one sale.

Every index card has the same blanks to fill in: name, region, email, and so on. Those blanks are called **columns** (sometimes "fields"). A column is one piece of information that every row shares. The `customers` table has a `customer_name` column, a `region` column, an `email` column, and so on. Every customer card fills in those same blanks.

So the whole picture is simple:

- A **table** is a grid about one kind of thing.
- A **row** is one entry in that grid (one thing).
- A **column** is one attribute that every row has.

Now, one more piece. If two customers are both named "Sam Lee," how do you tell their cards apart? You give every card a unique ID number. That unique label is called a **primary key** — a column whose value is different for every single row, so it can never be confused with another. In our `customers` table that's `customer_id`. No two customers share one.

Why does any of this matter? Because when data is shaped into neat, consistent tables with unique keys, you can ask precise questions and get exact answers — "show me every customer in the West region" — without digging through a messy pile of notes.

## Why it matters

Almost every app you use sits on top of tables like these. Your bank statement is rows in a transactions table. Your music playlist is rows in a songs table. When you understand the relational model, you stop seeing data as a confusing blob and start seeing it as organized grids you can query.

This is the foundation for everything else in this tier. Once "table, row, column, primary key" feels obvious, the actual SQL commands are just ways of saying "give me these rows and these columns."

Here are the four tables we'll use throughout this whole course. Get familiar with them now — you'll see them in every example.

- `customers(customer_id, customer_name, region, signup_date, email)`
- `sales(sale_id, sale_date, customer_id, rep_id, amount)`
- `sales_rep(rep_id, rep_name, commission_rate, hire_date)`
- `products(product_id, product_name, category, unit_price)`

Notice that each table has its own primary key: `customer_id`, `sale_id`, `rep_id`, `product_id`. Each one uniquely labels a row in its table.

## See it

You don't need much code yet. But here's the smallest possible taste — a way to peek at every row and column in a table. The asterisk `*` just means "all columns."

```sql
SELECT *
FROM customers;
```

Read it as a plain sentence: "Show me everything from the customers table." We'll unpack `SELECT` and `FROM` properly in the next module. For now, just notice that you name the table you want, and you get its rows back.

## Watch out

- **A table is about one kind of thing.** Customers go in `customers`, sales go in `sales`. Mixing types into one table is a common early mistake.
- **A row is one item, not many.** Don't picture a row as "all the sales" — it's one single sale.
- **A primary key must be unique.** `customer_id` can never repeat. Two rows with the same key would be impossible to tell apart.
- **Don't confuse rows and columns.** Rows run across (one record); columns run down (one attribute shared by all records).

## Practice

1. In plain words, describe what one row in the `sales` table represents. What does each column tell you about it?
2. List the four tables in this course and name the primary key of each.
3. The `sales` table has a `customer_id` column even though there's also a `customers` table. Why might it help to repeat that ID here? (Just reason it out — we'll cover the answer later.)
4. Think of something in your own life (a contacts list, a recipe box) and describe it as a table: what's one row, and what are the columns?

---
**Prev:** [Orientation](../00-orientation/) · **Next:** [SELECT and FROM](02-select-from.md)
