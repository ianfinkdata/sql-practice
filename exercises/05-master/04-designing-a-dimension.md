# Exercises: 4. Designing a Dimension

Work against `project/oakhaven.db`. Read-only — every query below is a
`SELECT`. None of these modify `dim_customer.sql` or any other gold
object; they're all standalone `SELECT`s exploring what a fix *would*
look like.

---

### 1. Confirm the near-duplicate block

The data dictionary claims `customer_id` 571–600 are the intentional
near-duplicate rows. Confirm the block's exact boundaries and size,
and confirm none of them are missing an email (a prerequisite for the
email-based dedup approach used in later exercises here).

<details>
<summary>Show solution</summary>

```sql
SELECT MIN(customer_id), MAX(customer_id), COUNT(*) AS total,
       SUM(CASE WHEN email IS NULL OR email = '' THEN 1 ELSE 0 END) AS null_or_empty_email
FROM dim_customer
WHERE customer_id >= 571;
```

| MIN(customer_id) | MAX(customer_id) | total | null_or_empty_email |
|---|---|---|---|
| 571 | 600 | 30 | 0 |

Exactly 30 rows, `customer_id` 571 through 600, all with a usable
email — confirming the block described in
`project/docs/data_dictionary.md`.

</details>

---

### 2. Count how many email groups actually contain a duplicate

Rather than looking at one example pair, find how many distinct
normalized email addresses appear on more than one row of
`dim_customer`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS groups_with_dupes
FROM (
    SELECT LOWER(TRIM(email)) AS ek
    FROM dim_customer
    WHERE email IS NOT NULL AND email <> ''
    GROUP BY LOWER(TRIM(email))
    HAVING COUNT(*) > 1
);
```

| groups_with_dupes |
|---|
| 29 |

29 distinct email addresses each appear on exactly two rows (you can
confirm no group has 3+ by checking `HAVING COUNT(*) > 2`, which
returns zero rows). That's 29 pairs — 58 rows total involved in a
duplicate — which is one fewer *pair* than the 30 near-duplicate
`customer_id`s in the 571–600 block. Exercise 5 tracks down why.

</details>

---

### 3. Preview the full dedup: how many rows survive?

Apply the `ROW_NUMBER() OVER (PARTITION BY LOWER(TRIM(email)) ...)`
pattern across the *entire* `dim_customer` table (not just one email),
keeping the earliest signup per normalized email. How many rows would
survive, and how does that compare to the original 600?

<details>
<summary>Show solution</summary>

```sql
WITH ranked AS (
    SELECT customer_id,
           ROW_NUMBER() OVER (
               PARTITION BY LOWER(TRIM(email))
               ORDER BY signup_date ASC, customer_id ASC
           ) AS rn
    FROM dim_customer
    WHERE email IS NOT NULL AND email <> ''
)
SELECT COUNT(*) AS rows_kept FROM ranked WHERE rn = 1;
```

| rows_kept |
|---|
| 536 |

536 rows would survive out of the 565 rows that have a usable email
(600 total minus 35 with `NULL`/empty email) — a reduction of 29 rows,
matching Exercise 2's count of 29 duplicate email groups exactly (one
"extra" row removed per group). Note this dedup pass only ever
considers rows with a non-empty email, by construction (the `WHERE`
clause) — any customer with a missing email is left completely alone
by an email-based dedup strategy, duplicate or not.

</details>

---

### 4. Find a near-duplicate pair that email-based dedup would *miss*

Exercise 2 found 29 duplicate pairs among the 30 near-duplicate
`customer_id`s (571–600). Find the one near-duplicate row (571–600)
whose email does **not** match any row in the base range (1–570) —
i.e., dedup-by-email would never catch it, even though the data
dictionary says it should be a near-duplicate of some base customer.

<details>
<summary>Show solution</summary>

```sql
SELECT d.customer_id AS dup_id, d.email,
       (SELECT COUNT(*) FROM dim_customer b
        WHERE b.customer_id < 571 AND LOWER(TRIM(b.email)) = LOWER(TRIM(d.email))) AS matching_base_rows
