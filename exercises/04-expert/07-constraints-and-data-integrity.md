# Exercises: Constraints and Data Integrity

Exercise 1 is read-only. All others create tables/indexes and must run
against your own scratch copy:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Confirm the real orphan-FK counts yourself

Don't take the facts sheet's word for it — run the two `NOT EXISTS`
checks yourself against the real, shared database and confirm you get
103 orphan `customer_id` rows and 122 orphan `product_id` rows in
`bronze_sales`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_sales s
WHERE NOT EXISTS (SELECT 1 FROM bronze_customers c WHERE c.customer_id = s.customer_id);
```

```
103
```

```sql
SELECT COUNT(*) FROM bronze_sales s
WHERE NOT EXISTS (SELECT 1 FROM bronze_products p WHERE p.product_id = s.product_id);
```

```
122
```

Both match the facts sheet exactly.

</details>

---

### 2. Build a minimal FK-constrained pair, and prove it blocks an orphan

On your scratch copy, create `ex_cust (id INTEGER PRIMARY KEY)` and
`ex_orders (id INTEGER PRIMARY KEY, cust_id INTEGER, FOREIGN KEY
(cust_id) REFERENCES ex_cust(id))`. Insert one valid customer.
Enable `PRAGMA foreign_keys = ON;`, then try to insert an order
referencing a `cust_id` that doesn't exist. What happens?

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_cust (id INTEGER PRIMARY KEY);
CREATE TABLE ex_orders (id INTEGER PRIMARY KEY, cust_id INTEGER, FOREIGN KEY (cust_id) REFERENCES ex_cust(id));
INSERT INTO ex_cust VALUES (1);

PRAGMA foreign_keys = ON;
INSERT INTO ex_orders VALUES (101, 888);
```

```
Runtime error near line 2: FOREIGN KEY constraint failed (19)
```

Rejected immediately — `cust_id = 888` doesn't exist in `ex_cust`.
Exactly the class of write that produced 103 orphan rows in the real
`bronze_sales` table, which has no such constraint.

</details>

---

### 3. Prove `PRAGMA foreign_keys` has to be explicitly turned on

Repeat Exercise 2's setup, but this time run `PRAGMA foreign_keys =
OFF;` (SQLite's actual default) before the orphan insert. Does it
succeed? What does this tell you about a schema that *declares* a
`FOREIGN KEY` but whose application never sets this pragma?

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_cust2 (id INTEGER PRIMARY KEY);
CREATE TABLE ex_orders2 (id INTEGER PRIMARY KEY, cust_id INTEGER, FOREIGN KEY (cust_id) REFERENCES ex_cust2(id));
INSERT INTO ex_cust2 VALUES (1);

PRAGMA foreign_keys = OFF;
INSERT INTO ex_orders2 VALUES (100, 999);
SELECT * FROM ex_orders2;
```

```
id   cust_id
---  -------
100  999
```

