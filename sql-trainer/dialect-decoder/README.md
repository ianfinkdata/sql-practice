# The Dialect Decoder

> One idea, spelled four ways. This is the part of SQL Trainer that translates a
> concept into the exact syntax for **your** database — and shows you the
> equivalent in the other three.

---

## SQL is a family of dialects

Think of SQL the way you'd think of English. British English and American
English share the same grammar, the same core vocabulary, and the same
sentences for 95% of everyday use — but a *lift* is an *elevator*, a *lorry* is
a *truck*, and you spell *colour* without the *u* on one side of the Atlantic.

SQL is exactly like that. There is a standard (ANSI/ISO SQL) that almost every
engine follows for the core — `SELECT ... FROM ... WHERE ... GROUP BY ... ORDER
BY` is the same everywhere. But each engine grew up solving different problems,
so the moment you reach for string functions, date math, top-N queries, upserts,
or JSON, the spellings diverge.

This Decoder catalogs those divergences so you never get stuck because a
tutorial assumed a different system than the one in front of you.

---

## The four dialects (in priority order)

Throughout the Decoder, dialects always appear in this same order:

| | Dialect | Version target | One-line positioning |
|---|---------|----------------|----------------------|
| 🟥 | **Oracle SQL** | Oracle Database 19c+ | Enterprise OLTP workhorse; deep, mature feature set and heavy **PL/SQL** procedural code. |
| 🧱 | **Databricks SQL** | Spark SQL / Photon, Unity Catalog era | Lakehouse **OLAP** engine; analytics over huge data, Spark SQL semantics, Delta tables. |
| 🐬 | **MySQL** | 8.0+ | The most widely deployed open-source **OLTP** database; simple, fast, ubiquitous on the web. |
| 🐘 | **PostgreSQL** | 14+ | The standards-leaning open-source database; rich types, extensible, careful about correctness. |

---

## How to use the Decoder

1. **Know the concept, need the spelling?** Open the
   [**reference matrix**](reference-matrix.md). Find the section (Strings, Dates,
   NULL handling, Upsert, JSON, …) and read across the row: **Task | Oracle |
   Databricks | MySQL | Postgres**.
2. **Living in one engine all day?** Read that engine's cheat sheet — it covers
   the quirks, signature functions, and "things that surprise people coming from
   other dialects":
   - [`oracle.md`](oracle.md)
   - [`databricks.md`](databricks.md)
   - [`mysql.md`](mysql.md)
   - [`postgres.md`](postgres.md)
3. **Learning a concept for the first time?** Start in the
   [curriculum](../curriculum/) — it teaches the *idea* in plain English — then
   come here for the exact syntax.

---

## Portability tips

You will not always know which engine your SQL ends up running on. A few habits
keep your code portable and your surprises small:

- **Write ANSI where ANSI exists.** `COALESCE` (not `NVL`/`IFNULL`), `CASE` (not
  `DECODE`/`IF`), `FETCH FIRST n ROWS ONLY` (works in Oracle and Postgres),
  `CAST(x AS type)` (not `::` or `CONVERT`), and `||` for concatenation
  (everywhere *except* default MySQL — see below).
- **Isolate the dialect-specific bits.** When you must use a proprietary
  function (`LISTAGG`, `GROUP_CONCAT`, `date_format`, `ON CONFLICT`), keep it in
  one clearly commented spot so a port is a find-and-replace, not a rewrite.
- **Don't assume top-N syntax.** `LIMIT` is *not* Oracle (pre-23ai); `ROWNUM`
  and `FETCH FIRST` are *not* MySQL. This is the single most common portability
  break.
- **Be explicit about types and casts.** Implicit conversions differ wildly
  (especially around dates and empty strings). Cast on purpose.
- **Beware the silent semantic traps:** MySQL `||` means OR, Oracle treats `''`
  as `NULL`, and Postgres folds unquoted identifiers to lowercase. These don't
  error — they just do something you didn't expect. Each is flagged with a
  **Gotcha** callout in the matrix.
- **Test the edge cases on the real target.** NULL ordering, division by zero,
  string/number coercion, and time-zone handling are where "portable" SQL most
  often quietly differs.

---

## Files in this folder

| File | What it is |
|------|------------|
| [`README.md`](README.md) | This page — how the Decoder works. |
| [`reference-matrix.md`](reference-matrix.md) | The big side-by-side translation table. **Start here.** |
| [`oracle.md`](oracle.md) | Oracle cheat sheet. |
| [`databricks.md`](databricks.md) | Databricks SQL cheat sheet. |
| [`mysql.md`](mysql.md) | MySQL cheat sheet. |
| [`postgres.md`](postgres.md) | PostgreSQL cheat sheet. |

← Back to the [curriculum](../curriculum/) · [project root](../README.md)
