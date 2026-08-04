# Cleaning Text: TRIM, UPPER, LOWER, REPLACE


<!-- nav -->
Previous: [CASE Expressions](05-case-expressions.md). Next: [COALESCE and NULLIF](07-coalesce-and-nullif.md).
<!-- /nav -->

## The idea

Module 3 showed `bronze_products.category` splitting into 40 raw
groups where only 8 real categories exist. That wasn't a `GROUP BY`
bug — `GROUP BY` was working correctly on dirty input. The fix lives
one layer earlier: clean the text *before* you group, filter, or join
on it. Four small functions do almost all of that work:

- `TRIM(text)` — strips leading/trailing whitespace (a stray trailing
  space is invisible in most result viewers but very real to `=`).
- `UPPER(text)` / `LOWER(text)` — normalizes casing.
- `REPLACE(text, find, replacement)` — swaps every occurrence of one
  substring for another.

None of these are exotic. The skill here is chaining them in the
right order and recognizing what they can't fix on their own.

## Why it matters

This directly resolves Module 3's pain. `bronze_products.category`
has 40 raw string variants for 8 real categories — different casing,
trailing spaces, `and` vs `&`, and one split compound word (`Foot
Wear` vs `Footwear`). `bronze_customers.state` is worse: full state
names, 2-letter abbreviations, lowercase versions of both, dotted
abbreviations (`Calif.`, `Fla.`) — 190 distinct raw strings for what
should be at most 50-something real states. Any report grouped or
filtered on either raw column, as-is, is wrong. You're about to fix
one of them completely and make real, measured progress on the other.

## Syntax

```sql
TRIM(text)                      -- strip leading/trailing whitespace
UPPER(text)                     -- to uppercase
LOWER(text)                     -- to lowercase
REPLACE(text, find, replacement) -- swap substrings
```

Chain them by nesting — inside out, the innermost function runs
first:

```sql
REPLACE(UPPER(TRIM(text)), 'find', 'replacement')
```

**Order matters.** `REPLACE` matches substrings case-sensitively.
`REPLACE(category, 'AND', '&')` will not touch `"and"` — you need
`UPPER` (or `LOWER`) applied *before* the `REPLACE` that depends on a
particular case, not after.

## Try it

**1. See the raw damage on `category`**

```sql
SELECT COUNT(DISTINCT category) FROM bronze_products;
```

| COUNT(DISTINCT category) |
|---|
| 40 |

**2. Step 1 of the fix: TRIM + UPPER collapses casing/spacing noise**

```sql
SELECT COUNT(DISTINCT TRIM(UPPER(category))) FROM bronze_products;
```

| COUNT(DISTINCT TRIM(UPPER(category))) |
|---|
| 11 |

40 → 11 just from stripping whitespace and normalizing case. Not done
yet — 11 groups remain for 8 real categories, because `AND` vs `&` and
`FOOT WEAR` vs `FOOTWEAR` are still different *substrings*, not just
different casing.

**3. Step 2: REPLACE ' AND ' with ' & ' — done in the right order**

```sql
SELECT COUNT(DISTINCT REPLACE(TRIM(UPPER(category)), ' AND ', ' & '))
FROM bronze_products;
```

| COUNT(...) |
|---|
| 9 |

11 → 9. `UPPER` ran first (inside the parentheses), so by the time
`REPLACE` looks for `' AND '` it's guaranteed to be uppercase already
— `Camping and Hiking`, `camping and hiking`, and `CAMPING AND HIKING`
all became `CAMPING AND HIKING` before `REPLACE` ever touched them.
Get the nesting order backwards — `REPLACE` before `UPPER` — and
lowercase `and` slips through untouched, because `REPLACE` only ever
matched the literal uppercase `AND`.

**4. Step 3: one more REPLACE for the split compound word**

```sql
SELECT COUNT(DISTINCT
  REPLACE(REPLACE(TRIM(UPPER(category)), ' AND ', ' & '), 'FOOT WEAR', 'FOOTWEAR')
) FROM bronze_products;
```

| COUNT(...) |
|---|
| 8 |

9 → 8. Exactly the 8 canonical categories from the data dictionary.
Full chain, and the cleaned `GROUP BY` it enables:

```sql
SELECT
  REPLACE(REPLACE(TRIM(UPPER(p.category)), ' AND ', ' & '), 'FOOT WEAR', 'FOOTWEAR') AS clean_category,
  COUNT(*) AS line_count,
  ROUND(SUM(s.quantity * s.unit_price), 2) AS rough_total
FROM bronze_sales s
JOIN bronze_products p ON s.product_id = p.product_id
GROUP BY clean_category
ORDER BY rough_total DESC;
```

