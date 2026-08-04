# 8. Writing Your First Silver View


<!-- nav -->
Previous: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md). Next: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md).
<!-- /nav -->

## The idea — what "silver" is for

Oakhaven's database is organized as a **medallion architecture**, a common
pattern in real data warehouses: raw data flows through named layers, each
one cleaner and more trustworthy than the last.

- **Bronze** — raw, as-ingested data. Exactly what came in, messiness and
  all. `bronze_customers`, `bronze_sales`, etc. No primary keys, no
  cleaning, no opinions.
- **Silver** — cleaned, standardized, and *derived* data. Same grain as
  bronze (one row per bronze row — silver doesn't delete or merge rows
  here), but every column has been normalized to one consistent
  representation.
- **Gold** — business-ready views: dimensions, facts, aggregates. Built on
  top of silver, never on top of bronze directly.

This module is about the middle layer. Silver's job has a very specific,
narrow contract, worth stating precisely because it's easy to overreach:

**Silver cleans, standardizes, and derives. It does not delete rows, and
it does not silently hide problems it can't fully resolve.** A phone
number in five different formats becomes one format. A boolean spelled 11
different ways becomes a real `0`/`1`. A date in three formats becomes one
ISO format. But a row with an unresolvable problem — an orphan foreign
key, a `NULL` that can't be safely defaulted — stays in the output,
flagged if possible, rather than vanishing. Silver's whole value is that
you can trust it *completely* for what it does clean, while still being
honest about what it couldn't.

## Worked example: dissecting `silver/silver_customers.sql`

Full contents (verified against the live view definition):

```sql
DROP VIEW IF EXISTS silver_customers;
CREATE VIEW silver_customers AS
WITH state_map(name_key, abbr) AS (
    VALUES
        ('alabama', 'AL'), ('alaska', 'AK'), ('arizona', 'AZ'), ('arkansas', 'AR'),
        ('california', 'CA'), ('colorado', 'CO'), ('connecticut', 'CT'), ('delaware', 'DE'),
        -- ... all 50 states ...
        ('calif.', 'CA'), ('fla.', 'FL'), ('mass.', 'MA'), ('penn.', 'PA'), ('wash.', 'WA')
),
base AS (
    SELECT
        c.customer_id,
        TRIM(REPLACE(REPLACE(TRIM(c.first_name), '  ', ' '), '  ', ' ')) AS fn_collapsed,
        TRIM(REPLACE(REPLACE(TRIM(c.last_name), '  ', ' '), '  ', ' ')) AS ln_collapsed,
        NULLIF(TRIM(LOWER(c.email)), '') AS email,
        c.phone AS phone_raw,
        NULLIF(TRIM(c.state), '') AS state_raw,
        c.signup_date AS signup_date_raw,
        c.is_active AS is_active_raw,
        c.customer_segment AS segment_raw
    FROM bronze_customers c
)
SELECT
    customer_id,
    UPPER(SUBSTR(fn_collapsed, 1, 1)) || LOWER(SUBSTR(fn_collapsed, 2)) AS first_name,
    -- ... last_name, full_name follow the same pattern ...
    email,
    CASE
        WHEN phone_raw IS NULL OR TRIM(phone_raw) = '' THEN NULL
        WHEN phone_raw LIKE '(___) ___-____'
            THEN '(' || substr(phone_raw, 2, 3) || ') ' || substr(phone_raw, 7, 3) || '-' || substr(phone_raw, 11, 4)
        WHEN phone_raw LIKE '___-___-____'
            THEN '(' || substr(phone_raw, 1, 3) || ') ' || substr(phone_raw, 5, 3) || '-' || substr(phone_raw, 9, 4)
        -- ... more format branches ...
        WHEN phone_raw GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
            THEN '(' || substr(phone_raw, 1, 3) || ') ' || substr(phone_raw, 4, 3) || '-' || substr(phone_raw, 7, 4)
        ELSE phone_raw
    END AS phone,
    COALESCE(
        (SELECT abbr FROM state_map WHERE name_key = LOWER(state_raw)),
        (SELECT abbr FROM state_map WHERE abbr = UPPER(state_raw))
    ) AS state,
    -- ... signup_date parsing (same 3-format pattern seen elsewhere) ...
    CASE
        WHEN LOWER(TRIM(is_active_raw)) IN ('y', 'yes', 'true', '1') THEN 1
        WHEN LOWER(TRIM(is_active_raw)) IN ('n', 'no', 'false', '0') THEN 0
        ELSE NULL
    END AS is_active,
    CASE LOWER(TRIM(segment_raw))
        WHEN 'retail' THEN 'Retail'
        WHEN 'wholesale' THEN 'Wholesale'
        WHEN 'vip' THEN 'VIP'
        ELSE NULL
    END AS customer_segment
FROM base;
```

