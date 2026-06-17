# Strings & Regular Expressions

> Clean, slice, and match text — from simple trims to full pattern matching.

## The idea

Real-world text is messy. Names with stray spaces. Emails in mixed case. A "city, state" field that's really two facts crammed into one. Phone numbers in five different formats. Before you can group, join, or trust text data, you usually have to *clean and reshape* it — and SQL has a toolbox for exactly that.

Start with the everyday string tools:

- **`TRIM`** shaves whitespace off the ends — the fix for "why won't these two values match?" when one has a trailing space.
- **`UPPER` / `LOWER`** normalize case so `Bob@x.com` and `bob@x.com` compare as equal.
- **`SUBSTRING`** pulls out a piece by position — the first three characters, say.
- **`REPLACE`** swaps one bit of text for another — strip dashes from a phone number.
- **`SPLIT_PART`** (or `SPLIT`) breaks a string on a delimiter and grabs one piece — the part of an email *before* the `@`, or the *state* out of "Austin, TX".
- **`||`** (or `CONCAT`) glues strings together.

Next, **pattern matching**. `LIKE` is the gentle introduction: `%` means "any run of characters," `_` means "exactly one character." `WHERE email LIKE '%@gmail.com'` finds every Gmail address. It's simple and portable, but limited — it can't express "a digit" or "three letters then four numbers."

For that you need **regular expressions** — a compact mini-language for describing text patterns. A regex can say "starts with a letter, then any number of word characters, then `@`, then a domain." It's the difference between `LIKE`'s blunt wildcards and a precise, surgical match. Regexes power validation ("is this a well-formed email?"), extraction ("pull the area code out"), and sophisticated filtering.

## Why it matters

Data is dirty, and dirty text quietly breaks everything downstream. A trailing space makes a join silently drop rows. Mixed case splits one customer into two. A combined "city, state" column can't be grouped by state until you split it. String functions are how you *clean as you query*, turning messy raw text into something dependable.

And so much useful information lives *inside* strings — domains inside emails, categories inside product codes, area codes inside phone numbers. Pattern matching and extraction are how you mine it out.

## See it

Clean and normalize, then extract the email domain with `SPLIT_PART`:

```sql
SELECT
  customer_id,
  LOWER(TRIM(email)) AS clean_email,
  SPLIT_PART(LOWER(TRIM(email)), '@', 2) AS email_domain
FROM customers;
```

`TRIM` removes stray spaces, `LOWER` normalizes case, and `SPLIT_PART(..., '@', 2)` grabs everything after the `@` — the domain.

Simple pattern matching with `LIKE` — all Gmail customers:

```sql
SELECT customer_name, email
FROM customers
WHERE LOWER(email) LIKE '%@gmail.com';
```

A regular expression for something `LIKE` can't express — emails that look structurally valid:

```sql
SELECT customer_name, email
FROM customers
WHERE email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
```

The pattern reads: some name characters, an `@`, a domain, a dot, and a 2+ letter suffix — anchored start (`^`) to end (`$`).

Replace and concatenate — strip dashes from a code, then label it:

```sql
SELECT
  'CODE-' || REPLACE(product_name, ' ', '_') AS tag
FROM products;
```

> **Dialect note:** String functions and regex syntax diverge sharply across engines. Postgres uses `~` (and `~*` for case-insensitive); Oracle and standard SQL use `REGEXP_LIKE(...)`; MySQL uses `REGEXP` / `RLIKE`; SQL Server has *no* general regex (use `LIKE` or CLR). Splitting is `SPLIT_PART` in Postgres, `SPLIT` returning an array in BigQuery/Spark, `SUBSTRING_INDEX` in MySQL. `SUBSTRING` positions are usually 1-based. Always confirm in the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Hidden whitespace is a silent killer.** Two values that look identical may differ by a trailing space and fail to match or join. `TRIM` defensively.
- **Case sensitivity bites comparisons and joins.** Normalize with `LOWER`/`UPPER` on *both* sides before comparing.
- **String positions are usually 1-based** in SQL (not 0-based like many programming languages). Off-by-one errors are easy.
- **`LIKE` patterns can't do "a digit" or "N characters of a type."** When you find yourself fighting `LIKE`, reach for a regex.
- **Regex syntax is dialect-specific** — and SQL Server lacks it entirely. Don't assume a Postgres `~` pattern runs elsewhere.
- **Splitting and matching on text is slower than on clean columns.** If you split the same field constantly, consider storing it pre-split.

## Practice

1. In plain English, explain when `LIKE` is enough and when you genuinely need a regular expression.
2. Write a query that returns each customer's email domain (the part after `@`), trimmed and lowercased.
3. Find all customers whose email is *not* a Gmail address, being careful about case and stray spaces.
4. Describe a "city, state" column and write (or sketch) how you'd split it into two separate values.

---
**Prev:** [Pivot & Unpivot](./09-pivot-unpivot.md) · **Next:** [Tier 4: Expert](../04-expert/)
