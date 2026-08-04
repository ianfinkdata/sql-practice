# Exercises: DISTINCT and Duplicates

### 1. Distinct regions

Write a query listing every distinct `region` value in
`bronze_employees`, sorted alphabetically. How many distinct values are
there, and how many *real* regions do you think that represents?

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT region
FROM bronze_employees
ORDER BY region;
```

| region |
|---|
| CENTRAL |
| Central |
| EAST |
| East |
| NORTHEAST |
| Northeast |
| SOUTH |
| South |
| WEST |
| West |
| central |
| east |
| south |
| west |

```sql
SELECT COUNT(DISTINCT region) FROM bronze_employees;
```

| COUNT(DISTINCT region) |
|---|
| 14 |

14 distinct strings, but only 5 real regions (West, East, Central,
South, Northeast) — the same casing-messiness pattern as `category`
and `department`.

### 2. Distinct order statuses

List every distinct `order_status` in `bronze_sales`.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT order_status
FROM bronze_sales
ORDER BY order_status;
```

| order_status |
|---|
| (blank/NULL) |
|  CANCELLED |
| Cancelled |
| Completed |
| Returned |
| completed |

Notice one of the "distinct" values is blank — that's `NULL` showing
up in the `DISTINCT` list, which is expected: `NULL` counts as its own
distinct "value" for this purpose, separate from any real status
string.

</details>

### 3. Distinct channels

List every distinct `channel` value in `bronze_sales`, and count them.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT channel
FROM bronze_sales
ORDER BY channel;
```

| channel |
|---|
| In-Store |
| Online |
| in store |
| online |

```sql
SELECT COUNT(DISTINCT channel) FROM bronze_sales;
```

| COUNT(DISTINCT channel) |
|---|
| 4 |

4 distinct strings for what's really only 2 channels (Online,
In-Store) — casing (`online`/`Online`) plus a punctuation difference
(`In-Store`/`in store`) both contribute here.

</details>

### 4. Distinct is_manager values

List the distinct values that actually occur in
`bronze_employees.is_manager`.

<details>
<summary>Show solution</summary>

```sql
SELECT DISTINCT is_manager
FROM bronze_employees
ORDER BY is_manager;
```

| is_manager |
|---|
| (blank/NULL) |
| 0 |
| 1 |
| N |
| Y |
| false |
| n |
| no |
| y |

9 distinct values appear among these 35 employees (out of an even
larger possible pool of mixed-boolean spellings used elsewhere in
Oakhaven — not every possible spelling has to show up in every
column).

</details>

### 5. DISTINCT across two columns

Count how many distinct `(category, brand)` combinations exist in
`bronze_products`. Is that number the same as, smaller than, or larger
than the total row count (150)? Why?

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(*) FROM (
    SELECT DISTINCT category, brand FROM bronze_products
);
```

| COUNT(*) |
|---|
| 136 |

136, smaller than 150. That means some `(category, brand)` pairs
repeat — e.g. the same brand selling more than one product in the same
raw category string. (This wraps the `DISTINCT` query in a subquery
just to count its rows — subqueries are covered properly in a later
tier; for now, just trust that this counts how many distinct
`category, brand` pairs came out.)

</details>

### 6. Duplicate product names

Count how many distinct `product_name` values exist versus the total
row count. Does every product have a unique name?

<details>
<summary>Show solution</summary>

```sql
SELECT COUNT(DISTINCT product_name) FROM bronze_products;
```

| COUNT(DISTINCT product_name) |
|---|
| 141 |

```sql
SELECT COUNT(*) FROM bronze_products;
```

| COUNT(*) |
|---|
| 150 |

141 distinct names out of 150 rows — so no, product names are **not**
guaranteed unique. At least a few names (like "Canyon Backpacks,"
generated from an `{adjective} {subcategory}` pattern) repeat across
different `product_id`s. This is worth remembering: `product_name`
alone is not a safe way to identify "one specific product" — you'd
want `product_id` for that.

</details>
