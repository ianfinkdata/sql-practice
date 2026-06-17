# Tier 0 — Orientation

> No code in this tier. Just the mental model. If you've never touched a
> database, this is the gentlest possible start.

---

## What is a database, really?

Imagine a very well-organized filing cabinet. Each drawer holds one *kind* of
thing — one drawer for customers, one for orders, one for products. Inside a
drawer, every folder has the **same labeled tabs** in the same order: every
customer folder has a name, an address, a phone number, in exactly those slots.

That's a database. In database words:

- a **drawer** is a **table**,
- a **folder** is a **row** (one customer, one order),
- a **labeled tab** is a **column** (the name, the address),
- and the whole cabinet is the **database**.

The magic isn't the storage — it's that everything is so consistently organized
that you can *ask questions* and get exact answers instantly.

---

## What is SQL?

**SQL** (say it "sequel" or "ess-cue-el", both are fine) is the language you use
to *ask the filing cabinet questions* and to *put things into it*.

You don't open drawers and flip through folders by hand. You write a sentence
like:

> "Show me the names of every customer in Texas, newest first."

and SQL turns that request into an exact answer. The whole language is really
just a precise way of phrasing requests like that.

SQL stands for **Structured Query Language**. A *query* is just a question you
ask the data.

---

## Why learn SQL?

Because the answers to almost every important business question live in a
database, and SQL is the key that opens it:

- *Which products are selling this month?*
- *Which customers haven't ordered in a year?*
- *How much revenue came from each region?*

Analysts, engineers, marketers, scientists, and product managers all use SQL.
It has been the common language of data for **fifty years** and isn't going
anywhere. Learn it once, use it everywhere.

---

## The one mental model that makes SQL click

Almost every question you ask follows the same three-beat rhythm:

1. **Which table?** — where does the answer live? (`FROM`)
2. **Which rows?** — which folders do I care about? (`WHERE`)
3. **Which columns?** — what do I want to see back? (`SELECT`)

Everything else — sorting, combining tables, summarizing — is an addition to
that core. Hold onto this rhythm. When a query confuses you, come back to:
*which table, which rows, which columns.*

---

## A word about dialects (don't worry yet)

There isn't just one SQL. Different database systems — Oracle, MySQL,
PostgreSQL, Databricks, and others — each speak a slightly different *dialect*.
Think British vs American English: 95% identical, with a few words spelled
differently.

You do **not** need to worry about this yet. The curriculum teaches the shared
core first. When a difference matters, we'll point you to the
[Dialect Decoder](../../dialect-decoder/), which shows the exact phrasing for
each system side by side.

---

## How to read this curriculum

Every module is built the same way:

- **The idea** — what it is, in plain words
- **Why it matters** — when you'd reach for it
- **See it** — a small example, *only when seeing it actually helps*
- **Watch out** — the traps everyone falls into
- **Practice** — a few exercises

You'll notice we explain things in English before showing any code. That's on
purpose. Most people don't get stuck on *typing* SQL — they get stuck on
*understanding what they're asking for*. Get the idea first; the syntax is a
quick lookup after.

---

## Are you ready?

You're ready for [Tier 1 — Beginner](../01-beginner/) if you can answer, in your
own words:

- What is a table, a row, and a column?
- What is SQL *for*?
- What are the three questions every query answers?

If yes — turn the page. If not, re-read the filing cabinet section; it's the
whole foundation.

---

**Next:** [Tier 1 — Beginner: Asking Questions →](../01-beginner/)
