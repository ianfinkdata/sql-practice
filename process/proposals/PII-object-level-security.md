# PROPOSAL — Object-Level Security for PII Columns

**Status: PROPOSAL — NOT APPROVED, NOT IMPLEMENTED.** This is a plan for future
development, captured for later reference. Nothing here is grounded, binding, or safe to
build against until Ian approves it and it lands as an actual `DEF-nnn` in
`grounding/definitions.md` plus a real task brief. Do not treat any column list, rule, or
recommendation below as authoritative in the meantime.

Origin: TASK-20260706-01 (bronze full-row export pack) triggered the harness's own safety
classifier for a bulk PII-shaped export of `customers`/`employees`/`orders`/`payments`. That
export was correct for this project (`oakhaven` is synthetic, Faker-generated, deterministically
seeded data — nobody real is in it), but the flag was a legitimate prompt to design what this
project *would* do if bronze ever contained real PII, or as a demonstration exercise in
building object-level security into the medallion layers themselves. 2026-07-06.

## 1. Problem statement

Bronze (`oakhaven`) is read-as-is and carries columns that would be PII in a real dataset.
Right now nothing in silver or gold specifically reasons about PII — columns just flow
through unless a `DEF` transforms them for an unrelated reason (e.g., `DEF-009`
casing/flag cleanup touches `marketing_opt_in`, not because it's PII, but because it's dirty).
There's no policy for "this column should never reach a downstream consumer" or "this column
should reach downstream consumers only in a reduced form."

## 2. Columns in scope (as of `grounding/schema.md`, 2026-07-04 snapshot)

| Table | Column | Why it's in scope |
|---|---|---|
| `customers` | `first_name`, `middle_name`, `last_name` | Direct identifiers |
| `customers` | `email`, `phone` | Direct identifiers / contact info |
| `customers` | `street_address`, `city`, `postal_code` | Quasi-identifiers (re-id risk rises sharply when joined with birth_date — see §4) |
| `customers` | `birth_date` | Quasi-identifier / sensitive attribute |
| `employees` | `first_name`, `last_name`, `work_email` | Direct identifiers |
| `employees` | `hourly_wage` | Sensitive (compensation), not identifying — different handling than the rest, flagged separately |
| `employees` | `termination_date` | Sensitive HR status, not identifying |

Note the two employee columns (`hourly_wage`, `termination_date`) are sensitive-but-not-
identifying — a different risk category from "this reveals who someone is." Any real policy
should probably treat them separately from the identifier/quasi-identifier columns above,
not lump all "sensitive-sounding" columns into one bucket.

`state` (on `customers`) is a broad quasi-identifier (low re-identification power alone) and
is arguably fine to leave as-is; called out here only so the omission is a decision, not an
oversight.

## 3. Two implementation approaches

**A. ETL/view exclusion.** Silver/gold views simply don't project PII columns at all — the
column doesn't exist downstream. Unambiguous: nobody can misuse data that isn't there.
Cost: zero analytical value from the excluded column (no age-band analysis, no name-based
dedupe assistance, etc.) — and it's an all-or-nothing choice per column.

**B. In-place SQL masking/generalization.** Keep a transformed version of the column (e.g.
`birth_year` instead of `birth_date`, an `age_band` bucket, a hashed/truncated email domain
only). Preserves some analytical utility. Cost: still produces a column that *looks* like
real data and invites a downstream consumer to misuse it as more precise than it is; the
"how much detail is safe" question becomes a per-column judgment call rather than a bright
line, and needs its own justification and review each time.

**Recommendation (non-binding): prefer A (exclusion) as the default**, and only reach for B
where there's a specific, named analytical need that justifies keeping a reduced-fidelity
version — decided per column, not as a blanket policy. This is a preference, not a decision;
Ian's call.

## 4. Is a birth date with no year still PII?

Context for whoever picks this up: yes, potentially. Full DOB (month+day+year) is a clear
identifier. But even month+day alone is often still a quasi-identifier — HIPAA's Safe Harbor
de-identification method requires removing month and day from birth dates while *allowing*
year to remain (the inverse of "keep month/day, drop year"), precisely because month+day can
still fingerprint someone when joined with other data (e.g., a "closest birthday" match, or
combined with zip+gender — Sweeney's classic result that ZIP+DOB+gender uniquely identifies
~87% of the US population). Whether a reduced birth_date counts as PII in practice depends on
population size and what else it's joinable with in the same dataset — treat it as a
quasi-identifier requiring a real risk assessment, not something that's automatically safe
once you drop one field.

## 5. Conflict with existing project rules

`grounding/lessons.md` RULE-005: *"Silver flags, never filters — any transform that could
lose information keeps the raw column as `<name>_raw` and/or an `is_*` flag; row counts must
match bronze exactly."* This rule was written for analytical fidelity (prove nothing silently
disappeared), not for compliance. A real PII policy is the first case in this project where
"drop the information on purpose" is the *correct* behavior — RULE-005 as written would
actively fight that. If this is ever built, it needs to be a named, deliberate exception
(e.g., "RULE-005 applies to data-quality transforms; PII-designated columns are governed by
DEF-0xx instead and are explicitly exempt from the raw-preservation requirement") — not a
silent violation of an existing rule, and not a blanket repeal of RULE-005 either.

## 6. Suggested next steps (if/when Ian wants to build this)

1. Ian decides: exclusion-by-default, masking-by-default, or per-column (this doc doesn't
   decide it).
2. Draft `DEF-0xx` (Object-Level Security / PII Handling Policy) in the same style as
   DEF-020/021 — presented as a diff for approval per CLAUDE.md, not edited directly.
3. Amend `grounding/medallion-spec.md` with the RULE-005 exception language from §5.
4. New task brief: apply the approved policy to `oakhaven_silver`/`oakhaven_gold` views for
   the columns in §2 (whichever direction was chosen), plus a verify query proving the
   excluded/masked columns are actually gone or actually reduced (not just renamed).
5. Sub-agent chain: same as any other gold/silver change — `sql-builder` → `sql-validator` →
   Ian.

## 7. Explicitly out of scope of this proposal

- The bronze full-row export pack (TASK-20260706-01) itself is not retroactively changed by
  this proposal — it remains a deliberate, full-fidelity bronze mirror for Ian's own local use
  on synthetic data. This proposal is about what silver/gold expose to other consumers/tools,
  not about restricting Ian's own access to his own database.
- Row-level security (restricting which *rows* a consumer sees) is a different mechanism from
  object/column-level security and isn't addressed here.
