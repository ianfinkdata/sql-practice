# Working with NULLs

> The value that means "unknown" — and why it breaks the rules you expect.

## The idea

Sometimes data is simply missing. A customer signed up but never gave an email. A sale was recorded before the rep was assigned. SQL has a special marker for this: **NULL**, meaning "no value here — unknown or not applicable."

Here's the mind-bender: NULL is *not* zero, and it's *not* an empty string. Those are real, known values. NULL is the *absence* of a value. It's the difference between a box containing the number 0 and a box you haven't been allowed to open.

This leads to **three-valued logic**. In everyday thinking, a statement is either true or false. SQL adds a third outcome: **unknown**. Any comparison involving NULL produces "unknown," because you can't compare against something you don't know.

The classic trap: **NULL = NULL is not true.** It's *unknown*. If I have two boxes I can't open, are their contents equal? I genuinely can't say. So SQL won't claim they're equal — it answers "unknown," and unknown rows don't pass a filter.

The analogy: NULL is a blank you haven't filled in. Two blanks aren't "the same"; they're just both blank.

## Why it matters

NULLs hide in nearly every real dataset, and they cause the most baffling bugs in SQL — rows that mysteriously vanish, counts that don't add up, joins that drop records. Once you understand that NULL means "unknown" and behaves by three-valued logic, these mysteries dissolve. Handling NULLs correctly is what separates fragile queries from reliable ones.

## See it

Because `= NULL` never works, SQL gives you a dedicated test: **IS NULL** (and **IS NOT NULL**). Find customers with no email:

```sql
SELECT customer_name
FROM customers
WHERE email IS NULL;
```

Using `WHERE email = NULL` here would return *nothing*, because the comparison is "unknown" for every row.

**COALESCE** returns the first non-NULL value from a list — perfect for supplying a fallback. Show "no email on file" wherever the email is missing:

```sql
SELECT
  customer_name,
  COALESCE(email, 'no email on file') AS contact
FROM customers;
```

**NULLIF** does the reverse: it returns NULL when two values are equal, otherwise the first value. It's handy for turning a placeholder into a true NULL, or for dodging division-by-zero. Here, if a commission rate is 0, treat it as NULL so it doesn't break a later calculation:

```sql
SELECT
  rep_name,
  amount / NULLIF(commission_rate, 0) AS adjusted
FROM sales_rep
JOIN sales ON sales.rep_id = sales_rep.rep_id;
```

If `commission_rate` is 0, `NULLIF` makes it NULL, and dividing by NULL yields NULL instead of an error.

### NULLs in aggregates

As you saw earlier, **SUM, AVG, MIN, MAX, and COUNT(column) all ignore NULLs.** They skip missing values entirely:

```sql
SELECT
  COUNT(*)        AS all_rows,
  COUNT(email)    AS rows_with_email,
  AVG(amount)     AS avg_of_known_amounts
FROM customers;
```

`AVG` divides by the count of *known* amounts, not by every row. If that's not what you want, fill NULLs with COALESCE *before* averaging.

### NULLs in joins

When a LEFT JOIN finds no match, it fills the right-side columns with NULL — that's the signal of "no match." This is also why the anti-join pattern (`WHERE right_key IS NULL`) works: you're looking for exactly those manufactured NULLs.

## Watch out

- **Never use `= NULL` or `<> NULL`.** Always `IS NULL` / `IS NOT NULL`.
- **NULL spreads through arithmetic.** `amount + NULL` is NULL, not `amount`. Wrap shaky columns in COALESCE before doing math.
- **NOT IN with a NULL in the list returns no rows.** A notorious bug. Prefer `NOT EXISTS` for "not in this set" checks.
- **NULLs form their own GROUP BY bucket** — all the unknowns land together in one group.
- **AVG can mislead** when many values are NULL, since it only averages the known ones. Decide whether missing should count as zero, and COALESCE if so.
- **A NULL in a comparison is "unknown," and unknown fails the filter** — so the row drops out. That's often why rows go missing.

## Practice

1. List all customers who do not have an email address on file.
2. Show each customer's email, substituting the text 'unknown' wherever the email is missing.
3. Explain to yourself why `WHERE email = NULL` returns no rows, and what to use instead.
4. Compute the average sale amount, then think through how the result would change if some amounts were NULL versus if they were zero.

---
**Prev:** [CASE & Conditional Logic](./08-case-conditional.md) · **Next:** [Tier 3: Advanced](../03-advanced/)
