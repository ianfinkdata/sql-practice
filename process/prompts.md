# Prompt Templates

## P-001: Kick off a task
> Read CLAUDE.md, then process/briefs/TASK-<id>.md. Plan the smallest reusable units, name which sub-agent owns each, list required DEF IDs, and wait for my approval before executing.

## P-002: Approve the definitions gate
> Review grounding/definitions.md DEF-001…DEF-018. For each: approve, amend, or reject. On approval, bump the file header from DRAFT v0.1 to v1.0 with today's date.

## P-003: Weekly retrospective
> Read the entries in process/memory_log.md since the last RETRO: line. Identify recurring failure modes and root causes. Propose diffs to grounding/lessons.md, process/prompts.md, or .claude/agents/*. Output diffs only — do not apply them.

## P-004: New definition draft
> Draft a definitions.md entry for <metric> using the DEF template. Mark every field you inferred rather than confirmed. Output as a diff for my approval.

## P-005: Validate a layer
> Run sql-validator against outputs/TASK-<id>/. It must re-execute every .sql via the command in process/mysql-setup.md and diff stdout against EXPECTED_OUTPUTS.md. Report verdict + sanity plan; fix nothing.
