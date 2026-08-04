# Exercises: Star vs. Snowflake Schema

<!-- nav -->
Curriculum: [8. Star vs. Snowflake Schema](../../curriculum/05-master/08-star-vs-snowflake-schema.md). Previous: [7. Designing the Fact Table](07-designing-the-fact-table.md). Next: [9. The Medallion Pipeline, Start to Finish](09-medallion-pipeline-recap.md).
<!-- /nav -->

All solutions verified against `project/oakhaven.db`.

## 1. One-hop rollup by subcategory

`dim_product.subcategory` is a flat text column, just like `category`.
Write a one-join query that returns net sales by `subcategory` for
non-NULL subcategories, top 5 by revenue.

<details>
<summary>Show solution</summary>

```sql
SELECT p.subcategory, COUNT(*) AS lines, ROUND(SUM(f.net_amount), 2) AS net
FROM fact_sales f
JOIN dim_product p ON p.product_id = f.product_id
WHERE p.subcategory IS NOT NULL
GROUP BY p.subcategory
ORDER BY net DESC
LIMIT 5;
```

| subcategory | lines | net |
|---|---|---|
| Jackets | 515 | 471010.47 |
| Harnesses | 389 | 417394.11 |
| Energy Bars | 494 | 385550.16 |
| Backpacks | 322 | 384378.22 |
| Chalk Bags | 553 | 367798.19 |

Same star-schema shape as the category rollup in the lesson: one join,
`GROUP BY` a flat column.

</details>

## 2. Check `dim_employee`'s cardinality before deciding

Before deciding whether `department` or `region` on `dim_employee`
deserve their own sub-dimension tables, check the numbers. Write a
query returning the employee count, distinct department count, and
distinct region count.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) AS employees, COUNT(DISTINCT department) AS depts, COUNT(DISTINCT region) AS regions
FROM dim_employee;
```

| employees | depts | regions |
|---|---|---|
| 35 | 4 | 5 |

4 departments and 5 regions across only 35 employees — far too low a
cardinality, and far too small a dimension, to justify snowflaking
either one out. Leave them flat.

</details>

## 3. One-hop rollup by employee region

Prove the same one-join pattern works identically for `dim_employee`
as it does for `dim_product`. Return total net sales by `region`,
highest first. (Remember `employee_id` can be NULL for online/no-rep
sales — an inner join naturally excludes those rows here, which is
fine for this exercise.)

<details>
<summary>Show solution</summary>

```sql
SELECT e.region, COUNT(*) AS lines, ROUND(SUM(f.net_amount), 2) AS net
FROM fact_sales f
JOIN dim_employee e ON e.employee_id = f.employee_id
GROUP BY e.region
ORDER BY net DESC;
```

| region | lines | net |
|---|---|---|
| West | 3382 | 2568537.23 |
| South | 2119 | 1560580.8 |
| East | 1917 | 1357036.81 |
| Central | 1834 | 1294425.26 |
| Northeast | 1505 | 1085647.03 |

</details>

## 4. Quantify the storage trade-off

Snowflaking `category` out of `dim_product` would store each of the 8
category strings exactly once instead of once per product. Write two
queries: the total character length of `category` values as currently
stored (star, one copy per product), and the total character length if
only the 8 distinct values were stored once each (snowflaked). How
much would actually be saved?

<details>
<summary>Show solution</summary>

```sql
SELECT
    (SELECT SUM(LENGTH(category)) FROM dim_product) AS star_bytes,
    (SELECT SUM(LENGTH(category)) FROM (SELECT DISTINCT category FROM dim_product)) AS snowflake_bytes;
