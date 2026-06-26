# Tier 1 — Beginner: Asking a Single Table for Answers

Welcome. I'm SQRL, and I'll be your guide through this tier.

We're going to start right at the beginning, no experience assumed. By the end of this tier you'll be able to get answers out of a single table — choosing what to look at, filtering down to the rows that matter, sorting them, and shaping the results into something readable. Every concept gets explained in plain English first, with a real-world analogy, *before* any code shows up. Take it one module at a time, and try the practice prompts as you go — that's where it really sticks.

Throughout the whole course we use the same four sample tables, so you'll get comfortable with them fast:

- `customers(customer_id, customer_name, region, signup_date, email)`
- `sales(sale_id, sale_date, customer_id, rep_id, amount)`
- `sales_rep(rep_id, rep_name, commission_rate, hire_date)`
- `products(product_id, product_name, category, unit_price)`

## The modules

1. **[The Relational Model in Plain English](01-relational-model.md)** — Tables, rows, columns, and primary keys: how data is organized and why that structure lets you ask precise questions.
2. **[SELECT and FROM](02-select-from.md)** — Choose which columns you want and which table they come from, including `SELECT *` and renaming columns with `AS`.
3. **[WHERE: Filtering Rows](03-where.md)** — Keep only the rows that match a condition, using comparison operators and correct quoting for text versus numbers.
4. **[ORDER BY and LIMIT](04-order-by-limit.md)** — Sort your results ascending or descending (even on multiple keys) and keep just the top few rows.
5. **[DISTINCT and Expressions](05-distinct-expressions.md)** — List unique values, build computed columns with arithmetic, and combine text with concatenation.
6. **[Operators and Logic](06-operators-logic.md)** — Combine conditions with AND/OR/NOT, use BETWEEN, IN, and LIKE, handle NULLs, and control precedence with parentheses.

Work through them in order — each one builds on the last. When you finish module 6, you'll be ready to bring multiple tables together in Tier 2.

---
**Prev:** [Orientation](../00-orientation/) · **Next:** [Tier 2: Intermediate](../02-intermediate/)
