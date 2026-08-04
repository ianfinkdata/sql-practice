# Exercises: Tools and Setup

<!-- nav -->
Curriculum: [3. Tools and Setup](../../curriculum/00-orientation/03-tools-and-setup.md). Previous: [2. What Is SQL?](02-what-is-sql.md). Next: [4. Meet Oakhaven](04-meet-oakhaven.md).
<!-- /nav -->

Confirm your environment actually works before moving on — these are
short, practical checks rather than reflection questions.

### 1. Build it

Run the setup steps from the curriculum module (creating a virtual
environment first if `pip install` gives you an
"externally-managed-environment" error), then build the database:

```bash
pip install -r project/requirements.txt
python project/build.py
```

What's the last line or two the script prints when it finishes
successfully?

<details>
<summary>Show solution</summary>

You should see a summary of what was built, ending with something like
`ALL HARD CHECKS PASSED` (exact wording may vary slightly by build
script version, but it should clearly indicate success, not an error
or traceback). If you instead see a Python traceback, re-check that
`pip install -r project/requirements.txt` completed without errors
first.

</details>

### 2. Connect

Open `project/oakhaven.db` using whichever tool you chose (the
`sqlite3` CLI or DB Browser for SQLite), and confirm you can see a list
of tables. With the CLI:

```bash
sqlite3 project/oakhaven.db ".tables"
```

How many tables/views does it list?

<details>
<summary>Show solution</summary>

```bash
sqlite3 project/oakhaven.db ".tables"
```

Real output (18 total tables/views — 5 bronze, 5 silver, 4 dim/fact,
3 agg — you'll meet the rest of these in later tiers):

```
agg_customer_ltv               dim_date
agg_daily_sales                dim_employee
agg_monthly_sales_by_category  dim_product
bronze_calendar                fact_sales
bronze_customers               silver_calendar
bronze_employees               silver_customers
bronze_products                silver_employees
bronze_sales                   silver_products
dim_customer                   silver_sales
```

If you see far fewer tables, or none, `python project/build.py` likely
didn't complete — re-run it.

</details>

### 3. Sanity-check the row count

Run this and confirm you get exactly the number below — it should
match regardless of who builds it or when, since generation is
deterministic:

```bash
sqlite3 project/oakhaven.db "SELECT COUNT(*) FROM bronze_sales;"
```

<details>
<summary>Show solution</summary>

```bash
sqlite3 project/oakhaven.db "SELECT COUNT(*) FROM bronze_sales;"
```

Result: `12000`. If your number differs, your database wasn't built
from a clean run of `project/build.py` — rebuild it (note that
rebuilding deletes and recreates `oakhaven.db` from scratch).

</details>

---

<!-- nav -->
Curriculum: [3. Tools and Setup](../../curriculum/00-orientation/03-tools-and-setup.md). Previous: [2. What Is SQL?](02-what-is-sql.md). Next: [4. Meet Oakhaven](04-meet-oakhaven.md).
<!-- /nav -->