```

| star_bytes | snowflake_bytes |
|---|---|
| 1790 | 96 |

Snowflaking would "save" 1,694 bytes — over the entire `dim_product`
table. That's an irrelevant amount of storage on any real system, and
it's the concrete version of the cardinality argument from module 8:
low-cardinality attributes on small dimensions essentially never
justify the extra join.

</details>

## 5. Build the snowflaked version yourself, and hit the classic bug

Simulate what a snowflaked `dim_category` would look like using CTEs,
then join `fact_sales` through it two hops (`fact_sales` →
simulated `dim_product` → simulated `dim_category`) to reproduce the
category rollup from module 8's lesson. Use `ROW_NUMBER()` to mint a
`category_id` for each distinct category.

**Watch out**: if you write `SELECT DISTINCT category, ROW_NUMBER()
OVER (ORDER BY category) FROM dim_product` directly, `DISTINCT` is
applied *after* the window function computes a row number per
underlying row — so you get one "distinct" row per product, not per
category, and the category_id you minted isn't actually 1:1 with
category text. Get the distinct list in its own CTE first.

<details>
<summary>Show solution</summary>

```sql
WITH cat_list AS (
    SELECT DISTINCT category FROM dim_product
),
sim_dim_category AS (
    SELECT category, ROW_NUMBER() OVER (ORDER BY category) AS category_id
    FROM cat_list
),
sim_dim_product AS (
    SELECT p.product_id, c.category_id
    FROM dim_product p
    JOIN sim_dim_category c ON c.category = p.category
)
SELECT sc.category, COUNT(*) AS lines, ROUND(SUM(f.net_amount), 2) AS net
FROM fact_sales f
JOIN sim_dim_product sp ON sp.product_id = f.product_id
JOIN sim_dim_category sc ON sc.category_id = sp.category_id
GROUP BY sc.category
ORDER BY net DESC;
```

| category | lines | net |
|---|---|---|
| Climbing | 1858 | 1389650.95 |
| Winter Sports | 1834 | 1249691.54 |
| Apparel | 1556 | 1237729.99 |
| Nutrition & Hydration | 1548 | 1164289.69 |
| Footwear | 1402 | 1077941.52 |
| Accessories | 1543 | 938846.45 |
| Camping & Hiking | 1277 | 911945.48 |
| Water Sports | 860 | 722662.14 |

Identical numbers to the one-hop star version in the lesson — as they
should be, since it's the same data reshaped. Compare the query length
and hop count to the one-liner join in exercise 1: this is the real
cost of snowflaking, paid on every single query, for a dimension that
didn't need it.

(If you hit the `DISTINCT`-before-window-function bug first, you'd
have seen wildly inflated `lines`/`net` numbers — many thousands of
lines instead of 12,000 total across all categories — because every
product joined to several duplicate `category_id`s instead of one.
That's worth remembering any time `DISTINCT` and a window function
appear in the same `SELECT`.)

</details>

## 6. Reasoning: when would you actually snowflake here?

No query for this one — answer in your own words first, then compare.
Oakhaven's `dim_product` has a `brand` column (24 distinct values, no
further attributes tracked). Suppose the business wanted to start
tracking, per brand: headquarters country, founding year, and a
sustainability rating — and suppose three *other* fact tables in the
warehouse (returns, supplier invoices, marketing spend) all also need
to look up brand attributes. Would you snowflake `brand` out into its
own `dim_brand` table now? Why or why not?

<details>
<summary>Show solution</summary>

Yes — this scenario flips both of the conditions from the lesson that
argue against it. `brand` would now have real attributes beyond a
label (headquarters, founding year, rating), and multiple *other* fact
tables need to share the exact same values consistently — the
conformed-dimension case. Splitting it into `dim_brand(brand_id,
brand_name, hq_country, founded_year, sustainability_rating)` and
having `dim_product` (and the other three fact-adjacent dimensions)
reference `brand_id` means the sustainability rating is maintained in
exactly one place and stays consistent everywhere it's used — versus
either duplicating those new attributes onto every fact-adjacent
dimension separately (risking drift) or awkwardly re-joining back to
`dim_product` from unrelated fact tables just to reach brand
attributes. Cardinality alone (24 values) still wouldn't justify it —
it's the combination of "has its own attributes" and "genuinely shared
across multiple fact tables" that does.

</details>

---

<!-- nav -->
Curriculum: [8. Star vs. Snowflake Schema](../../curriculum/05-master/08-star-vs-snowflake-schema.md). Previous: [7. Designing the Fact Table](07-designing-the-fact-table.md). Next: [9. The Medallion Pipeline, Start to Finish](09-medallion-pipeline-recap.md).
<!-- /nav -->
