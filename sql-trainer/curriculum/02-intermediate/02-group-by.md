# GROUP BY

> Summarize per category — one total for each region, each rep, each month.

## The idea

In the last module, an aggregate squeezed the whole table into a single number. But usually you don't want *one* total — you want *one total per group*.

Not "what were total sales?" but "what were total sales **in each region**?" Not "how many customers?" but "how many customers **per signup month**?"

That's `GROUP BY`. It sorts your rows into buckets based on a column you choose, then runs the aggregate separately inside each bucket.

Picture sorting a pile of receipts into stacks — one stack per store. Then you tally each stack on its own. GROUP BY makes the stacks; the aggregate tallies them. You get back one summary row per stack.

## Why it matters

"Per category" is how almost every report is shaped. Sales by region. Revenue by rep. Sign-ups by month. Orders by customer.

GROUP BY is the workhorse that produces these breakdowns. Once it clicks, you'll reach for it constantly.

## See it

Total revenue, broken down by region:

```sql
SELECT
  region,
  SUM(amount) AS total_revenue
FROM sales
JOIN customers ON sales.customer_id = customers.customer_id
GROUP BY region;
```

You get one row per region, each with its own total. (Don't worry about the JOIN line yet — that's coming. For now, focus on the grouping.)

Here's the one rule that catches everyone. **Every column in your SELECT must either be inside an aggregate, or be named in the GROUP BY.**

Why? Because each output row represents a *whole group*. If you ask for a column that isn't grouped, SQL doesn't know *which* value from the group to show you — there could be hundreds of different ones. So it refuses.

This is wrong and will error in standard SQL:

```sql
SELECT region, customer_name, SUM(amount)
FROM sales
JOIN customers ON sales.customer_id = customers.customer_id
GROUP BY region;          -- customer_name is neither grouped nor aggregated
```

You can group by **multiple columns** to make finer buckets. This gives a total for each region-and-rep combination:

```sql
SELECT
  region,
  rep_id,
  SUM(amount) AS total_revenue
FROM sales
JOIN customers ON sales.customer_id = customers.customer_id
GROUP BY region, rep_id;
```

Now each unique pairing of region and rep is its own stack.

> **Dialect note:** Some databases (like older MySQL) let you SELECT ungrouped columns and silently pick a random value, which hides bugs. Standard SQL and most modern databases reject it. Always list every non-aggregated column. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **The golden rule:** non-aggregated SELECT columns must appear in GROUP BY. The most common error in this entire tier.
- **GROUP BY changes the shape of your output** from "one row per record" to "one row per group." Expect fewer rows.
- **Grouping by more columns means more, smaller groups** — not fewer. `GROUP BY region, rep_id` produces more rows than `GROUP BY region` alone.
- **NULL forms its own group.** Rows with a missing value in the grouping column get bundled together into a single NULL bucket.
- **Don't filter groups with WHERE.** WHERE acts before grouping. To filter the groups themselves, you need HAVING — the very next module.

## Practice

1. Count how many customers signed up in each region.
2. Find the total and average sale amount for each sales rep (`rep_id`).
3. Break down total revenue by both region and rep at once, so each region-rep pairing gets its own line.
4. Find the number of distinct customers each rep has sold to.

---
**Prev:** [Aggregate Functions](./01-aggregate-functions.md) · **Next:** [HAVING](./03-having.md)
