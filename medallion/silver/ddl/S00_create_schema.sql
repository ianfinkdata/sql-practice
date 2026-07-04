-- TASK-20260704-03 · S00_create_schema.sql · 2026-07-04
-- PURPOSE: Create the silver schema (views only; no base tables — medallion-spec §Silver rules).
-- GROUNDING: grounding/medallion-spec.md §Layer map, §Silver rules
-- RUN: Get-Content S00_create_schema.sql -Raw | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-extra-file="C:\Users\ianfi\.my.cnf" --batch oakhaven
-- (PowerShell has no "<" input redirection — always the Get-Content pipe form; add --table for human-readable grids)

CREATE SCHEMA IF NOT EXISTS oakhaven_silver;