| clean_category | line_count | rough_total |
|---|---|---|
| CLIMBING | 1858 | 1565035.72 |
| WINTER SPORTS | 1834 | 1408463.1 |
| APPAREL | 1556 | 1398826.64 |
| NUTRITION & HYDRATION | 1548 | 1327851.74 |
| FOOTWEAR | 1402 | 1211249.52 |
| ACCESSORIES | 1543 | 1068475.68 |
| CAMPING & HIKING | 1277 | 1024156.04 |
| WATER SPORTS | 860 | 818393.7 |

Eight real rows. Compare this to Module 3's version of the same
query — 25+ rows, revenue scattered across duplicate spellings of the
same category.

**5. `state` — real, partial progress, and an honest limit**

```sql
SELECT COUNT(DISTINCT state) FROM bronze_customers;
```

| COUNT(DISTINCT state) |
|---|
| 190 |

```sql
SELECT COUNT(DISTINCT TRIM(UPPER(state))) FROM bronze_customers;
```

| COUNT(DISTINCT TRIM(UPPER(state))) |
|---|
| 105 |

190 → 105 from `TRIM(UPPER(...))` alone — real progress, but nowhere
near "one row per state." Here's why, spelled out for California
specifically:

```sql
SELECT DISTINCT state, TRIM(UPPER(state)) AS cleaned
FROM bronze_customers
WHERE state IN ('CA', 'ca', 'Calif.', 'California', 'california')
ORDER BY state;
```

| state | cleaned |
|---|---|
| CA | CA |
| Calif. | CALIF. |
| California | CALIFORNIA |
| ca | CA |
| california | CALIFORNIA |

`TRIM`/`UPPER` correctly merges `CA` and `ca` into one group, and
`California`/`california` into another — but `CA`, `Calif.`, and
`California` are three *different substrings* referring to the same
state, and no amount of case/whitespace normalization can merge them.
That needs an explicit mapping (a `CASE` expression with one branch
per state, or a lookup table) — reasonable groundwork for later tiers,
not a today problem. The honest takeaway: `TRIM`/`UPPER`/`REPLACE`
solve whitespace-and-casing messiness completely, and *substring*
messiness (`&` vs `and`, split words) partially, with targeted
`REPLACE` calls — but they don't solve "different words for the same
thing" (abbreviation vs. full name) on their own.

## Common mistakes

- **Wrong nesting order for case-sensitive `REPLACE`.** As shown
  above: normalize case *first*, then `REPLACE` a case-specific
  substring. `REPLACE(category, ' and ', ' & ')` alone misses
  `' AND '` and `' And '` variants entirely.
- **Trimming only one side, or forgetting to trim at all.** A string
  that "looks" identical in a table viewer (`'ACCESSORIES'` vs
  `'ACCESSORIES '`) will not `=`-match or `GROUP BY`-merge without
  `TRIM`. This is invisible until you specifically check `LENGTH()` or
  count distinct values.
- **Assuming `UPPER`/`LOWER`/`TRIM`/`REPLACE` are a complete cleaning
  solution.** They fix casing, whitespace, and known substring swaps —
  they cannot merge `CA` and `California`, or catch a typo. Know where
  the boundary is (see the `state` example above) rather than trusting
  a chain of these functions to fully normalize everything.
- **Cleaning in the `SELECT` list but forgetting to also clean in
  `WHERE`/`GROUP BY`/`JOIN ON`.** If you filter `WHERE category =
  'Climbing'` against the raw column, you'll only match one of the 6+
  raw variants that mean "Climbing" — the same cleaning expression
  needs to be applied wherever the column is compared, not just where
  it's displayed.

## Key takeaways

- `TRIM`, `UPPER`/`LOWER`, and `REPLACE` chain together (nested,
  innermost-first) to progressively normalize messy text.
- `REPLACE` is case-sensitive — normalize case before replacing a
  case-specific substring, or the replacement silently misses variants.
- On Oakhaven's `category`: 40 raw variants → 11 after
  `TRIM(UPPER(...))` → 9 after fixing `AND`/`&` → 8 (fully clean) after
  fixing the split `FOOT WEAR` compound.
- On `state`: 190 → 105 with the same technique — real progress, but
  abbreviation-vs-full-name pairs (`CA` / `California`) need an
  explicit mapping these functions alone can't provide.
- Apply the same cleaning expression everywhere the column is
  compared — `SELECT`, `WHERE`, `GROUP BY`, and `JOIN ON` alike —  not
  just where it's displayed.

---

<!-- nav -->
Previous: [CASE Expressions](05-case-expressions.md). Next: [COALESCE and NULLIF](07-coalesce-and-nullif.md).
<!-- /nav -->