The insert succeeds even though `cust_id = 999` doesn't exist in
`ex_cust2` — with `PRAGMA foreign_keys = OFF;` (or simply never set,
since `OFF` is SQLite's default), the `FOREIGN KEY` clause is parsed
and stored in the schema but never actually checked. A schema that
*declares* foreign keys gives you no real protection unless every
connection that writes to it also enables `PRAGMA foreign_keys = ON;`
— declaring the constraint and enforcing it are two separate steps in
SQLite, unlike most other engines where declaring it is enough.

</details>

---

### 4. Tie a CHECK constraint to a real bronze problem

Per the facts sheet, `bronze_sales.quantity` has 359 negative rows and
212 zero rows (out of 12,000) — neither should logically be possible
for a normal sale (returns aside, which this dataset represents with
negative quantities on purpose, but a stricter production system might
model returns as a separate flag instead of a raw negative number).
On your scratch copy, build a `demo_line_items(quantity INTEGER CHECK
(quantity > 0))` table and confirm it rejects both a negative and a
zero quantity.

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE demo_line_items (quantity INTEGER CHECK (quantity > 0));
INSERT INTO demo_line_items VALUES (-3);
```

```
Error: stepping, CHECK constraint failed: quantity > 0 (19)
```

```sql
INSERT INTO demo_line_items VALUES (0);
```

```
Error: stepping, CHECK constraint failed: quantity > 0 (19)
```

Both rejected. Every one of the 359 + 212 = 571 problematic rows in
real `bronze_sales` would have been refused at insert time by this
single-line constraint.

</details>

---

### 5. Try to add a UNIQUE index directly to already-messy real data

This is the trickiest and most realistic exercise in this set. On
your scratch copy, try to create a `UNIQUE` index directly on
`bronze_customers(email)` — no cleaning first. Does it succeed? If
not, use the error to find the actual duplicate email(s) causing the
failure.

<details>
<summary>Show solution</summary>

```sql
CREATE UNIQUE INDEX idx_unique_email_raw ON bronze_customers(email);
```

```
Error: stepping, UNIQUE constraint failed: bronze_customers.email (19)
```

It fails immediately — bronze_customers already has real, exact
(case-identical) duplicate emails, independent of the intentional
near-duplicate customers (571–600) the data dictionary describes.
Find them:

```sql
SELECT email, COUNT(*) FROM bronze_customers
WHERE email IS NOT NULL AND email != ''
GROUP BY email HAVING COUNT(*) > 1;
```

```
email                              COUNT(*)
---------------------------------  --------
christopher.harris@hotmail.com     2
erica.reed@outlook.com             2
logan.williams@oakmail.com         2
theodore.davis@outlook.com         2
tyrone.larsen@oakmail.com          2
```

This is the central lesson of constraints applied to *existing* messy
data: a `UNIQUE` constraint can't be bolted onto a table that already
violates it — SQLite (like every engine) refuses to create it until
the underlying duplicates are resolved. In a real migration, you'd
have to decide what "resolved" means (merge the rows? keep the
newest? flag both?) *before* the constraint can be added — a
constraint enforces going forward, it doesn't retroactively clean up
what's already there (this echoes the lesson's point directly).

</details>

---

### 6. An expression-based UNIQUE index catches even more duplicates

Exercise 5 only found *exact*-string duplicates. The data dictionary
also documents 30 *near*-duplicate customers (IDs 571–600) whose
emails differ only in casing/whitespace but are equal after
`LOWER(TRIM(email))`. Try creating a `UNIQUE` index on
`LOWER(TRIM(email))` instead of the raw column, and use the error (or
a direct query) to find one specific near-duplicate pair.

<details>
<summary>Show solution</summary>

```sql
CREATE UNIQUE INDEX idx_unique_email_norm ON bronze_customers(LOWER(TRIM(email)));
```

```
Error: stepping, UNIQUE constraint failed: index 'idx_unique_email_norm' (19)
```

Still fails — and would keep failing even after fixing Exercise 5's
exact-match duplicates, because normalized duplicates are a superset
of exact-string duplicates. Find a specific pair directly:

```sql
SELECT c1.customer_id AS orig_id, c1.email AS orig_email,
       c2.customer_id AS dup_id, c2.email AS dup_email
FROM bronze_customers c1
JOIN bronze_customers c2
  ON LOWER(TRIM(c1.email)) = LOWER(TRIM(c2.email))
 AND c1.customer_id < c2.customer_id
WHERE c2.customer_id BETWEEN 571 AND 600
LIMIT 3;
```

```
orig_id  orig_email                  dup_id  dup_email
-------  --------------------------  ------  --------------------------
9        cathy.romero@oakmail.com    571     CATHY.ROMERO@OAKMAIL.COM
17       john.ramsey@icloud.com      573     JOHN.RAMSEY@ICLOUD.COM
19       sharon.green@yahoo.com      574     SHARON.GREEN@YAHOO.COM
```

Customer 9 and customer 571 are the same real person, entered twice —
exactly the "signed up twice" scenario the data dictionary describes.
An expression-based `UNIQUE` index on the *normalized* email would
have refused the second signup outright, at the moment it was
inserted — a stronger, earlier-acting version of the deduplication
work a `ROW_NUMBER()`-based query has to do after the fact (a
technique covered elsewhere in this course). This is the clearest
illustration in this whole module of the tier's central theme: every
constraint you've practiced here is a rule that, applied from the
start, would have made an entire category of bronze's messiness
structurally impossible to create.

</details>
