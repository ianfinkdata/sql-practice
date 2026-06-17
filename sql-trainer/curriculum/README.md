# The SQL Trainer Curriculum

A complete path from "what is a database?" to designing data systems that scale.
Five tiers, each building on the last. Every module follows the same shape so
you always know what you're getting:

- **The idea** — plain English, before any syntax
- **Why it matters** — where you'd actually use it
- **See it** — a minimal example (only when it helps)
- **Watch out** — the mistakes everyone makes
- **Practice** — exercises to make it stick

---

## How to move through it

You don't have to start at the beginning. Find the first thing on this list you
*can't* confidently do, and start there.

### Tier 0 — [Orientation](00-orientation/)
Brand new? Start here. What a database is, what SQL is for, and how to read the
rest of this curriculum. No code required.

### Tier 1 — [Beginner: Asking Questions](01-beginner/)
Get answers out of a single table.
1. The relational model in plain English
2. SELECT and FROM — choosing what you see
3. WHERE — filtering to the rows you want
4. ORDER BY and LIMIT — sorting and trimming
5. DISTINCT and basic expressions
6. Operators, AND/OR/NOT, and ranges

### Tier 2 — [Intermediate: Combining & Summarizing](02-intermediate/)
Work across rows and tables.
1. Aggregate functions — COUNT, SUM, AVG, MIN, MAX
2. GROUP BY — summarizing by category
3. HAVING — filtering the summaries
4. JOINs part 1 — INNER and LEFT
5. JOINs part 2 — RIGHT, FULL, CROSS, SELF, and anti-joins
6. Set operations — UNION, INTERSECT, EXCEPT
7. Subqueries — nested and correlated
8. CASE and conditional logic
9. NULLs — the three-valued logic that bites everyone

### Tier 3 — [Advanced: Analytics](03-advanced/)
Answer questions a single GROUP BY can't.
1. Window functions — the big idea
2. Ranking — ROW_NUMBER, RANK, DENSE_RANK, NTILE
3. Running totals and moving averages
4. LEAD, LAG, and period-over-period
5. Window frames — ROWS vs RANGE
6. CTEs — readable, reusable building blocks
7. Recursive CTEs — hierarchies and sequences
8. Date and time intelligence
9. Pivoting and unpivoting
10. Strings, patterns, and regular expressions

### Tier 4 — [Expert: Building & Tuning](04-expert/)
Stop just querying — start building.
1. DDL — designing tables, types, and constraints
2. DML — INSERT, UPDATE, DELETE, and MERGE/UPSERT
3. Transactions and ACID
4. Isolation levels and concurrency
5. Views and materialized views
6. Indexes — how they work and when to add them
7. Reading query plans (EXPLAIN)
8. Query optimization patterns
9. Stored procedures, functions, and triggers
10. JSON and semi-structured data

### Tier 5 — [Master: Design & Architecture](05-master/)
Think in systems.
1. Data modeling and normalization
2. Dimensional modeling — star and snowflake schemas
3. Slowly changing dimensions
4. The medallion architecture (Bronze/Silver/Gold)
5. Partitioning, clustering, and distribution
6. Performance tuning at scale
7. Anti-patterns and how to refactor them
8. Dialect mastery — knowing your engine
9. Capstone projects

---

## The dialect question

SQL is a family of closely related languages, not one language. This curriculum
teaches concepts in **standard SQL** and flags where dialects differ. Whenever
you need the exact spelling for your database, jump to the
[Dialect Decoder](../dialect-decoder/).

---

## A reminder about code

If you're following along with the **Sage** persona (see
[`persona_instructions.md`](../persona_instructions.md)), notice that the goal
is always *understanding first*. The code blocks in these modules are there for
when you're ready to type — not as the explanation itself. Read the words, then
reach for the code.