Four techniques worth pulling out individually — each one a reusable
pattern, not just a one-off fix:

### 1. Phone reformatting by shape-matching, not by re-parsing digits

Rather than stripping all non-digit characters and reassembling, the view
matches each raw value's *shape* with `LIKE`/`GLOB` patterns —
`'(___) ___-____'`, `'___-___-____'`, `'___.___.____'`, `'+1 ___ ___
____'`, or 10 bare digits — and extracts fixed-position substrings for
each. This only works because the data dictionary guarantees every
non-null phone value is exactly 3-3-4 digit groups; a format-based
approach like this is a bet on that guarantee holding, and it's a
reasonable bet here specifically because it's documented. Verified
before/after:

```sql
SELECT b.customer_id, b.phone AS raw_phone, s.phone AS clean_phone
FROM bronze_customers b JOIN silver_customers s ON s.customer_id = b.customer_id
WHERE b.phone IS NOT NULL
ORDER BY b.customer_id LIMIT 8;
```

| customer_id | raw_phone | clean_phone |
|---|---|---|
| 2 | 4278193651 | (427) 819-3651 |
| 3 | +1 363 326 9140 | (363) 326-9140 |
| 4 | (941) 660-5364 | (941) 660-5364 |
| 5 | 472-676-3094 | (472) 676-3094 |
| 6 | (936) 218-7125 | (936) 218-7125 |
| 7 | +1 378 520 9025 | (378) 520-9025 |
| 8 | 517-252-2676 | (517) 252-2676 |
| 9 | 4286531983 | (428) 653-1983 |

### 2. State normalization via a `VALUES`-based lookup table

`state_map` is a CTE built entirely from a `VALUES` list — no source
table, just a literal 2-column mapping of every full state name (and five
special dotted abbreviations: `Calif.`, `Fla.`, `Mass.`, `Penn.`, `Wash.`)
to its canonical 2-letter code. The main query then does a `COALESCE` of
two correlated-subquery lookups: try matching the raw value as a full name
first, then try it as an abbreviation already in the right form. This
pattern — a `VALUES`-based mapping CTE plus a lookup — generalizes to any
"normalize a field from a small fixed vocabulary" problem, and keeps the
mapping data visible and editable right in the SQL rather than buried in
`CASE` branches. Verified:

```sql
SELECT b.customer_id, b.state AS raw_state, s.state AS clean_state
FROM bronze_customers b JOIN silver_customers s ON s.customer_id = b.customer_id
WHERE b.state IN ('Calif.','Fla.','Mass.','Penn.','Wash.')
LIMIT 6;
```

| customer_id | raw_state | clean_state |
|---|---|---|
| 6 | Calif. | CA |
| 40 | Penn. | PA |
| 50 | Mass. | MA |
| 143 | Calif. | CA |
| 223 | Mass. | MA |
| 238 | Penn. | PA |

### 3. Mixed-boolean coalescing to a real 0/1

`bronze_customers.is_active` is `TEXT`, drawn from an 11-value pool
including `NULL` itself (`Y`, `y`, `yes`, `true`, `1`, `N`, `n`, `no`,
`false`, `0`, and literal `NULL`). The `CASE` normalizes every "truthy"
spelling to integer `1`, every "falsy" spelling to `0`, and — critically —
anything that doesn't match either list (including bronze `NULL`) falls
through to `ELSE NULL`, an honest "unknown," rather than being guessed at.
Verified — every raw/clean combination that actually occurs, with counts:

```sql
SELECT b.is_active AS raw, s.is_active AS clean, COUNT(*)
FROM bronze_customers b JOIN silver_customers s ON s.customer_id = b.customer_id
GROUP BY b.is_active, s.is_active ORDER BY s.is_active;
```

