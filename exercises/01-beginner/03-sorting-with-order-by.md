# Exercises: Sorting with ORDER BY

### 1. Alphabetical by last name

Write a query showing `first_name` and `last_name` from
`bronze_employees`, sorted alphabetically by last name, first 5 rows.

<details>
<summary>Show solution</summary>

```sql
SELECT first_name, last_name
FROM bronze_employees
ORDER BY last_name ASC
LIMIT 5;
```

| first_name | last_name |
|---|---|
| Robert | ANDERSON |
| ANTONIO | Bailey |
| Mary | Boyd |
| JENNIFER | Brown |
| Derek | Brown |

</details>

### 2. Top 3 most expensive

Write a query for the 3 most expensive products (`product_name`,
`unit_price`).

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price DESC
LIMIT 3;
```

| product_name | unit_price |
|---|---|
| Highline Backpacks | 812.71 |
| Foothill Electrolyte Mixes | 782.32 |
| Highline Paddle | 696.3 |

</details>

### 3. Multi-column sort, and a casing surprise

Write a query showing `department`, `first_name`, `last_name`,
`hire_date` from `bronze_employees`, sorted by `department` and then
by `last_name`, first 8 rows. Look closely at how the `department`
values group — is `Management` grouped together as one block?

<details>
<summary>Show solution</summary>

```sql
SELECT department, first_name, last_name, hire_date
FROM bronze_employees
ORDER BY department ASC, last_name ASC
LIMIT 8;
```

| department | first_name | last_name | hire_date |
|---|---|---|---|
| MANAGEMENT | ANTONIO | Bailey | 04/22/2022 |
| MANAGEMENT | Ashlee | Hall | 09/16/2018 |
| MANAGEMENT | Nicholas | Morris | 11/05/2022 |
| MANAGEMENT | DANIEL | Ramsey | 2025-02-05 00:14:18 |
| Management | Mary | Boyd | 2021-03-01 21:05:46 |
| Management | Shannon | KLEIN | 2021-01-05 09:06:48 |
| Management | Amy | Morrow | 2023-04-02 00:01:01 |
| Management | NANCY | Simmons | 10/28/2025 |

No — `MANAGEMENT` (all caps) sorts as a separate group *before*
`Management` (title case), because SQLite's default text sort is
case-sensitive and uppercase letters sort before lowercase ones. Even
though these represent the same real department, sorting treats them
as different values entirely. Another preview of why casing gets
standardized in Tier 2.

</details>

### 4. Filter, then sort

Write a query for every product from brand `Stonepine Gear`, sorted by
price from highest to lowest.

<details>
<summary>Show solution</summary>

```sql
SELECT brand, product_name, unit_price
FROM bronze_products
WHERE brand = 'Stonepine Gear'
ORDER BY unit_price DESC;
```

| brand | product_name | unit_price |
|---|---|---|
| Stonepine Gear | Canyon Hiking Boots | 649.26 |
| Stonepine Gear | Highline Winter Gloves | 501.03 |
| Stonepine Gear | Alpine Snowshoe | 461.22 |
| Stonepine Gear | Basecamp Kayaks | 347.63 |
| Stonepine Gear | Northbound Trekking Poles | 189.59 |

</details>

### 5. The single cheapest product

Write a query that returns just one row: the single cheapest product
in `bronze_products` (name and price).

<details>
<summary>Show solution</summary>

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price ASC
LIMIT 1;
```

| product_name | unit_price |
|---|---|
| Cascade Hiking Boots | 6.67 |

</details>

### 6. Diagnose the bug

A teammate wrote this query, wanting the 5 most recently hired
employees, and got confused by the result:

```sql
SELECT first_name, last_name, hire_date
FROM bronze_employees
ORDER BY hire_date ASC
LIMIT 5;
```

What's wrong with their approach, independent of `ASC` vs `DESC`?

<details>
<summary>Show solution</summary>

Two separate bugs, actually: first, `ASC` gives the *earliest* dates,
not the most recent — they'd want `DESC` for "most recently hired."
But even fixing that wouldn't be enough: `hire_date` is stored as raw
`TEXT` with mixed formats (`MM/DD/YYYY` and `YYYY-MM-DD`), so sorting
it — in either direction — sorts the *text*, not the actual
chronological dates. As shown in this module's curriculum content,
every `MM/DD/YYYY` value sorts before every `YYYY-MM-DD` value
regardless of real date, so neither `ASC` nor `DESC` on raw
`hire_date` gives a trustworthy chronological answer. A reliable
answer needs the dates parsed into one consistent format first — which
is exactly what the silver layer does in Tier 2.

</details>
