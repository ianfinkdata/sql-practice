# Operators and Logic: Combining Conditions

> After this module you'll be able to build rich filters with AND/OR/NOT, ranges, lists, pattern matching, and missing-value checks.

## The idea

In module 3 you filtered rows with a single condition. Real questions often need several conditions at once: customers in the West *who signed up this year*, sales between $100 and $500. This module is about combining and expressing conditions.

### Combining conditions: AND, OR, NOT

- **AND** means *both* conditions must be true. "In the West AND signed up this year" keeps a row only if both hold.
- **OR** means *at least one* must be true. "In the West OR in the East" keeps a row if either holds.
- **NOT** flips a condition. "NOT in the West" keeps rows where the condition is false.

### Handy shortcuts

- **BETWEEN** checks whether a value falls in a range, *inclusive* of both ends. `amount BETWEEN 100 AND 500` is a tidy way to say `amount >= 100 AND amount <= 500`.
- **IN** checks whether a value matches any item in a list. `region IN ('West', 'East')` is shorthand for `region = 'West' OR region = 'East'`.
- **LIKE** matches text patterns using two wildcards. The percent sign `%` stands for "any run of characters" (including none), and the underscore `_` stands for "exactly one character." So `customer_name LIKE 'S%'` finds every name starting with S.

### Missing values: IS NULL

Sometimes a cell is empty — no email on file, for instance. That emptiness has a name: **NULL**, meaning "no value / unknown." NULL is special: you *cannot* test it with `=`. Writing `email = NULL` never works, because NULL isn't equal to anything, not even itself. Instead you use **IS NULL** (or **IS NOT NULL**) to check for it.

### Precedence and parentheses

When you mix AND and OR, AND binds tighter than OR — it's evaluated first, just like multiplication before addition in math. That can surprise you. To make your meaning unambiguous, group conditions with **parentheses**. When in doubt, add parentheses; they cost nothing and remove all guesswork.

## Why it matters

This is where filtering gets powerful enough for real questions. "High-value sales in two specific regions, excluding one rep, where the email is missing" is just a stack of these operators. And understanding NULL and precedence saves you from silent, confusing wrong answers — two of the most common SQL traps there are.

## See it

Both conditions must hold (AND):

```sql
SELECT customer_name, region, signup_date
FROM customers
WHERE region = 'West'
  AND signup_date >= '2026-01-01';
```

A range with BETWEEN and a list with IN:

```sql
SELECT sale_id, amount
FROM sales
WHERE amount BETWEEN 100 AND 500
  AND rep_id IN (3, 7, 9);
```

Pattern matching with LIKE, and checking for missing data:

```sql
SELECT customer_name, email
FROM customers
WHERE customer_name LIKE 'S%'
   OR email IS NULL;
```

Parentheses to control precedence — "(West or East) AND a big sale isn't expressible on one table, but the grouping idea looks like this":

```sql
SELECT customer_name, region
FROM customers
WHERE (region = 'West' OR region = 'East')
  AND signup_date >= '2026-01-01';
```

Without those parentheses, AND would bind first and change the meaning entirely.

## Watch out

- **`= NULL` never matches.** Always use `IS NULL` / `IS NOT NULL` to test for missing values.
- **AND beats OR.** `a OR b AND c` means `a OR (b AND c)`. If you meant `(a OR b) AND c`, you must write the parentheses.
- **`BETWEEN` includes both endpoints.** `BETWEEN 100 AND 500` keeps 100 and 500 themselves — not just the values strictly in between.
- **`LIKE` wildcards: `%` is many characters, `_` is exactly one.** Mixing them up is a common slip.
- **`IN` values follow the column's type.** Quote text (`IN ('West','East')`); leave numbers bare (`IN (3, 7, 9)`).
- **`NOT` can be confusing with NULL.** A row with NULL often fails *both* a condition and its NOT — because the answer is "unknown," not true or false.

## Practice

1. Find sales where the `amount` is between 250 and 1000 and the `rep_id` is one of 1, 2, or 5.
2. List customers whose `region` is West or East, returning name and region.
3. Find every customer whose `email` is missing (NULL). Return their name.
4. Find products whose `product_name` starts with the letter "B" (use LIKE).
5. Write a filter for customers in the West region who signed up on or after `2026-06-01`, using parentheses to make the logic unambiguous.

---
**Prev:** [DISTINCT and Expressions](05-distinct-expressions.md) · **Next:** [Tier 2: Intermediate](../02-intermediate/)
