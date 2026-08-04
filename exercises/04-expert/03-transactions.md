# Exercises: Transactions

Every exercise here writes data — work against your own scratch copy
for all of them, never `project/oakhaven.db`:

```bash
cp project/oakhaven.db /tmp/my_scratch.db
sqlite3 /tmp/my_scratch.db
```

---

### 1. Baseline count

Before touching anything, count how many `bronze_sales` rows have
`order_status = 'Cancelled'`. You'll use this number to verify a
rollback in the next exercise.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_sales WHERE order_status = 'Cancelled';
```

```
1031
```

</details>

---

### 2. Delete inside a transaction, then undo it

Start a transaction, delete every `bronze_sales` row with
`order_status = 'Cancelled'`, confirm (mid-transaction) that they're
gone, then `ROLLBACK` and confirm they're back.

<details>
<summary>Show solution</summary>

```sql
BEGIN;
DELETE FROM bronze_sales WHERE order_status = 'Cancelled';
SELECT COUNT(*) AS remaining_cancelled FROM bronze_sales WHERE order_status = 'Cancelled';
ROLLBACK;
SELECT COUNT(*) AS after_rollback FROM bronze_sales WHERE order_status = 'Cancelled';
```

```
remaining_cancelled
--------------------
0

after_rollback
--------------
1031
```

Mid-transaction, all 1031 rows are gone (`remaining_cancelled = 0`).
After `ROLLBACK`, all 1031 are back — matching Exercise 1's baseline
exactly.

</details>

---

### 3. Commit an update and confirm it's permanent

Start a transaction, set `is_discontinued = 'Y'` for products 1, 2,
and 3, commit, then query again (as if in a brand-new session) to
confirm the change persisted.

<details>
<summary>Show solution</summary>

```sql
BEGIN;
UPDATE bronze_products SET is_discontinued = 'Y' WHERE product_id IN (1,2,3);
SELECT product_id, is_discontinued FROM bronze_products WHERE product_id IN (1,2,3);
COMMIT;
SELECT product_id, is_discontinued FROM bronze_products WHERE product_id IN (1,2,3);
```

```
product_id  is_discontinued
----------  ---------------
1           Y
2           Y
3           Y

product_id  is_discontinued
----------  ---------------
1           Y
2           Y
3           Y
```

Same result before and after `COMMIT` in this case (nothing else
touched these rows in between) — the point is that after `COMMIT`,
there's no `ROLLBACK` that could undo it anymore; the change is final.

</details>

---

### 4. Undo a mistaken update with ROLLBACK

Create a small `ex_inventory` table (`product_id INTEGER, qty INTEGER
CHECK (qty >= 0)`) with two rows: `(1, 10)` and `(2, 5)`. Inside a
transaction, subtract 3 from product 1's quantity, confirm the change,
then decide it was a mistake and `ROLLBACK`. Confirm product 1 is back
to 10.

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_inventory (product_id INTEGER, qty INTEGER CHECK (qty >= 0));
INSERT INTO ex_inventory VALUES (1, 10), (2, 5);
BEGIN;
UPDATE ex_inventory SET qty = qty - 3 WHERE product_id = 1;
SELECT * FROM ex_inventory;
ROLLBACK;
SELECT * FROM ex_inventory;
```

```
product_id  qty
----------  ---
1           7
2           5

product_id  qty
----------  ---
1           10
2           5
```

</details>

---

### 5. A CHECK failure does NOT automatically roll back the whole transaction — verify it yourself

This is a genuine SQLite gotcha, worth seeing firsthand rather than
taking on faith. Using the same `ex_inventory`-shaped table (fresh
copy, both rows back at their original values), start a transaction,
make one **valid** update (subtract 3 from product 1 — leaves it at
7, still `>= 0`), then attempt one **invalid** update in the *same*
transaction (subtract 100 from product 2 — would leave it at -95,
violating the `CHECK`). Does the invalid statement's failure
automatically discard the valid one too? Try `COMMIT` afterward and
see what actually gets persisted.

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_inventory3 (product_id INTEGER, qty INTEGER CHECK (qty >= 0));
INSERT INTO ex_inventory3 VALUES (1, 10), (2, 5);
BEGIN;
UPDATE ex_inventory3 SET qty = qty - 3 WHERE product_id = 1;
UPDATE ex_inventory3 SET qty = qty - 100 WHERE product_id = 2;
SELECT * FROM ex_inventory3;
```

```
Runtime error near line 5: CHECK constraint failed: qty >= 0 (19)
product_id  qty
----------  ---
1           7
2           5
```

The second `UPDATE` failed, as expected — but the transaction is
**still open**, and product 1's change (`qty = 7`) is still sitting
there, uncommitted but not discarded either. SQLite's default
behavior on a `CHECK` violation aborts *only that one statement*, not
the entire transaction. If you now run:

```sql
COMMIT;
SELECT * FROM ex_inventory3;
```

```
product_id  qty
----------  ---
1           7
2           5
```

The `COMMIT` succeeds, and product 1's partial change is now
permanent — even though the transaction *also* contained a statement
that failed. This is a real trap: don't assume a single failed
statement means "the whole transaction will be safely discarded."
SQLite leaves it up to you to notice the error and explicitly issue
`ROLLBACK` if you want the transaction's earlier successful statements
undone too. Checking each statement's result (or your application's
error handling) matters — the database won't protect you from a
partial commit by default.

</details>

---

### 6. Nested checkpoints with SAVEPOINT

`SAVEPOINT` lets you set an undo point *inside* an already-open
transaction, and `ROLLBACK TO savepoint_name` undoes only the changes
since that savepoint — without ending the outer transaction. On a
fresh `ex_savepoint (id INTEGER, val TEXT)` table seeded with `(1,
'original')`: begin a transaction, update `val` to `'first change'`,
create a savepoint, update `val` again to `'second change'`, then
`ROLLBACK TO` the savepoint. What value survives? Then `COMMIT` and
confirm what's actually persisted.

<details>
<summary>Show solution</summary>

```sql
CREATE TABLE ex_savepoint (id INTEGER, val TEXT);
INSERT INTO ex_savepoint VALUES (1, 'original');
BEGIN;
UPDATE ex_savepoint SET val = 'first change' WHERE id = 1;
SAVEPOINT sp1;
UPDATE ex_savepoint SET val = 'second change' WHERE id = 1;
SELECT * FROM ex_savepoint;
ROLLBACK TO sp1;
SELECT * FROM ex_savepoint;
COMMIT;
SELECT * FROM ex_savepoint;
```

```
id  val
--  -------------
1   second change

id  val
--  ------------
1   first change

id  val
--  ------------
1   first change
```

`ROLLBACK TO sp1` undid only the second update, restoring `'first
change'` — it did **not** undo the first update or end the outer
transaction (unlike a plain `ROLLBACK`, which would have thrown away
both changes and closed the transaction entirely). The subsequent
`COMMIT` then persists `'first change'` as the final value.
`SAVEPOINT` is the tool for "undo just this part" inside a larger
transaction that should otherwise still go through.

</details>
