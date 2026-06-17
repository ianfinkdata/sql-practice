# Ranking Rows

> Number, rank, and bucket rows in order — and handle ties the way you mean to.

## The idea

Once you can order rows within a window, the natural next step is to *number* them. Who's first? Who's second? Who's in the top 10%? Ranking functions answer exactly these questions, and they all live inside `OVER (ORDER BY ...)`.

There are four to know, and the differences are all about how they treat **ties** — rows that share the same value.

Imagine a race where two runners cross the line at exactly the same moment.

- **`ROW_NUMBER()`** insists on a unique number for every row, no matter what. The two tied runners get, say, 3 and 4 — chosen arbitrarily. There are no ties; someone is always "first."
- **`RANK()`** gives tied rows the *same* rank, then **skips** the next numbers. Two runners tie for 3rd, so both get 3, and the next runner is 5th. (There is no 4th — those places were "used up.")
- **`DENSE_RANK()`** also gives ties the same rank, but does **not** skip. Two get 3, and the next is 4. No gaps.
- **`NTILE(n)`** ignores fine-grained ranking and instead chops the ordered rows into `n` roughly equal **buckets** — quartiles (`NTILE(4)`), deciles (`NTILE(10)`), and so on. Each row gets a bucket number from 1 to n.

A simple way to remember the trio: **ROW_NUMBER never ties, RANK ties with gaps, DENSE_RANK ties without gaps.**

## Why it matters

"Top N" is one of the most-asked questions in business. The top 5 customers by spend. The best-selling product per category. The three most recent orders per customer. All of these are ranking problems.

The real superpower is **top-N-*per-group***. Plain `ORDER BY ... LIMIT` gives you the top N of the *whole* table. But "top 3 reps *in each region*" needs a ranking that **restarts inside each group** — and that's `PARTITION BY` plus a ranking function, filtered down to the ranks you want.

## See it

Rank sales reps by total sales, highest first:

```sql
SELECT
  rep_id,
  SUM(amount) AS total_sales,
  RANK() OVER (ORDER BY SUM(amount) DESC) AS sales_rank
FROM sales
GROUP BY rep_id;
```

Now the classic **top-N-per-group** pattern. Because you can't filter a window function in `WHERE`, you compute the ranking in a subquery (or CTE), then filter outside it. Here's the top 3 sales per region:

```sql
SELECT *
FROM (
  SELECT
    s.sale_id,
    c.region,
    s.amount,
    ROW_NUMBER() OVER (
      PARTITION BY c.region
      ORDER BY s.amount DESC
    ) AS rn
  FROM sales s
  JOIN customers c ON c.customer_id = s.customer_id
) ranked
WHERE rn <= 3;
```

The `PARTITION BY c.region` is what makes the numbering restart at 1 for every region. The outer `WHERE rn <= 3` keeps only the top three of each.

Split customers into four equal spending buckets with `NTILE`:

```sql
SELECT
  customer_id,
  SUM(amount) AS total_spent,
  NTILE(4) OVER (ORDER BY SUM(amount) DESC) AS spend_quartile
FROM sales
GROUP BY customer_id;
```

Quartile 1 is your biggest spenders; quartile 4, your smallest.

## Watch out

- **Pick the right tie behavior.** Using `ROW_NUMBER` when you meant `RANK` (or vice versa) is a subtle, common bug. Ask yourself: should ties share a number?
- **`ROW_NUMBER` breaks ties arbitrarily.** If two rows are equal on your `ORDER BY`, which gets the lower number is undefined unless you add more tie-breaker columns to the `ORDER BY`.
- **You must filter ranks outside the window.** `WHERE rn <= 3` only works once `rn` exists in an inner query or CTE — never in the same `SELECT` that defines it.
- **`NTILE` buckets can be uneven.** When rows don't divide cleanly, the earlier buckets get one extra row each.
- **`ORDER BY` direction matters.** Forgetting `DESC` ranks smallest-first when you wanted largest-first.

## Practice

1. In words, explain the difference between `RANK` and `DENSE_RANK` for a set of scores 90, 90, 80.
2. Write a query that ranks customers by total spend, highest first.
3. Use the top-N-per-group pattern to return the two highest-amount sales for each sales rep.
4. Divide all customers into deciles (10 buckets) by total spend, and describe what bucket 1 versus bucket 10 represents.

---
**Prev:** [Window Functions: The Big Idea](./01-window-functions-intro.md) · **Next:** [Running Totals & Moving Averages](./03-running-totals.md)
