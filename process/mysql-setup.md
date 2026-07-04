# MySQL Setup — sql-practice agents (Windows)

## Connection (the only supported way)

The Windows MySQL client does NOT auto-read `~/.my.cnf`. Always pass the defaults file:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven -e "SELECT 1;"
```

- Server: Windows service `MySQL80`, host 127.0.0.1, user `claude`.
- NEVER read, print, or copy `.my.cnf` contents; never put credentials anywhere else.
- `--batch` → tab-separated output (what EXPECTED_OUTPUTS.md captures).
  `--table` → pretty grid (what a human sees running the same file). Both are valid
  renderings of the same result; captures use `--batch`.

## Multi-line SQL: use files, not -e

PowerShell quoting mangles multi-line `-e` strings (RULE-010). Run files instead:

```powershell
Get-Content outputs\TASK-XX\bronze\B01_row_counts.sql -Raw |
  & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch
```

Capture an expected output:

```powershell
Get-Content <file>.sql -Raw | & $mysql --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch |
  Set-Content -Encoding utf8 <file>.out.txt
```

## Write-scope boundary (contract, CLAUDE.md)

- `oakhaven`: READ ONLY. No exceptions.
- `oakhaven_silver`, `oakhaven_gold`: `CREATE SCHEMA IF NOT EXISTS`, `CREATE OR REPLACE VIEW`,
  `DROP VIEW` — only when the brief calls for it.
- Everything else (`common_db`, `sakila`, `squirrelpractice`, …): off limits.

## Refreshing grounding/schema.md

If the oakhaven schema ever changes (contract version bump upstream):

```powershell
# per table:
& $mysql --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch --raw --skip-column-names oakhaven -e "SHOW CREATE TABLE <t>;"
# plus exact COUNT(*) per table — update both sections and the 'Last verified' date.
```
