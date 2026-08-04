# 1. What Is a Database?


<!-- nav -->
Previous: [sql-practice](../../README.md). Next: [2. What Is SQL?](02-what-is-sql.md).
<!-- /nav -->

## The idea

A database is just an organized place to store information so that you
can find it again reliably, even when there's a lot of it.

You already know a messier version of this problem. Imagine trying to
run an outdoor-gear store using a stack of spreadsheets: one for
customers, one for products, one for orders, one for employees. Every
time someone places an order, you'd have to flip between sheets to
look up the customer's info, check the product's price, and note which
employee helped them. Now imagine doing that thousands of times a day,
without ever mistyping a customer ID or losing track of which
spreadsheet is the current one.

A database solves this by keeping related information in **tables** —
think of a table as one very disciplined spreadsheet — and giving you
a language (SQL) to ask precise questions across all of them at once:
"which customers in Colorado bought a tent in the last 90 days?" A
spreadsheet can technically hold that answer somewhere in its cells.
A database can *compute* it for you, correctly, in a fraction of a
second, no matter how big the pile of data gets.

## Tables, rows, and columns

A table has:

- **Columns** — the fields every record shares. A `products` table
  might have columns for `product_name`, `category`, `unit_price`.
  Columns are fixed: every row has the same set of columns.
- **Rows** — one individual record. One row in `products` is one
  specific product, like a pair of hiking boots.

So a table is a grid: columns going across, rows going down. That's
it — nearly everything else in SQL is about selecting, filtering,
combining, and summarizing grids like this.

A **database** is a collection of tables like this, usually related to
each other. Our practice database, Oakhaven, has separate tables for
customers, products, employees, and sales — and part of what makes SQL
powerful is being able to ask questions that span more than one table
at once (you'll get to that in a later tier — for now, one table at a
time is plenty).

## Why SQL exists

"SQL" stands for **Structured Query Language**. It was designed in the
1970s for exactly one job: letting a person describe *what* data they
want, without having to write a program describing *how* to go get it.

That distinction matters. You don't tell a database "loop through
every row, check if the category column equals 'Footwear', and if so
add it to a list." You just say:

```sql
SELECT * FROM bronze_products WHERE category = 'Footwear';
```

You describe the *result* you want. The database software figures out
the fastest way to actually produce it. That's what makes SQL readable
even to people who've never written a line of any other programming
language — and it's why, decades later, it's still the standard way to
talk to structured data almost everywhere: banks, hospitals, airlines,
and — in this course — a small fictional outdoor-gear retailer called
Oakhaven.

## Key takeaways

- A database organizes information into **tables**: grids of
  **columns** (fields) and **rows** (records).
- Databases let you ask precise, fast questions across large amounts
  of data — something spreadsheets get unwieldy at.
- **SQL** is the language for asking those questions. You describe
  *what* you want; the database figures out *how* to get it.
- The rest of this course is about learning to read and write SQL
  against one real (if fictional, if intentionally messy) database:
  Oakhaven.

---

<!-- nav -->
Previous: [sql-practice](../../README.md). Next: [2. What Is SQL?](02-what-is-sql.md).
<!-- /nav -->
