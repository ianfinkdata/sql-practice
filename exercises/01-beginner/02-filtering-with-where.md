# Exercises: Filtering with WHERE

### 1. One category

Write a query that shows `product_name` and `unit_price` for every
product in `bronze_products` where `category` is exactly `Footwear`.

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM bronze_products
WHERE category = 'Footwear';
```

| product_name | unit_price |
|---|---|
| Switchback Trail Running Shoes | 341.91 |
| Driftwood Approach Shoes | 71.3 |
| Backcountry Approach Shoes | 60.5 |

Only 3 rows — remember this misses `FOOTWEAR`, `footwear`, `Foot Wear`,
and other messy variants, since `=` is exact-match.

</details>

### 2. Budget gear

Write a query that shows `product_name` and `unit_price` for every
product priced under $50. How many rows come back?

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM bronze_products
WHERE unit_price < 50;
```

10 rows. First few:

| product_name | unit_price |
|---|---|
| Cascade Hiking Boots | 6.67 |
| Glacier Winter Glove | 26.09 |
| Trailhead Sleeping Bags | 22.82 |

```sql
SELECT COUNT(*) FROM bronze_products WHERE unit_price < 50;
```

| COUNT(*) |
|---|
| 10 |

</details>

### 3. Two conditions with AND

Write a query that finds employees who are in the `Management`
department **and** the `West` region. Show `first_name`, `last_name`,
`department`, `region`.

<details>
<summary>Show solution</summary>

```sql
SELECT first_name, last_name, department, region
FROM bronze_employees
WHERE department = 'Management' AND region = 'West';
```

| first_name | last_name | department | region |
|---|---|---|---|
| Alexa | garcia | Management | West |
| DALE | parker | Management | West |

</details>

### 4. Either of two values, two ways

Count how many products have `is_discontinued` equal to `'true'` or
`'yes'`. Write it once using `OR`, and confirm you'd get the same
count using `IN`.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_products
WHERE is_discontinued = 'true' OR is_discontinued = 'yes';
```

| COUNT(*) |
|---|
| 2 |

Equivalently:

```sql
SELECT COUNT(*) FROM bronze_products
WHERE is_discontinued IN ('true', 'yes');
```

Same result: 2. (Note this is deliberately not the full picture — the
mixed-boolean pool for `is_discontinued` also includes `1`, `Y`, `y`;
a real "how many are discontinued" question needs the cleaned-up
silver version, which you'll meet in Tier 2.)

</details>

### 5. IN with three or more values

Write a query listing `first_name`, `last_name`, and `region` for
employees whose `region` is `East` or `West`. How many total rows
match?

<details>
<summary>Show solution</summary>

```sql
SELECT first_name, last_name, region
FROM bronze_employees
WHERE region IN ('East', 'West');
```

10 rows total. First few:

| first_name | last_name | region |
|---|---|---|
| Alexa | garcia | West |
| Alexandria | CUNNINGHAM | East |
| CHRISTY | Lee | West |

```sql
SELECT COUNT(*) FROM bronze_employees WHERE region IN ('East', 'West');
```

| COUNT(*) |
|---|
| 10 |

</details>

### 6. Not equal, and why it can surprise you

Count products where `category` is **not** exactly `Footwear`. Before
running it, predict roughly what you'd expect if `category` had no
casing mess at all (150 total products, 3 exactly `'Footwear'`) —
then run it and see if the real number matches that expectation.

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM bronze_products WHERE category != 'Footwear';
```

| COUNT(*) |
|---|
| 147 |

150 total products minus the 3 exactly matching `'Footwear'` gives
147 — which does match, because `!=` (like `=`) is exact-match too, so
it's *consistent* with the exact-match count, even though it's still
including other-cased footwear rows (`FOOTWEAR`, `Foot Wear`, etc.) in
the "not footwear" bucket. That inconsistency between what the query
literally says and what you'd actually want ("not footwear, in any
casing") is exactly why raw `category` gets cleaned up in Tier 2.

</details>