FROM dim_customer d
WHERE d.customer_id >= 571
ORDER BY d.customer_id;
```

Scanning the results, `customer_id = 572` (`cindy.robinson@icloud.com`)
is the one row with `matching_base_rows = 0` — every other row in
571–600 matches exactly one base-range row on normalized email.

```sql
SELECT customer_id, email FROM dim_customer
WHERE LOWER(TRIM(email)) = 'cindy.robinson@icloud.com';
```

| customer_id | email |
|---|---|
| 572 | cindy.robinson@icloud.com |

Only one row in the entire table has this email — its intended "base"
counterpart apparently has a `NULL` or empty email in this build (an
independently regenerated field, per the data dictionary), which
breaks the email-based matching entirely. This is a genuine limitation
of the dedup approach from Exercise 3, worth internalizing: **matching
on any single field is only as reliable as that field's own
completeness.** A production MDM (master data management) process
would typically need a fuzzier or multi-field matching strategy (name
+ phone + address similarity, not just exact email equality) to catch
cases like this one.

</details>

---

### 5. Design judgment: what would you need to safely dedupe `dim_customer` for real?

This one has no single query — it's a design exercise. Using what
you've found in Exercises 1–4, write out (as SQL comments or plain
text) the steps you'd need, in order, to actually deduplicate
`dim_customer` in a way that's safe for `fact_sales` to keep working
correctly. Then write one query that identifies the specific risk your
plan has to handle: rows in `fact_sales` whose `customer_id` would be
one of the 29 "losing" duplicate rows from Exercise 3, i.e., orders
that would become orphaned if you just deleted the losing rows without
redirecting their foreign keys.

<details>
<summary>Show solution</summary>

A safe plan needs, at minimum:

1. **Decide and document a conflict-resolution rule** (e.g., "keep the
   row with the earliest `signup_date`; on a tie, keep the lower
   `customer_id`") — this is what Exercise 3's `ROW_NUMBER()` ordering
   already encodes, but it should be a deliberate business decision,
   not just whatever ordering happened to be convenient.
2. **Build a `customer_id` crosswalk** mapping every "losing"
   `customer_id` to its "winning" survivor's `customer_id`.
3. **Redirect `fact_sales.customer_id`** for any row currently pointing
   at a losing ID, using the crosswalk, *before* removing the losing
   rows from the dimension.
4. **Only then** filter the dimension down to `rn = 1` per
   Exercise 3.
5. Accept that email-only matching (Exercise 4) will miss some real
   near-duplicates — document that as a known limitation, not a
   solved problem.

The query that shows why step 3 matters — how many `fact_sales` rows
currently reference a `customer_id` that Exercise 3's dedup would
remove:

```sql
WITH ranked AS (
    SELECT customer_id,
           ROW_NUMBER() OVER (
               PARTITION BY LOWER(TRIM(email))
               ORDER BY signup_date ASC, customer_id ASC
           ) AS rn
    FROM dim_customer
    WHERE email IS NOT NULL AND email <> ''
),
losing_ids AS (
    SELECT customer_id FROM ranked WHERE rn > 1
)
SELECT COUNT(*) AS fact_rows_at_risk_of_orphaning
FROM fact_sales f
JOIN losing_ids l ON f.customer_id = l.customer_id;
```

| fact_rows_at_risk_of_orphaning |
|---|
| 584 |

584 order lines in `fact_sales` currently reference one of the 29
"losing" `customer_id` values. Every one of those rows would silently
lose its ability to join to `dim_customer` the moment the losing
dimension rows were deleted without a crosswalk redirect first — which
is exactly the kind of quiet, hard-to-detect breakage that makes "just
delete the duplicates" the wrong first instinct for fixing a dimension
like this.

</details>
