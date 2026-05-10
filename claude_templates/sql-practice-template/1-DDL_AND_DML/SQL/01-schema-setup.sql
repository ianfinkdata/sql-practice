-- ============================================================
-- Exercise 1 — Schema Setup
-- Replace [your_schema] with your actual schema name.
-- ============================================================

USE [your_schema];

-- Step 1: Create bare-bones tables (intentionally under-specified)
-- Your job: enrich these in 02-enrichment.sql

CREATE TABLE customers (
    id INT,
    j  JSON
);

CREATE TABLE sales (
    id INT,
    d  DATE
);

CREATE TABLE sales_rep (
    id INT
);

-- Step 2: Insert seed rows
INSERT INTO sales_rep VALUES (1),(2),(3),(4),(5),(6),(7);

INSERT INTO customers VALUES
    (1, '[3]'),
    (2, '[4]'),
    (3, '[5]'),
    (4, '[6]'),
    (5, '[7]'),
    (6, '[8]'),
    (7, '[9]');

INSERT INTO sales VALUES
    (1, '2026-01-01'),
    (2, '2026-01-02'),
    (3, '2026-01-03'),
    (4, '2026-01-04'),
    (5, '2026-01-05'),
    (6, '2026-01-06'),
    (7, '2026-01-07');

-- Step 3: Inspect the schema — use this query to see what you have
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = '[your_schema]'
ORDER BY table_name, ordinal_position;
