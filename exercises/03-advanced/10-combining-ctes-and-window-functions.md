# Exercises: Capstone — Combining CTEs and Window Functions

<!-- nav -->
Curriculum: [10. Capstone — Combining CTEs and Window Functions](../../curriculum/03-advanced/10-combining-ctes-and-window-functions.md). Previous: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md). Next: [1. DDL Basics and Type Affinity](../04-expert/01-ddl-basics-and-type-affinity.md).
<!-- /nav -->

Query `project/oakhaven.db` for all of these. Run with:

```bash
sqlite3 project/oakhaven.db "SELECT ...;" -header -column
```

These build directly on the curriculum module's worked example (top
product per category by revenue) — expect to reuse and adapt that
two-CTE shape (aggregate first, rank second) throughout.

---

### 1. Top employee by revenue, per department

Find the single highest-revenue employee (by `SUM(fact_sales.net_amount)`)
in each department. Return `department`, `full_name`, `total_revenue`.

<details>
<summary>Show solution</summary>

```sql
WITH emp_rev AS (
    SELECT e.employee_id, e.full_name, e.department,
           ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM dim_employee e
    JOIN fact_sales f ON f.employee_id = e.employee_id
    GROUP BY e.employee_id, e.full_name, e.department
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY department ORDER BY total_revenue DESC) AS dept_rank
    FROM emp_rev
)
SELECT department, full_name, total_revenue
FROM ranked
WHERE dept_rank = 1
ORDER BY total_revenue DESC;
```

Verified output:

| department | full_name | total_revenue |
|---|---|---|
| Support | Robert Anderson | 268133.60 |
| Management | Daniel Ramsey | 263429.03 |
| Warehouse | Elaine Jones | 250715.52 |
| Sales | Carol Harrison | 246561.06 |

</details>

---

### 2. Every category's top product, with its share of category revenue

For each category, find the top product by revenue *and* what percentage
of that category's total revenue it represents. (This is the curriculum
module's "top 3, one category" example, generalized to rank 1 across
*all* categories at once.)

<details>
<summary>Show solution</summary>

```sql
WITH product_revenue AS (
    SELECT p.category, p.product_id, p.product_name,
           ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT category, product_name, total_revenue,
           SUM(total_revenue) OVER (PARTITION BY category) AS category_total,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rn
    FROM product_revenue
)
SELECT category, product_name, total_revenue,
       ROUND(100.0 * total_revenue / category_total, 1) AS pct_of_category
FROM ranked
WHERE rn = 1
ORDER BY pct_of_category DESC;
```

Verified output:

| category | product_name | total_revenue | pct_of_category |
|---|---|---|---|
| Water Sports | Ridge Paddles | 138646.07 | 19.2 |
| Camping & Hiking | Highline Backpacks | 172340.61 | 18.9 |
| Nutrition & Hydration | Foothill Electrolyte Mixes | 154322.60 | 13.3 |
| Footwear | Canyon Hiking Boots | 127464.80 | 11.8 |
| Accessories | Granite Sunglasse | 100832.83 | 10.7 |
| Apparel | Highline Rain Shells | 132236.97 | 10.7 |
| Climbing | Meridian Chalk Bags | 134818.34 | 9.7 |
| Winter Sports | Alpine Snowboards | 117472.48 | 9.4 |

