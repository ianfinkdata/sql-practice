# HAVING

> Filter the groups themselves — after the totals are computed.

## The idea

You already know `WHERE`: it keeps the rows you want and throws out the rest. So why do we need a second filter?

Because there are two different moments when you might want to filter, and WHERE only works at the first one.

Picture a building with two doors.

**The first door** is at the entrance, before anyone forms a team. A guard checks each *person* individually: "Are you on the guest list?" Anyone who fails is turned away. This is **WHERE** — it filters individual rows *before* grouping.

**The second door** is deeper inside, after people have gathered into teams. A second guard checks each *team*: "Does your team have at least five members?" Teams that are too small are dismissed as a group. This is **HAVING** — it filters whole groups *after* the aggregate is computed.

The key difference: WHERE judges raw rows. HAVING judges the summarized results. So HAVING can talk about aggregates — `SUM`, `COUNT`, `AVG` — while WHERE cannot.

## Why it matters

The moment you start asking questions like "which regions had more than 100 sales?" or "which reps averaged over $500 per sale?", you're filtering on a calculated total. WHERE simply can't do that, because the total doesn't exist yet when WHERE runs. HAVING is the tool for those questions.

## See it

Find regions whose total revenue exceeds 50,000:

```sql
SELECT
  region,
  SUM(amount) AS total_revenue
FROM sales
JOIN customers ON sales.customer_id = customers.customer_id
GROUP BY region
HAVING SUM(amount) > 50000;
```

Notice HAVING refers to `SUM(amount)` — an aggregate. That's its whole purpose.

You'll often use **both** filters together. WHERE narrows the rows first; HAVING judges the groups after:

```sql
SELECT
  region,
  COUNT(*) AS sale_count
FROM sales
JOIN customers ON sales.customer_id = customers.customer_id
WHERE sale_date >= '2026-01-01'        -- door 1: only this year's sales
GROUP BY region
HAVING COUNT(*) > 100;                  -- door 2: only busy regions
```

Read it in order: keep 2026 rows, bucket them by region, then keep only regions with more than 100 of those rows.

### Execution order

This is worth memorizing, because it explains everything above. SQL processes a query roughly in this order:

1. **FROM / JOIN** — gather the rows
2. **WHERE** — filter individual rows
3. **GROUP BY** — form the groups
4. **HAVING** — filter the groups
5. **SELECT** — pick the columns
6. **ORDER BY** — sort the result

WHERE comes before grouping, so it can't see aggregates. HAVING comes after, so it can. That ordering is the entire reason two filters exist.

## Watch out

- **Don't put aggregates in WHERE.** `WHERE SUM(amount) > 100` is an error. Aggregates belong in HAVING.
- **Don't use HAVING for plain row filtering.** `HAVING region = 'West'` technically may work but is slower and confusing — that's a row condition, so use WHERE. Reserve HAVING for conditions on aggregates.
- **HAVING needs GROUP BY in spirit.** It filters groups, so it almost always accompanies a GROUP BY. (A HAVING with no GROUP BY treats the whole table as one group — rarely what you want.)
- **Performance:** filtering early with WHERE is cheaper than computing aggregates for groups you'll later discard with HAVING. Trim rows first when you can.

## Practice

1. List the regions that have more than 100 total sales.
2. Find the sales reps whose average sale amount is above 500.
3. Considering only sales from this year, list the regions with total revenue over 25,000.
4. Find which customers have placed more than 10 orders, showing the customer and their order count.

---
**Prev:** [Group By](./02-group-by.md) · **Next:** [Joins: Inner & Left](./04-joins-inner-left.md)
