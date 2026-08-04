# Exercises: What Is SQL?

<!-- nav -->
Curriculum: [2. What Is SQL?](../../curriculum/00-orientation/02-what-is-sql.md). Previous: [1. What Is a Database?](01-what-is-a-database.md). Next: [3. Tools and Setup](03-tools-and-setup.md).
<!-- /nav -->

Still no SQL to run — these are quick checks on the DDL/DML/DQL
vocabulary and where this course puts its weight.

### 1. Classify the statement

For each of the following, say whether it's DDL, DML, or DQL:

1. `SELECT * FROM bronze_products;`
2. `CREATE TABLE bronze_customers (...);`
3. `DELETE FROM bronze_sales WHERE order_id = 42;`
4. `ALTER TABLE bronze_products ADD COLUMN warranty_months INTEGER;`
5. `INSERT INTO bronze_employees (...) VALUES (...);`

<details>
<summary>Show solution</summary>

1. DQL — asks a question, changes nothing.
2. DDL — defines a table's structure.
3. DML — modifies data inside a table (removes rows).
4. DDL — changes a table's structure (adds a column).
5. DML — modifies data inside a table (adds a row).

</details>

### 2. Where's the weight?

If roughly 90%+ of real-world SQL work is one of DDL, DML, or DQL,
which one is it, and why does that match how this course is
structured?

<details>
<summary>Show solution</summary>

DQL — `SELECT` — is where the vast majority of practical SQL work
happens, because most of the time the data already exists (created by
some application, import job, or in Oakhaven's case a build script)
and the job is to *ask questions of it*: filter, sort, summarize, join,
clean up. That's why this course spends nearly all its time on
`SELECT` and treats `oakhaven.db` as read-only throughout.

</details>

### 3. Read-only, on purpose

This course's practice database is meant to be queried, not written
to. Why might that matter specifically for a *shared* database file
that many learners (or, in this repo's case, several automated
processes) might be using at the same time?

<details>
<summary>Show solution</summary>

If everyone queries with `SELECT` only, many people/processes can read
the same file safely and simultaneously — reads don't conflict with
each other. But writes (`INSERT`/`UPDATE`/`DELETE`, or `CREATE`/`DROP`)
change the underlying file; if two things tried to write to the same
SQLite file at the same time, or one person's write ran while another
was still reading it, you could get locking errors or, worse, corrupt
the file for everyone. Treating the shared database as read-only
avoids that entirely.

</details>

---

<!-- nav -->
Curriculum: [2. What Is SQL?](../../curriculum/00-orientation/02-what-is-sql.md). Previous: [1. What Is a Database?](01-what-is-a-database.md). Next: [3. Tools and Setup](03-tools-and-setup.md).
<!-- /nav -->
