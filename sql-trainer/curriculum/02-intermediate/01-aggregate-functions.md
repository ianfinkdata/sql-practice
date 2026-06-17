# Aggregate Functions

> Turn many rows into a single answer: counts, totals, averages, and extremes.

## The idea

So far you've worked with data one row at a time. You ask a question, and you get back a list. But often the question you really care about isn't "show me every sale" — it's "how many sales were there?" or "what did they add up to?"

That's what aggregate functions do. An **aggregate function** takes a whole stack of values and squeezes it down into one summary number.

Think of a cashier counting a drawer at the end of the day. They don't hand you each bill individually. They count the bills, add up the total, and tell you one figure. The pile of money goes in; a single number comes out.

The five everyday aggregates are:

- **COUNT** — how many?
- **SUM** — added together, how much?
- **AVG** — on average, how much?
- **MIN** — what's the smallest?
- **MAX** — what's the largest?

## Why it matters

Almost every real business question is a summary question. How many customers signed up this year? What were total sales? What's our average order size? Who placed the biggest order?

You can't answer these by scrolling through rows. Aggregates are how you go from raw records to insight, and they're the foundation for nearly everything you'll learn in this tier.

## See it

Let's ask four summary questions about our sales table at once.

```sql
SELECT
  COUNT(*)   AS number_of_sales,
  SUM(amount) AS total_revenue,
  AVG(amount) AS average_sale,
  MAX(amount) AS biggest_sale
FROM sales;
```

This returns exactly one row — a tidy summary of the entire table.

Now, **COUNT** has a few flavors that trip people up, so let's slow down here.

- `COUNT(*)` counts **rows**, period. Empty values and all.
- `COUNT(column)` counts rows where that column **is not NULL** (a NULL is a missing or unknown value — we'll cover NULLs properly in module 09).
- `COUNT(DISTINCT column)` counts the **unique** values.

See the difference:

```sql
SELECT
  COUNT(*)                  AS all_rows,
  COUNT(email)              AS rows_with_email,
  COUNT(DISTINCT region)    AS distinct_regions
FROM customers;
```

If 100 customers exist but 5 have no email, `all_rows` is 100 while `rows_with_email` is 95. And if those 100 customers live in just 4 regions, `distinct_regions` is 4.

## Watch out

- **SUM, AVG, MIN, MAX ignore NULLs.** They quietly skip missing values. This matters most for AVG: it divides by the count of *non-NULL* values, not by the total row count.
- **AVG can mislead you about NULLs.** If half your amounts are missing, the average is only of the half that's present. That may not be what you intended.
- **COUNT(column) is not COUNT(\*).** When a column has missing values, these give different answers. Pick deliberately.
- **Don't mix a bare column with an aggregate** in the same SELECT without grouping (e.g. `SELECT region, COUNT(*) FROM customers`). That's the job of GROUP BY, coming up next — without it, you'll get an error.
- **SUM of nothing is NULL, not zero.** If no rows match your filter, SUM returns NULL. Keep that in mind when a total looks blank.

## Practice

1. Find the total revenue and the average sale amount across the entire `sales` table.
2. Count how many customers there are in total, and separately how many distinct regions they come from.
3. Find the largest and smallest single sale amount on record.
4. Count how many customers have an email on file versus how many customer rows exist altogether, and explain to yourself why the two numbers might differ.

---
**Prev:** [Tier 2 Index](./README.md) · **Next:** [Group By](./02-group-by.md)
