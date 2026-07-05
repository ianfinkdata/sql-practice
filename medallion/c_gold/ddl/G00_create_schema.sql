-- TASK-20260704-04 · G00_create_schema.sql · 2026-07-05
-- PURPOSE: Create the gold schema (views only; no base tables — medallion-spec §Gold rules).
-- GROUNDING: grounding/medallion-spec.md §Layer map, §Gold rules
-- RUN: Get-Content G00_create_schema.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)

CREATE SCHEMA IF NOT EXISTS oakhaven_gold;