Notice `Water Sports`' top product carries a bigger share of its category
(19.2%) than `Climbing`'s does (9.7%) — even though `Climbing`'s *category
total* is much larger overall (from the facts sheet: $1,382,563.66 vs.
Water Sports' $721,133.90). Revenue concentration and category size are
independent facts; this query surfaces the former.

</details>

---

### 3. Bottom product per category

Flip the sort direction from the curriculum's worked example: find the
*lowest*-revenue product in each category (i.e. still sold at least once,
but the weakest performer).

<details>
<summary>Show solution</summary>

```sql
WITH product_revenue AS (
    SELECT p.category, p.product_id, p.product_name,
           ROUND(SUM(f.net_amount), 2) AS total_revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_id = f.product_id
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT category, product_name, total_revenue,
           RANK() OVER (PARTITION BY category ORDER BY total_revenue ASC) AS rnk
    FROM product_revenue
)
SELECT category, product_name, total_revenue
FROM ranked
WHERE rnk = 1
ORDER BY total_revenue;
```

Verified output:

| category | product_name | total_revenue |
|---|---|---|
| Footwear | Cascade Hiking Boots | 1442.09 |
| Camping & Hiking | Trailhead Sleeping Bags | 3633.70 |
| Winter Sports | Glacier Winter Glove | 3790.50 |
| Accessories | Canyon Hats | 3795.30 |
| Apparel | Outrider Pants | 9531.83 |
| Nutrition & Hydration | Glacier Hydration Packs | 11326.72 |
| Climbing | Alpine Climbing Shoes | 12947.16 |
| Water Sports | Basecamp Life Jackets | 17696.30 |

</details>

---

### 4. Top VIP customer per state

Among customers with `customer_segment = 'VIP'` and a known `state`, find
the single highest-`lifetime_net_amount` VIP customer in each state. Show
the top 8 states by that customer's lifetime value.

<details>
<summary>Show solution</summary>

```sql
WITH vip AS (
    SELECT customer_id, full_name, state, lifetime_net_amount
    FROM agg_customer_ltv
    WHERE customer_segment = 'VIP' AND state IS NOT NULL
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY state ORDER BY lifetime_net_amount DESC) AS rn
    FROM vip
)
SELECT state, full_name, lifetime_net_amount
FROM ranked
WHERE rn = 1
ORDER BY lifetime_net_amount DESC
LIMIT 8;
```

Verified output:

| state | full_name | lifetime_net_amount |
|---|---|---|
| IA | Jennifer Howard | 35024.55 |
| HI | Angela Fischer | 28985.84 |
| MD | Shawn Jacobs | 28149.78 |
| CO | Kristin Baker | 28089.28 |
| PA | Michele Perez | 27836.74 |
| CA | Denise White | 26519.30 |
| RI | Ann Rogers | 25614.81 |
| MS | Joshua Pittman | 24834.05 |

</details>

---

### 5. Hardest: top category per year, with year-over-year change in that leading category's own revenue

For each year, find the top category by revenue (as in the curriculum's
Module 1 worked example), then add a column showing how that *same
category's* revenue changed from the previous year (even if it wasn't
the top category the previous year). This needs three CTEs chained: (1)
category-year totals, (2) the year's top category via `RANK()`, (3)
`LAG()` applied *back on the category-year totals*, filtered down to just
the winning categories.

<details>
<summary>Show solution</summary>

```sql
WITH category_year AS (
    SELECT year, category, ROUND(SUM(total_net_amount), 2) AS year_revenue
    FROM agg_monthly_sales_by_category
    GROUP BY year, category
),
with_prev AS (
    SELECT year, category, year_revenue,
           LAG(year_revenue) OVER (PARTITION BY category ORDER BY year) AS prev_year_revenue
    FROM category_year
),
top_category AS (
    SELECT year, category, year_revenue, prev_year_revenue,
           RANK() OVER (PARTITION BY year ORDER BY year_revenue DESC) AS rnk
    FROM with_prev
)
SELECT year, category, year_revenue, prev_year_revenue,
       ROUND(year_revenue - prev_year_revenue, 2) AS yoy_change
FROM top_category
WHERE rnk = 1
ORDER BY year;
```

Verified output:

| year | category | year_revenue | prev_year_revenue | yoy_change |
|---|---|---|---|---|
| 2021 | Climbing | 243934.82 | *(null)* | *(null)* |
| 2022 | Nutrition & Hydration | 268912.10 | 201398.10 | 67514.00 |
| 2023 | Climbing | 253598.69 | 264761.16 | -11162.47 |
| 2024 | Climbing | 264295.25 | 253598.69 | 10696.56 |
| 2025 | Climbing | 242061.82 | 264295.25 | -22233.43 |
| 2026 | Climbing | 113911.92 | 242061.82 | -128149.90 |

Two things worth noticing. First, 2022's winning category
(Nutrition & Hydration) is compared against *its own* 2021 total
($201,398.10) — not Climbing's 2021 total — because `LAG()` was computed
per-category before the ranking step, exactly as intended. Second, 2023's
`prev_year_revenue` ($264,761.16) is Climbing's actual 2022 total — and
it's worth confirming that's plausible even though Climbing wasn't 2022's
winner: querying `category_year` for 2022 directly shows Climbing
($264,761.16) came in a close second to Nutrition & Hydration
($268,912.10) — no contradiction, just a near-photo-finish year. Finally,
2026's steep `yoy_change` is a separate, simpler caveat: it's a half-year
total (data ends 2026-06-30) being compared to a full prior year, exactly
the kind of caveat worth calling out any time a partial period gets
compared against complete ones.

The key trick: `LAG()` in `with_prev` is computed **before** the ranking
step, partitioned by `category` and ordered by `year` — so each category
carries its own prior-year value regardless of rank, and only afterward
does `top_category` pick out whichever category happened to win that
particular year.

</details>

---

<!-- nav -->
Curriculum: [10. Capstone — Combining CTEs and Window Functions](../../curriculum/03-advanced/10-combining-ctes-and-window-functions.md). Previous: [9. Correlated Subqueries, EXISTS, and NOT EXISTS](09-correlated-subqueries-exists.md). Next: [1. DDL Basics and Type Affinity](../04-expert/01-ddl-basics-and-type-affinity.md).
<!-- /nav -->
