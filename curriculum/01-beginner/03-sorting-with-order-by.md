# 3. Sorting with ORDER BY

## The idea

By default, a query returns rows in whatever order the database
happens to produce them — which, in practice, usually resembles the
order they were inserted, but nothing in SQL *guarantees* that.
`ORDER BY` is how you take control and ask for rows in a specific,
meaningful order: cheapest products first, most recently hired
employees first, alphabetically by name.

```sql
SELECT columns
FROM table_name
ORDER BY column_name;
```

## Why it matters

"What's our most expensive product?" and "what's our cheapest
product?" are both trivial once you can sort — the answer is just the
first row after the right `ORDER BY`. Sorting is also foundational for
later work: ranking customers by lifetime value, finding the earliest
or latest order, building a leaderboard. It's a small piece of syntax
that unlocks a lot of practical questions.

## Syntax

```sql
SELECT columns FROM table_name
ORDER BY column_name ASC;   -- ascending (low to high, A to Z) — the default

SELECT columns FROM table_name
ORDER BY column_name DESC;  -- descending (high to low, Z to A)
```

`ASC` is the default — if you omit it, ascending is assumed. Most
people write `ASC` explicitly anyway for readability, but it's never
required.

You can sort by more than one column. The first column is the primary
sort; ties in that column are broken by the second column, and so on:

```sql
SELECT columns FROM table_name
ORDER BY column_a ASC, column_b DESC;
```

## Try it

### Cheapest products first

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price ASC
LIMIT 5;
```

| product_name | unit_price |
|---|---|
| Cascade Hiking Boots | 6.67 |
| Canyon Hats | 21.03 |
| Glacier Sleeping Bag | 22.65 |
| Trailhead Sleeping Bags | 22.82 |
| Outrider Sleeping Bag | 23.52 |

### Most expensive products first

```sql
SELECT product_name, unit_price
FROM bronze_products
ORDER BY unit_price DESC
LIMIT 5;
```

| product_name | unit_price |
|---|---|
| Highline Backpacks | 812.71 |
| Foothill Electrolyte Mixes | 782.32 |
| Highline Paddle | 696.3 |
| Canyon Backpacks | 687.96 |
| Meridian Chalk Bags | 669.02 |

### Multi-column sort: group by category, then by price within each

```sql
SELECT category, product_name, unit_price
FROM bronze_products
ORDER BY category ASC, unit_price DESC
LIMIT 8;
```

| category | product_name | unit_price |
|---|---|---|
| ACCESSORIES | Switchback Multi-Tools | 505.09 |
| ACCESSORIES | Granite Sunglasse | 490.08 |
| ACCESSORIES | Trailhead Hats | 67.0 |
| ACCESSORIES | Switchback Headlamps | 370.95 |
| ACCESSORIES | Summit Sunglasses | 309.16 |
| ACCESSORIES | Timberline Multi-Tools | 192.25 |
| ACCESSORIES | Wayfinder Multi-Tools | 145.45 |
| ACCESSORIES | Granite Headlamps | 122.88 |

All `ACCESSORIES`-category rows come first (there happen to be enough
of them to fill the whole `LIMIT 8`), and within that group, price
descends from $505.09 down. That's the two-column sort at work: sort
by `category` first, and only use `unit_price` to break ties *within*
a category.

### A trap: sorting mixed-format dates

```sql
SELECT first_name, last_name, hire_date
FROM bronze_employees
ORDER BY hire_date
LIMIT 10;
```

| first_name | last_name | hire_date |
|---|---|---|
| Wendy | Scott | 02/11/2021 |
| Alexa | garcia | 04/09/2024 |
| ANTONIO | Bailey | 04/22/2022 |
| sandra | Thompson | 05/25/2018 |
| Scott | henderson | 05/29/2024 |
| Elaine | jones | 07/07/2022 |
| Karen | jackson | 07/13/2025 |
| Ashlee | Hall | 09/16/2018 |
| NANCY | Simmons | 10/28/2025 |
| Nicholas | Morris | 11/05/2022 |

Look closely: this is **not** chronological order at all, even though
it might look plausible at a glance. `hire_date` is stored as raw
`TEXT`, and Oakhaven's bronze data mixes `MM/DD/YYYY` and
`YYYY-MM-DD` formats. SQLite sorts `TEXT` values character by
character, left to right — and every `MM/DD/YYYY` value starts with a
`0` or `1` (the month), which sorts *before* every `YYYY-MM-DD` value
(which starts with `2`, the first digit of a year like `2018`). So
this query puts *every* `MM/DD/YYYY`-formatted hire date ahead of
*every* `YYYY-MM-DD`-formatted one, regardless of which year either
one actually is — Wendy Scott's `02/11/2021` sorts before someone
hired in `2018-07-14`, even though 2018 is earlier. This is exactly
the kind of bug that raw, mixed-format bronze data invites, and
exactly why parsing dates into one consistent format is one of the
first things the silver layer does (Tier 2).

## Common mistakes

- **Assuming unsorted output has a meaningful order.** Without
  `ORDER BY`, don't rely on rows coming back in any particular
  sequence — always sort explicitly if order matters to you.
- **Sorting text-formatted dates and expecting chronological
  order.** As shown above, this silently produces wrong results
  rather than an error — the most dangerous kind of mistake. When
  `hire_date`/`order_date`/etc. are messy `TEXT`, `ORDER BY` sorts them
  as strings, not as dates.
- **Putting `ORDER BY` before `WHERE`.** The correct clause order is
  `SELECT ... FROM ... WHERE ... ORDER BY ...`. Reversing `WHERE` and
  `ORDER BY` is a syntax error.
- **Forgetting `DESC` and getting the opposite of what you wanted.**
  "Top 5 most expensive" needs `ORDER BY unit_price DESC` — leaving off
  `DESC` silently gives you the 5 *cheapest* instead, no error, just
  the wrong answer.

## Key takeaways

- `ORDER BY column ASC|DESC` controls result order; without it, order
  isn't guaranteed.
- You can sort by multiple columns — later columns break ties in
  earlier ones.
- Sorting mixed-format text dates does **not** give chronological
  order — a real trap in Oakhaven's bronze layer, and a preview of why
  the silver layer standardizes date formats.
