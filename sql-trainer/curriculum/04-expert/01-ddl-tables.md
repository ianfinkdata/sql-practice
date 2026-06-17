# Creating Tables: DDL and Constraints

> Design the shape of your data: define tables, pick the right types, and set the rules that keep your data honest.

## The idea

Up to now you've been a guest in someone else's house — querying tables other people built. In this tier you become the architect. The first thing an architect does is draw the rooms. In a database, the "rooms" are **tables**, and the language for drawing them is **DDL** — Data Definition Language.

Defining a table is like designing a paper form. Every column is a blank on the form, and for each blank you decide two things: what *kind* of answer goes there, and what *rules* the answer must follow.

The "what kind" part is the **data type**. Think of it as the shape of the blank. A blank for an age is a small box for digits. A blank for a name is a long line for letters. A blank for a birthday is three little boxes: month, day, year. Databases have the same idea — they just use type names:

- **Numbers** — `INTEGER` for whole numbers (counts, ids), `DECIMAL(p, s)` for exact money (dollars and cents), `FLOAT`/`REAL` for approximate scientific values.
- **Text** — `VARCHAR(n)` for variable-length text up to a limit, `TEXT` for long free-form text, `CHAR(n)` for fixed-length codes.
- **Dates and times** — `DATE` for a calendar day, `TIMESTAMP` for a precise moment, `TIME` for a clock reading.
- **True/false** — `BOOLEAN`.

The "rules" part is the **constraint**. A constraint is a promise the database enforces for you, so bad data simply can't get in:

- **NOT NULL** — this blank may not be left empty.
- **DEFAULT** — if left empty, fill in this value automatically.
- **PRIMARY KEY** — this column uniquely identifies each row, like a passport number. It must be unique *and* never empty.
- **UNIQUE** — no two rows may share this value (e.g., two customers can't have the same email).
- **FOREIGN KEY** — this column must point to a real row in another table, like a sale that must belong to a customer who actually exists.
- **CHECK** — a custom rule, like "amount must be greater than zero."

You won't always get the design right the first time. That's what **ALTER TABLE** is for — it lets you add a column, drop one, or add a constraint to a table that already exists.

## Why it matters

Constraints are cheaper than cleanup. It is far easier to *prevent* a negative sale amount or an orphaned record than to hunt one down months later after it has corrupted a report. A well-designed table refuses to hold nonsense, which means every query you write on top of it can trust the data underneath. Good schema design is the quiet foundation that everything else in this tier stands on.

## See it

Create the customers table, with types and constraints chosen deliberately:

```sql
CREATE TABLE customers (
    customer_id   INTEGER      PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    region        VARCHAR(20),
    signup_date   DATE         DEFAULT CURRENT_DATE,
    email         VARCHAR(255) UNIQUE
);
```

Now the sales table, which *references* customers and reps so every sale belongs to real people, plus a rule that money can't be negative:

```sql
CREATE TABLE sales (
    sale_id     INTEGER       PRIMARY KEY,
    sale_date   DATE          NOT NULL,
    customer_id INTEGER       REFERENCES customers(customer_id),
    rep_id      INTEGER       REFERENCES sales_rep(rep_id),
    amount      DECIMAL(10,2) NOT NULL CHECK (amount >= 0)
);
```

Changed your mind later? Add a column and a constraint to an existing table:

```sql
ALTER TABLE customers ADD COLUMN phone VARCHAR(30);

ALTER TABLE sales ADD CONSTRAINT chk_amount CHECK (amount < 1000000);
```

> **Dialect note:** Auto-incrementing ids differ a lot — PostgreSQL uses `GENERATED ALWAYS AS IDENTITY` or `SERIAL`, MySQL uses `AUTO_INCREMENT`, SQL Server uses `IDENTITY`. Some engines (older MySQL) ignore `CHECK` constraints. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Don't store money in FLOAT.** Floating point can't represent `0.10` exactly, so totals drift. Use `DECIMAL`/`NUMERIC` for currency.
- **Pick a real primary key.** Every table should have one. It's how rows get found, joined, and updated efficiently.
- **Order matters for foreign keys.** The table you reference must exist first. Create `customers` before `sales`.
- **`VARCHAR(n)` is a maximum, not a reservation.** Pick a generous limit; running out later means an `ALTER`.
- **Adding a `NOT NULL` column to a populated table needs a default,** or the database won't know what to put in the existing rows.

## Practice

1. Write a `CREATE TABLE` statement for `sales_rep` with a primary key, a non-null name, a `commission_rate` that must be between 0 and 1, and a hire date that defaults to today.
2. Design a `products` table where `category` may be empty but `product_name` and `unit_price` may not, and price must be positive.
3. You realize customers need a loyalty tier. Write the `ALTER TABLE` to add a `loyalty_tier` column defaulting to `'standard'`.
4. Explain in plain English why you'd choose `DECIMAL(10,2)` over `FLOAT` for the `amount` column, and `DATE` over `VARCHAR` for `sale_date`.

---
**Prev:** [Tier 3: Advanced](../03-advanced/) · **Next:** [Changing Data: DML](02-dml.md)
