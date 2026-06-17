# JSON and Semi-Structured Data

> Store flexible, nested data inside a column — and query into it almost as if it were tables.

## The idea

Relational tables love neat rectangles: every row has the same columns, every column one value. But the real world sometimes hands you data that doesn't fit the grid — a settings blob that differs per customer, an event payload from an API, a product whose attributes vary by category. Forcing that into rigid columns means either dozens of mostly-empty columns or constant schema changes.

**JSON** columns are the escape hatch. A JSON value is **semi-structured**: it has structure (keys, nested objects, arrays) but not a *fixed* shape. You can store a whole little document — `{"plan": "pro", "seats": 5, "addons": ["sso", "audit"]}` — in a single column, and different rows can carry different keys. It's like keeping a free-form notes field, except the database actually understands the structure and lets you reach inside it.

Reaching inside is the key skill. You don't read the whole blob and parse it in your app; you ask the database to **extract** a piece. Want the `plan` value? Pull it out by key. Want the third addon? Index into the array. Modern engines have operators and functions exactly for this, and you can use the extracted value in `WHERE`, `SELECT`, joins — anywhere. Some engines can even **unnest** a JSON array into rows, turning a list of addons into a little table you can join against.

The judgment call is **JSON versus real columns**. The rule of thumb: if you query, filter, sort, or join on a field a lot, make it a proper column with a proper type and index — that's what the relational engine is best at. Save JSON for the genuinely variable, rarely-filtered, or sparse parts. JSON buys flexibility; columns buy speed and integrity. Don't pour your whole schema into one JSON blob just because you can — you'll lose constraints, types, and most of your indexing.

## Why it matters

Almost every modern system has some data that won't sit still: API responses, user preferences, feature flags, audit payloads. JSON support lets you keep that data right alongside your structured tables and query it in one language, instead of bolting on a separate document store. Knowing how to extract from JSON — and, just as important, knowing which fields deserve to graduate into real columns — keeps your schema both flexible and fast.

## See it

Suppose `customers` has a `prefs JSON` column. Extract a single field and filter on it:

```sql
SELECT customer_name, prefs ->> 'plan' AS plan
FROM customers
WHERE prefs ->> 'plan' = 'pro';
```

Reach into a nested value and an array element:

```sql
SELECT
    prefs -> 'billing' ->> 'currency' AS currency,   -- nested object
    prefs -> 'addons'  ->> 0          AS first_addon  -- first array item
FROM customers;
```

Unnest a JSON array into rows so each addon becomes its own row you can group or join:

```sql
SELECT c.customer_name, addon.value AS addon
FROM customers c,
     jsonb_array_elements_text(c.prefs -> 'addons') AS addon;
```

> **Dialect note:** Every engine spells this differently. PostgreSQL uses `->` (keeps JSON) and `->>` (returns text), plus `jsonb` and `jsonb_array_elements`; MySQL uses `JSON_EXTRACT(...)` / the `->>` shorthand and `JSON_TABLE`; SQL Server and Oracle use `JSON_VALUE` (scalars), `JSON_QUERY` (objects), and `JSON_TABLE`; Snowflake/Databricks use **colon notation** like `prefs:plan` and `LATERAL FLATTEN` / `explode`. See the [Dialect Decoder](../../dialect-decoder/).

## Watch out

- **Don't bury everything in JSON.** Fields you filter or join on constantly belong in typed, indexed columns. JSON is for the flexible remainder.
- **Extraction usually returns text.** A value pulled from JSON often comes out as a string; cast it (`(prefs ->> 'seats')::INT`) before doing math or numeric comparisons.
- **Indexing JSON is special.** A plain index won't help a filter inside JSON; you need expression indexes or engine-specific ones (e.g., Postgres `GIN` on `jsonb`).
- **No schema means no guardrails.** The database won't stop a typo'd key or a missing field. You trade constraints for flexibility — validate in your app if it matters.
- **Distinguish `NULL` from "key absent."** Asking for a key that isn't there usually yields `NULL`, which can quietly hide bugs.
- **Mind the dialect.** As above, operators and functions vary so much that JSON code rarely ports unchanged. Always check the target engine.

## Practice

1. Given a `prefs` JSON column, write a query (in your engine's flavor) that returns customers whose `plan` is `'enterprise'`.
2. Explain in plain English how you'd decide whether a new "preferred currency" field should be a JSON key or its own column.
3. The `addons` array varies in length per customer. Describe how you'd produce one row per (customer, addon) pair.
4. You extract `seats` from JSON and a comparison `WHERE prefs ->> 'seats' > 3` behaves oddly. Explain the likely cause and the fix.

---
**Prev:** [Procedures, Functions, and Triggers](09-procedures-triggers.md) · **Next:** [Tier 5: Master](../05-master/)
