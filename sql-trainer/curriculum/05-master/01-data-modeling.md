# Data Modeling: Three Lenses on the Same World

> Shape your data deliberately — first as ideas, then as tables, then as bytes.

## The idea

Up to now you've mostly been a guest in someone else's house: the tables already existed, and you learned to find your way around them. In this tier you become the architect. And the first thing an architect does is *model* — decide what rooms exist, how they connect, and where the plumbing runs — before a single brick is laid.

A data model is exactly that: a deliberate description of the things your system cares about and how they relate. The classic approach uses three lenses, each sharper than the last.

**The conceptual model** is the big-picture sketch on a napkin. It names the *things* — customers, sales, reps, products — and the relationships between them: "a customer places many sales," "a rep earns commission on sales." No columns, no types, no database in sight. Just the shape of the business. Anyone in the room, technical or not, should be able to nod along.

**The logical model** adds the detail an analyst needs. Now each thing becomes an *entity* with *attributes*: a customer has a name, a region, a signup date, an email. You decide which attribute uniquely identifies each row (the key), and you draw the relationships precisely — one-to-many, many-to-many. Still no mention of Postgres or Oracle. It's the floor plan with measurements.

**The physical model** is the model translated into a *specific* database. Now `customer_name` becomes `VARCHAR(120)`, `signup_date` becomes `DATE`, you add indexes, choose partitioning, pick a storage engine. This is the blueprint the builders actually work from, and it's the only one of the three that changes when you switch databases.

The discipline is to move through them in order. Skip to physical too early and you end up modeling your *tools* instead of your *business*.

## Why it matters

A good model is the difference between a system that bends gracefully as the business grows and one that cracks the first time someone asks an unexpected question. Get the model right and queries become natural, joins become obvious, and data stays consistent on its own. Get it wrong and you spend the next five years writing workarounds.

Modeling is also the most leveraged thing you'll ever do. A clumsy query costs one person an afternoon. A clumsy schema costs every person who touches it, forever.

## See it: normalization, the intuitive version

**Normalization** is the craft of organizing tables so each fact lives in exactly one place. It sounds bureaucratic; it's really just common sense, dressed up in three "normal forms."

Imagine a single sprawling spreadsheet where every sale also repeats the customer's name, region, and email:

| sale_id | amount | customer_name | region | email |
|---|---|---|---|---|
| 1 | 200 | Ada Lovelace | West | ada@x.com |
| 2 | 150 | Ada Lovelace | West | ada@x.com |

When Ada changes her email, you must hunt down *every* sale row to fix it — and if you miss one, your data now disagrees with itself. That's the disease normalization cures.

**First Normal Form (1NF): one value per cell.** No comma-separated lists, no "phone1, phone2, phone3" columns. If a customer has three phone numbers, those belong in their own rows in a related table, not crammed into one cell. *Rule of thumb: a column holds a single, atomic value.*

**Second Normal Form (2NF): every column depends on the whole key.** This bites when a table has a *composite* key (say, `sale_id` + `product_id`). If a column depends on only part of that key — like the product's category, which depends on `product_id` alone — it's in the wrong table. *Rule of thumb: no column should describe just a piece of the key.*

**Third Normal Form (3NF): columns depend on the key, nothing but the key.** In our spreadsheet, `region` doesn't really depend on the *sale* — it depends on the *customer*. So `region` belongs in a `customers` table, and the sale just points at the customer. *Rule of thumb: if column A determines column B, and A isn't the key, B is in the wrong table.*

People memorize it as: every non-key column depends on **the key, the whole key, and nothing but the key.** Reach 3NF and you've eliminated the vast majority of "my data contradicts itself" bugs.

Here's our spreadsheet, normalized:

```sql
-- customers owns the customer facts, once
CREATE TABLE customers (
  customer_id   INTEGER PRIMARY KEY,
  customer_name VARCHAR(120),
  region        VARCHAR(40),
  email         VARCHAR(160)
);

-- sales just point at the customer
CREATE TABLE sales (
  sale_id     INTEGER PRIMARY KEY,
  customer_id INTEGER REFERENCES customers(customer_id),
  amount      NUMERIC(12,2)
);
```

Now Ada's email lives in one cell. Change it once, and every sale sees the update instantly.

## When to denormalize

Normalization optimizes for *correctness on write*. But reading normalized data means joining tables back together, and at scale those joins cost time. So sometimes you deliberately break the rules and store a copy of data where it's convenient — **denormalization**.

A reporting table that pre-joins customer region onto each sale row is denormalized on purpose: you accept the risk of stale copies in exchange for blazing-fast reads. The trade is always the same — *normalize to protect the truth, denormalize to protect the clock.* Transactional systems (lots of writes, where one wrong number matters) lean normalized. Analytical systems (mostly reads, scanning billions of rows) happily denormalize. You'll see this tension drive nearly every design choice in this tier.

## Watch out

- **Don't model the database before you've modeled the business.** Conceptual first, always.
- **Normalization is a tool, not a religion.** 3NF is the sensible default; blindly chasing higher forms can hurt more than help.
- **Denormalization without a refresh plan rots.** If you copy data, you own keeping the copy honest.
- **A key that can change isn't a great key.** Prefer stable identifiers (more on surrogate keys in the next module).
- **Many-to-many relationships need a bridge table.** Customers and products related directly is usually a sign you're missing the `sales` table in between.

## Practice

1. Sketch a conceptual model (just boxes and lines, in words) for our sample dataset: customers, sales, sales_rep, products. Name every relationship.
2. You're handed a flat export where each row is a sale that *also* repeats the rep's name, commission rate, and hire date. Identify the 3NF violation and describe how you'd split it.
3. Design a denormalized "sales summary" table for a dashboard that shows revenue by region by month. What do you copy, and what's your plan to keep it fresh?
4. Argue both sides: a colleague wants to store a customer's three favorite categories as `cat1, cat2, cat3` columns. Make the case against (normalization) and the case for (pragmatism). When would each win?

---
**Prev:** [Tier 4: Expert](../04-expert/) · **Next:** [Dimensional Modeling](./02-dimensional-modeling.md)
