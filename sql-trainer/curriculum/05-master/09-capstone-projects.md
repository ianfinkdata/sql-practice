# Capstone Projects: Put It All Together

> Four substantial briefs that braid the whole curriculum into real systems you design end to end.

## The idea

You've learned the moves. Now you build the machine. A capstone isn't an exercise with one right answer — it's a *brief*, the way a real project arrives: a goal, some requirements, and the freedom (and burden) of designing the solution yourself. There are no full solutions here on purpose. Mastery is shown by the system you produce, the trade-offs you can defend, and the questions you think to ask.

Use the shared sample dataset — `customers`, `sales`, `sales_rep`, `products` — as your raw material, inventing extra columns or volume wherever a project needs them. Tackle them in any order; each one leans on a different cluster of skills from this tier.

A word before you start: write down your design decisions *as you make them*. "I chose Type 2 for region because..." The ability to explain *why* is the thing being assessed — by future-you, by a reviewer, by anyone who inherits your work.

---

## Project 1 — Build a Sales Analytics Warehouse (Medallion)

**Goal.** Turn raw, messy sales feeds into a trustworthy, business-ready warehouse using the bronze/silver/gold layering from Module 04.

**Requirements.**
- Define a **bronze** layer that lands raw `customers`, `sales`, `sales_rep`, and `products` exactly as received, append-only, each row stamped with a `loaded_at` time. Change nothing.
- Build a **silver** layer that cleans: deduplicate (keep the latest record per key), cast types, standardize date formats, trim text, and quarantine bad rows (negative amounts, orphan customer references) into a reject table rather than dropping them silently.
- Build a **gold** layer with at least two business-ready tables — e.g. monthly revenue by region, and rep performance — that a dashboard could read directly with no further joins.
- Document, in words, what each layer is responsible for and why a number in gold can be traced back to a bronze row.

**Stretch goals.**
- Add a data-quality report counting rejects per load and per reason.
- Make gold tables materialized and describe your refresh schedule and the staleness it implies.
- Add a fourth source that arrives in a different date format and handle it without touching the others.

**What mastery looks like.** Each layer has exactly one job, no cleaning leaks into gold, no business logic leaks into silver, and you can trace any gold figure all the way back to raw. You can articulate the replayability you gained by keeping bronze untouched.

---

## Project 2 — Design and Populate a Dimensional Model

**Goal.** Convert the normalized sample data into a star schema an analyst can query intuitively (Modules 01–02).

**Requirements.**
- Write the **grain** of your fact table in one sentence before anything else, and never violate it.
- Design a `sales_fact` with surrogate-key pointers to dimensions and only additive (or clearly labeled semi/non-additive) facts.
- Build conformed dimensions for customer, product, rep, and date. Give each a generated **surrogate key** distinct from its business key.
- Write three analytical queries against your star — revenue by region by month, top reps by category, average sale by signup cohort — and confirm each reads almost like the plain-English question.

**Stretch goals.**
- Add a date dimension rich enough to support fiscal periods, weekdays, and holiday flags.
- Demonstrate one case where snowflaking a dimension is justified, and defend the extra join.
- Label every fact additive / semi-additive / non-additive and show a rollup that would be wrong if you summed a non-additive one.

**What mastery looks like.** The grain is crisp and never mixed, facts and dimensions are cleanly separated, surrogate keys are used throughout, and your queries mirror the questions. You can explain why you chose star over snowflake for each dimension.

---

## Project 3 — Build an SCD2 History Pipeline

**Goal.** Track the full history of a changing dimension so the past stays honest (Module 03).

**Requirements.**
- Pick an attribute that genuinely changes — customer `region` is ideal — and implement it as **Type 2**, with `valid_from`, `valid_to`, and `is_current`.
- Build a load process that, given a fresh batch of customer data, **expires** changed current rows and **inserts** new versions, leaving exactly one current row per customer and never overlapping date ranges.
- Implement it with the two-step expire-then-insert pattern (or `MERGE` where your engine supports it cleanly), and explain why a single naive `MERGE` is awkward here.
- Show that a sales fact joins to the dimension *version* whose date range contains the sale date — not merely to the current row — and prove that January's sales keep January's region after a July move.

**Stretch goals.**
- Mix SCD types in one dimension: Type 1 for a name typo, Type 2 for region. Defend each choice per attribute.
- Add validation that fails loudly if any customer ends up with two current rows or overlapping ranges.
- Sketch how a Type 6 hybrid would let you ask both "region then" and "region now" from the same table.

**What mastery looks like.** History reconstructs perfectly for any past date, exactly one current row exists per customer, ranges never overlap, and facts join to the correct historical version. You can explain the trade-off you accepted in row growth.

---

## Project 4 — Performance-Tuning Challenge

**Goal.** Take a slow, large-scale workload and make it fast by reading less and splitting evenly (Modules 05–07).

**Requirements.**
- Scale `sales` to a large volume (real or simulated) and identify a query that's painfully slow.
- Apply **partitioning** on the column you filter most and demonstrate **partition pruning** with a before/after.
- Find and fix at least two **anti-patterns** from Module 07 — a non-sargable filter and a per-row scalar subquery are prime candidates — and explain each refactor.
- Diagnose a join: decide whether it should **broadcast** or **shuffle**, ensure statistics are fresh, and explain how the planner's choice changed.

**Stretch goals.**
- Introduce deliberate **data skew** (one dominant region), show the slow-worker symptom, and mitigate it.
- Demonstrate the small-files problem and fix it with compaction.
- Materialize one expensive aggregation and quantify the speed-up against the staleness cost.

**What mastery looks like.** You can point to *why* each change helped using the vocabulary of this tier — pruning, pushdown, sargability, broadcast vs. shuffle, skew — not just "it got faster." You measured before and after, and you fixed the real bottleneck rather than guessing.

---

## Watch out

- **Don't aim for a "right answer."** Aim for a defensible design. The reasoning is the deliverable.
- **Write down trade-offs as you go.** Every choice closes some doors; name which ones and why it's worth it.
- **Measure before you tune.** Especially in Project 4 — confirm the bottleneck before rewriting anything.
- **Cross-reference the whole curriculum.** These briefs deliberately span every tier; reach back when you're stuck.
- **Engine matters.** Note where your design would differ on another database, and check the [Dialect Decoder](../../dialect-decoder/).

## Practice

1. Before building any project, write its one-paragraph design brief in your own words, including the single hardest decision you anticipate.
2. For Project 2, draft the grain sentence and have a peer try to break it with an edge case.
3. For Project 3, write the validation query that proves no customer has two current rows.
4. For Project 4, record one baseline measurement now so you have something honest to compare against later.

---
**Prev:** [Dialect Mastery](./08-dialect-mastery.md) · **Next:** [Back to the Curriculum](../README.md)
