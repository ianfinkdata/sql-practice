# Exercises: What Is a Database?

<!-- nav -->
Curriculum: [1. What Is a Database?](../../curriculum/00-orientation/01-what-is-a-database.md). Previous: [All Exercises](../README.md). Next: [2. What Is SQL?](02-what-is-sql.md).
<!-- /nav -->

No SQL yet — just a few questions to make sure the mental model stuck
before you start writing queries. Jot down your own answers (in your
head, on paper, wherever) before checking the solution notes.

### 1. Spreadsheet vs. database

Name one thing a spreadsheet does reasonably well, and one thing that
gets painful once you have many related spreadsheets (e.g. one for
customers, one for orders, one for products) that a database handles
better.

<details>
<summary>Show solution</summary>

There's no single right answer, but a solid one: spreadsheets are
great for quick, small, visual, single-table data — you can eyeball a
few hundred rows and see patterns immediately. They get painful once
you need to reliably cross-reference *multiple* related sheets (which
customer bought which product on which order?) at any real volume —
that's manual, slow, and error-prone by hand, whereas a database can
answer that kind of cross-table question precisely and instantly via
SQL.

</details>

### 2. Rows and columns

In the Oakhaven database, `bronze_products` is a table with columns
including `product_name`, `category`, and `unit_price`. If Oakhaven
starts selling a new product tomorrow, does that create a new **row**
or a new **column** in `bronze_products`? What about if Oakhaven
decides it wants to start tracking each product's *weight* — is that a
new row or a new column?

<details>
<summary>Show solution</summary>

A new product is a new **row** — one more record with the same set of
existing columns. Tracking a new attribute like weight for every
product is a new **column** — every existing row would need a value
(or NULL) in that column. (In fact, `bronze_products` really does have
a `weight_kg` column — you'll meet it directly in later modules.)

</details>

### 3. Why not just one big table?

Oakhaven keeps customers, products, employees, and sales in four
separate tables instead of cramming everything into one giant table
(e.g. repeating the customer's full name and email on every single
sales row). Take a guess at why that might be a bad idea, even before
you know any SQL.

<details>
<summary>Show solution</summary>

A few reasons worth having in mind, even loosely: it would repeat the
same customer info (name, email, etc.) on every one of that customer's
sales rows — wasteful, and if the customer's email ever needs
correcting, you'd have to fix it in *every* row instead of one. It
also mixes concerns that don't belong together (a "product" fact
shouldn't live inside a "sale" record). Splitting related data into
separate tables and then *joining* them back together only when needed
is a core relational database idea — you'll get hands-on with joins in
a later tier.

</details>

---

<!-- nav -->
Curriculum: [1. What Is a Database?](../../curriculum/00-orientation/01-what-is-a-database.md). Previous: [All Exercises](../README.md). Next: [2. What Is SQL?](02-what-is-sql.md).
<!-- /nav -->