| raw | clean | COUNT(*) |
|---|---|---|
| *(null)* | *(null)* | 31 |
| `0` | 0 | 18 |
| `N` | 0 | 29 |
| `false` | 0 | 9 |
| `n` | 0 | 21 |
| `no` | 0 | 14 |
| `1` | 1 | 103 |
| `Y` | 1 | 101 |
| `true` | 1 | 93 |
| `y` | 1 | 92 |
| `yes` | 1 | 89 |

Every one of the 11 raw spellings lands on exactly the right side — and
the raw `NULL` group (31 rows) stays `NULL` on the clean side too, rather
than being defaulted to `0` or `1` by guesswork.

### 4. Near-duplicate awareness — deliberately *not* solved here

The header comment on the real file is explicit about a boundary:
*"Does NOT deduplicate the intentional near-duplicate people — that's left
for a dedicated ROW_NUMBER lesson."* `silver_customers` still returns 600
rows, the same as `bronze_customers` — cleaning is applied per-row, but no
row is dropped or merged, even though Module 2 showed that ~29-30 of these
600 rows are the same underlying person appearing twice. That's a
deliberate, documented scope boundary, not an oversight: deduplication is
a *judgment call* (which row is "canonical"? do you merge fields or pick
one?) that belongs in a purpose-built step, not silently baked into a
general-purpose cleaning view. This is the silver-layer contract in
action: clean and standardize, but don't quietly make consequential
decisions a downstream consumer wasn't told about.

## Your turn: clean a column silver_customers.sql doesn't touch

Every technique above lives in `silver_customers.sql`, scoped to
`bronze_customers`. To practice the pattern yourself, look at a *different*
table: `bronze_employees.department` and `bronze_employees.region` have
the exact same casing-inconsistency problem (`MANAGEMENT`, `Management`,
`management` all meaning the same thing), verified from the raw data:

```sql
SELECT DISTINCT department FROM bronze_employees ORDER BY 1;
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

**Write a plain `SELECT`** (not a `CREATE VIEW` — never run DDL against
the shared `oakhaven.db`) that normalizes `department` to its 4 canonical
forms (`Sales`, `Support`, `Warehouse`, `Management`), using the same
`LOWER(TRIM(...))`-key-then-`CASE` technique `silver_customers.sql` uses
for `customer_segment`. Then do the same for `region` (canonical forms:
`West`, `East`, `Central`, `South`, `Northeast`). Try it before checking
the exercises file for this module — the point is building the muscle
memory of writing the `CASE` yourself, not reading someone else's.

## Common mistakes

- **Deleting rows in a silver view because they look wrong.** Silver's job
  is to clean what it can and be honest about what it can't — not to
  quietly filter out anything inconvenient. If bronze has 600 rows,
  silver_customers has 600 rows too.
- **Guessing at ambiguous values instead of returning `NULL`.** The
  `is_active` `CASE` above explicitly falls through to `NULL` for anything
  unrecognized, rather than defaulting everything unmatched to `0`
  (or `1`) — a default here would be a silent, unjustified assumption
  baked permanently into "clean" data.
- **Assuming a format-matching approach (like the phone reformat) is safe
  without checking the guarantee it depends on.** The phone `LIKE`/`GLOB`
  patterns work *because* the data dictionary guarantees a fixed 3-3-4
  digit shape for every non-null value — that assumption is exactly what
  to re-verify first if this pattern is reused against a different,
  unverified data source.
- **Solving deduplication inside a general cleaning view.** As shown
  above, `silver_customers.sql` explicitly punts near-duplicate resolution
  to a dedicated step — bundling it in here would hide a significant,
  debatable decision inside what's supposed to be uncontroversial cleaning.

## Key takeaways

- Bronze → silver → gold: bronze is raw, silver cleans/standardizes/derives
  without deleting rows or hiding unresolved problems, gold is
  business-ready.
- `silver_customers.sql` demonstrates four reusable silver-layer
  techniques: shape-based reformatting (phone), a `VALUES`-based lookup
  CTE (state), exhaustive `CASE`-based boolean coalescing with an honest
  `NULL` fallback (is_active), and deliberately deferring a judgment call
  (deduplication) to a dedicated step rather than making it silently.
- Silver views preserve bronze's row count and grain — cleaning happens
  per-row, not by filtering.
- The same casing-normalization technique used for `customer_segment`
  applies directly to `bronze_employees.department`/`region` — practice it
  there before checking this module's exercises.

---

<!-- nav -->
Previous: [7. The Date-Spine Pattern](07-the-date-spine-pattern.md). Next: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md).
<!-- /nav -->
