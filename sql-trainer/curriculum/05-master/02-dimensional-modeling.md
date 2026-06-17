# Dimensional Modeling: Building for Questions

> Organize data the way analysts think — measurements at the center, context all around.

## The idea

Normalization, from the last module, is built to keep data *correct* as it changes. But analysts don't ask "is this correct?" — they ask "what happened, and how does it break down?" *Show me revenue by region, by month, by product category.* A schema tuned for safe writing is often clumsy for that kind of question.

Dimensional modeling flips the priorities. It's a way of arranging data purpose-built for analysis, and once you see it you'll recognize it everywhere.

The core insight is that every analytical question has two kinds of words in it. There are the **measurements** — the numbers you want to add up, average, or count: revenue, quantity, profit. And there are the **ways you slice them** — by region, by month, by category, by rep. Dimensional modeling gives each kind its own home.

The measurements live in a **fact table**. Each row is one event that happened — one sale — and it holds the numbers (the *facts*) plus skinny pointers to context. Fact tables are tall and narrow: billions of rows, just a handful of columns.

The context lives in **dimension tables**. A dimension is a thing you slice *by*: customers, products, dates, reps. Each holds rich descriptive detail — names, categories, hierarchies. Dimensions are short and wide: relatively few rows, many descriptive columns.

Picture a wheel. The fact table is the **hub** at the center. The dimensions are the spokes radiating out. Because the diagram looks like a star, this is called a **star schema** — and it's the workhorse of analytics.

```
        customers
            |
products -- SALES (fact) -- dates
            |
        sales_rep
```

The fact in the middle holds `amount` plus keys pointing at each dimension. Want revenue by region by month? Join the fact to the customer dimension (for region) and the date dimension (for month), sum the amount, group. The query reads almost exactly like the question.

## Why it matters

Star schemas are easy for humans *and* easy for machines. Humans grasp them because they mirror how we naturally describe data ("sales, by customer, by date"). Machines love them because the shape is predictable — query engines have decades of optimizations tuned specifically for star-shaped joins.

This approach, popularized by Ralph **Kimball**, became the backbone of data warehousing precisely because it scales in both senses: it scales to huge data volumes, and it scales to large teams who can all read the same simple shape.

## The pieces, plainly

**Grain** is the single most important decision, and it's deceptively simple: *what does one row of the fact table mean?* "One row per sale"? "One row per product per sale"? "One row per store per day"? Declare the grain in one sentence before anything else, and never mix grains in one table. Get the grain fuzzy and every total you compute will be subtly, maddeningly wrong.

**Facts** are the numbers in the fact table. The best ones are *additive* — they make sense when you sum them across any dimension (revenue, quantity). Some are *semi-additive* (a bank balance sums across accounts but not across time). Some are *non-additive* (a ratio like margin % — you must recompute it, not sum it). Knowing which kind you have prevents wrong rollups.

**Surrogate keys** are meaningless integer IDs the warehouse generates for each dimension row — `customer_key = 4471` — separate from the business's natural key like an email or SKU. Why bother? Because natural keys change (people change emails, products get renumbered in a merger), and because they let you track history (next module). The fact table stores the small surrogate key, joins stay fast, and the business key lives safely inside the dimension.

## See it

Star versus snowflake, in one comparison.

A **star schema** keeps each dimension flat — one table, even if that means repeating a category name on many rows:

```sql
SELECT c.region, p.category, SUM(f.amount) AS revenue
FROM sales_fact f
JOIN dim_customer c ON c.customer_key = f.customer_key
JOIN dim_product  p ON p.product_key  = f.product_key
GROUP BY c.region, p.category;
```

A **snowflake schema** normalizes those dimensions further — a product dimension that points to a separate category table, which points to a department table. The diagram sprouts branches off each spoke, like a snowflake's crystals. It saves a little storage and removes some repetition, but it costs extra joins and makes queries harder to read.

The Kimball guidance is blunt and usually right: **prefer the star.** Storage is cheap; analyst clarity and join simplicity are not. Snowflake only the dimensions that genuinely need it (very large dimensions, or hierarchies that change on their own).

> **Dialect note:** Some engines offer "star schema optimization" hints or automatic star-join detection; the available knobs differ by platform — see the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Undeclared grain is the cardinal sin.** Write the grain sentence first; pin it to the wall.
- **Don't mix grains in one fact table.** Order-level and line-level facts belong in separate tables.
- **Don't sum non-additive facts.** Percentages and ratios must be recomputed from their components, never added.
- **Resist over-snowflaking.** Each extra dimension table is another join every analyst pays for, forever.
- **Don't put descriptive text in the fact table.** Names and categories belong in dimensions; facts hold numbers and keys.

## Practice

1. Write the one-sentence grain for a fact table that records each sale in our dataset. Then write a *different* grain for the same business and explain how the tables would differ.
2. List the facts and the dimensions for a "store sales" warehouse. For each fact, label it additive, semi-additive, or non-additive.
3. Design a star schema for our sample data: name the fact table, its facts, and the dimension tables. Sketch the spokes.
4. A colleague wants to break the product dimension into product → category → department tables (snowflake). Argue when that's worth it and when it isn't.

---
**Prev:** [Data Modeling](./01-data-modeling.md) · **Next:** [Slowly Changing Dimensions](./03-slowly-changing-dimensions.md)
