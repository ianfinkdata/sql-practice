# 8. DISTINCT and Duplicates

<!-- nav -->
Previous: [7. Pattern Matching with LIKE](07-pattern-matching-with-like.md). Next: [Tier 2 — Intermediate](../02-intermediate/README.md). Exercises: [8. DISTINCT and Duplicates](../../exercises/01-beginner/08-distinct-and-duplicates.md).
<!-- /nav -->

## The idea

`DISTINCT` removes duplicate rows from a result — if the same value
(or combination of values) appears more than once, you only see it
once. It's the tool for questions like "what are all the different
categories we have?" rather than "list every product's category,
including repeats."

```sql
SELECT DISTINCT column_name FROM table_name;
```

## Why it matters

`bronze_products` has 150 rows but far fewer *distinct* categories.
`DISTINCT` is how you go from "150 rows of category text" to "the set
of category values that actually occur." It's a natural fit for
exploring what values live in a column before you decide how to filter
or group by it — and, as you're about to see, it's also an excellent
tool for *revealing* messiness, since a column you expect to have 8
values might turn out to have many more once you actually ask.

## Syntax

```sql
SELECT DISTINCT column_name
FROM table_name;
```

`DISTINCT` applies to the whole row of selected columns, not just one
column in isolation — with multiple columns, it removes rows only
where *every* selected column matches another row exactly:

```sql
SELECT DISTINCT column_a, column_b
FROM table_name;
```

You can also count distinct values directly:

```sql
SELECT COUNT(DISTINCT column_name) FROM table_name;
```

## Try it

### Every distinct department

```sql
SELECT DISTINCT department
FROM bronze_employees
ORDER BY department;
```

| department |
|---|
| MANAGEMENT |
| Management |
| SUPPORT |
| Sales |
| Support |
| WAREHOUSE |
| Warehouse |
| management |
| sales |
| support |
| warehouse |

11 distinct values for what should conceptually be **4** departments
(Sales, Support, Warehouse, Management). `DISTINCT` did exactly what
it promised — it removed *exact* duplicate rows — but each casing
variant of the same real department (`MANAGEMENT`, `Management`,
`management`) is a *different* exact string, so `DISTINCT` treats them
as different values. This is the seed of the dedup/standardization
work coming in later tiers.

### How many distinct brands?

```sql
SELECT COUNT(DISTINCT brand) FROM bronze_products;
```

| COUNT(DISTINCT brand) |
|---|
| 24 |

24 distinct brand names across 150 products — a much more useful
number than "150 rows of brand text," most of which repeat.

### The category column: a near-duplicate showcase

```sql
SELECT COUNT(DISTINCT category) FROM bronze_products;
```

| COUNT(DISTINCT category) |
|---|
| 40 |

**40.** Not 8 — even though Oakhaven really only sells 8 canonical
categories of gear (Footwear, Apparel, Camping & Hiking, Climbing,
Water Sports, Winter Sports, Accessories, Nutrition & Hydration).
`DISTINCT` isn't wrong here — it's accurately reporting that there
really are 40 different exact strings in this column. The gap between
"40 distinct strings" and "8 real categories" *is* the messiness: same
underlying category, spelled/cased/spaced differently. A few examples
of what's hiding in there: `FOOTWEAR`, `Footwear`, `footwear`, `Foot
Wear`, and even `FOOT WEAR ` (with a trailing space) all mean the same
thing to a human, but are 5 separate values to `DISTINCT`. You may
even notice what look like duplicate rows in a raw `SELECT DISTINCT
category` listing — that's usually a value with invisible trailing
whitespace sitting right next to its trimmed twin.

This is a preview, not the fix. Actually collapsing these 40 strings
down to 8 clean categories — trimming whitespace, standardizing case,
handling "and" vs "&" — is exactly what Tier 2 (and the real
`silver_products` view in this project) does. For now, the skill worth
taking away is simpler: **`COUNT(DISTINCT column)` is a fast, reliable
way to check "is this column messier than I expect?"** before you rely
on it for anything.

### Distinct combinations across two columns

```sql
SELECT DISTINCT payment_method
FROM bronze_sales
ORDER BY payment_method;
```

| payment_method |
|---|
| CC |
| Cash |
| Credit Card |
| Debit Card |
| Gift Card |
| PayPal |
| cash |
| credit card |
| debit card |
| paypal |

10 distinct raw values for what should be 5 real payment methods
(Credit Card, Cash, Debit Card, Gift Card, PayPal) — the same pattern
as `category`, on a different column, in the biggest table in the
database.

## Common mistakes

- **Assuming DISTINCT understands meaning, not just exact text.**
  `DISTINCT` deduplicates by exact value — it has no idea that
  `'Footwear'` and `'FOOTWEAR'` "mean" the same category. If you want
  that, you need to standardize the values first (case-folding,
  trimming, etc.) — coming in Tier 2.
- **Trusting `COUNT(DISTINCT column)` as "the number of real-world
  categories."** As shown above, it tells you how many distinct
  *strings* exist, which is a ceiling on the number of real categories
  — never fewer than the real count, often quite a bit more.
- **Forgetting DISTINCT applies to the whole selected row.**
  `SELECT DISTINCT category, brand FROM ...` doesn't independently
  dedupe each column — it only removes rows where *both* columns
  together exactly match another row.
- **Reaching for DISTINCT to hide a bug in filtering/joining logic.**
  If a query is producing more rows than expected, slapping `DISTINCT`
  on top can mask (rather than fix) a real problem elsewhere in the
  query — worth keeping in mind once you get to joins in a later tier.

## Key takeaways

- `DISTINCT` removes exact-duplicate rows from a result.
- `COUNT(DISTINCT column)` counts how many distinct exact values a
  column has — a quick, useful "how messy is this?" check.
- `bronze_products.category` has 40 distinct raw strings representing
  only 8 real categories, and `bronze_sales.payment_method` shows the
  same pattern — a direct, concrete preview of the cleanup work in
  Tier 2.

---

<!-- nav -->
Previous: [7. Pattern Matching with LIKE](07-pattern-matching-with-like.md). Next: [Tier 2 — Intermediate](../02-intermediate/README.md). Exercises: [8. DISTINCT and Duplicates](../../exercises/01-beginner/08-distinct-and-duplicates.md).
<!-- /nav -->
