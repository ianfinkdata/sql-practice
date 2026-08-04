# 7. Pattern Matching with LIKE


<!-- nav -->
Previous: [6. Basic Aggregate Functions](06-basic-aggregate-functions.md). Next: [8. DISTINCT and Duplicates](08-distinct-and-duplicates.md).
<!-- /nav -->

## The idea

`=` requires an exact match. Sometimes you don't know the exact value
— you want "anything starting with Canyon," or "anything containing
the word Boot," or "any 4-character code." `LIKE` lets you match text
against a *pattern* instead of an exact string, using two wildcard
characters.

```sql
WHERE column_name LIKE 'pattern'
```

## Why it matters

Free-text columns rarely have values you can predict exactly.
Oakhaven's `product_name` values are things like "Canyon Hiking
Boots," "Cascade Hiking Boots," "Ironpeak Hiking Boot" — related, but
not identical. `LIKE` is how you search for "anything about boots"
without listing every exact product name. It's also your first
introduction to a genuinely useful quirk: `LIKE` is one of the only
places in standard SQL where text comparison is case-insensitive by
default — which matters a lot against a column as messy as
`bronze_products.category`.

## Syntax: the two wildcards

| Wildcard | Matches |
|---|---|
| `%` | Any sequence of characters (zero or more) |
| `_` | Exactly one character |

```sql
WHERE column_name LIKE 'Canyon%'    -- starts with "Canyon"
WHERE column_name LIKE '%Boot%'     -- contains "Boot" anywhere
WHERE column_name LIKE '%Boots'     -- ends with "Boots"
WHERE column_name LIKE 'FOO-000_'   -- "FOO-000" plus exactly one more character
```

## Try it

### Starts with

```sql
SELECT product_name
FROM bronze_products
WHERE product_name LIKE 'Canyon%'
LIMIT 5;
```

| product_name |
|---|
| Canyon Hiking Boots |
| Canyon Life Jackets |
| Canyon Backpack |
| Canyon Water Filters |
| Canyon Trekking Poles |

```sql
SELECT COUNT(*) FROM bronze_products WHERE product_name LIKE 'Canyon%';
```

| COUNT(*) |
|---|
| 9 |

### Contains

```sql
SELECT product_name
FROM bronze_products
WHERE product_name LIKE '%Boot%';
```

| product_name |
|---|
| Canyon Hiking Boots |
| Cascade Hiking Boots |
| Ironpeak Hiking Boot |
| Alpine Hiking Boots |
| Foothill Hiking Boot |

`%Boot%` finds "Boot" anywhere in the string — beginning, middle, or
end — including both the singular ("Boot") and plural ("Boots") forms,
since the trailing `%` absorbs whatever comes after.

### LIKE is case-insensitive (for ASCII) — unlike `=`

This is the big one. Recall from module 2 that `=` is exact and
case-sensitive:

```sql
SELECT COUNT(*) FROM bronze_products WHERE category = 'footwear';
```

| COUNT(*) |
|---|
| 4 |

```sql
SELECT COUNT(*) FROM bronze_products WHERE category LIKE 'footwear';
```

| COUNT(*) |
|---|
| 8 |

Same literal pattern, `'footwear'`, no wildcards even used — but `=`
found only the 4 rows spelled exactly `footwear` (lowercase), while
`LIKE` found 8, because it also matched `FOOTWEAR` and `Footwear` and
any other casing of that exact same sequence of letters. This is a
genuinely useful trick for casing-messy data — but notice it *still*
doesn't catch every variant: it won't match `'Footwear '` (trailing
space) or `'Foot Wear'` (split into two words), since those aren't the
same sequence of characters, just differently-cased. `LIKE` fixes the
casing problem specifically; it doesn't fix spacing or spelling
differences. Full normalization of a column like this is Tier 2's job.

### The underscore wildcard: exactly one character

```sql
SELECT sku
FROM bronze_products
WHERE sku LIKE 'FOO-00__';
```

| sku |
|---|
| FOO-0001 |
| FOO-0016 |
| FOO-0019 |
| FOO-0020 |
| FOO-0023 |
| FOO-0025 |
| FOO-0029 |
| FOO-0044 |
| FOO-0062 |
| FOO-0065 |
| FOO-0069 |
| FOO-0087 |
| FOO-0099 |

13 rows total. `FOO-00__` matches `FOO-00` followed by exactly two
more characters — so `FOO-0001` and `FOO-0099` both match (2 digits
after `FOO-00`), but a hypothetical `FOO-00123` (3 digits) would not,
since `_` matches *exactly* one character each, no more, no less.
Compare this to `FOO-00%`, which would match any number of trailing
characters — `_` and `%` are both wildcards, but they're not
interchangeable.

## Common mistakes

- **Forgetting the wildcard entirely.** `WHERE product_name LIKE
  'Canyon'` (no `%`) behaves just like `=` — an exact match, just
  case-insensitive. If you meant "starts with Canyon," you need
  `'Canyon%'`.
- **Confusing `%` and `_`.** `%` is "any number of characters
  (including zero)"; `_` is "exactly one character." Swapping them
  gives you a pattern that's too loose or too strict.
- **Assuming LIKE fixes all messiness.** As shown above, LIKE only
  smooths over *case* differences — it does nothing about extra
  whitespace, spelled-out `and` vs `&`, or split words like `Foot
  Wear`. Those need real string cleaning, coming in Tier 2.
- **Forgetting quotes.** Like any text literal, `LIKE` patterns need
  single quotes: `LIKE 'Canyon%'`, not `LIKE Canyon%`.

## Key takeaways

- `LIKE` matches text against a pattern using `%` (any number of
  characters) and `_` (exactly one character).
- `LIKE` is case-insensitive for ASCII text, unlike `=` — a genuinely
  useful tool against messy casing, but not a substitute for real
  cleaning.
- `LIKE` handles casing differences; it does not handle whitespace,
  spelling, or word-order differences — full standardization of a
  column like `category` is a Tier 2 topic.

---

<!-- nav -->
Previous: [6. Basic Aggregate Functions](06-basic-aggregate-functions.md). Next: [8. DISTINCT and Duplicates](08-distinct-and-duplicates.md).
<!-- /nav -->
