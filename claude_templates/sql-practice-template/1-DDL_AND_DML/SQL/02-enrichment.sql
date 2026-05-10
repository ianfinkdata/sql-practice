-- ============================================================
-- Exercise 1 — Enrichment
-- Work through the three phases below.
-- Replace [your_schema] with your actual schema name.
-- ============================================================

USE [your_schema];

-- ============================================================
-- Phase 1: Rename columns to meaningful names
-- ============================================================

-- TODO: Rename customers.id → customer_id
-- TODO: Rename customers.j  → contact_details
-- TODO: Rename sales.id     → sale_id
-- TODO: Rename sales.d      → sale_date
-- TODO: Rename sales_rep.id → rep_id

-- Hint: ALTER TABLE table_name RENAME COLUMN old_name TO new_name;
-- MySQL 8.0+ allows multiple renames in one ALTER TABLE statement.

-- ============================================================
-- Phase 2: Add missing columns
-- ============================================================

-- TODO: Add to customers:  customer_name VARCHAR(50), region VARCHAR(50)
-- TODO: Add to sales_rep:  rep_name VARCHAR(50), commission_rate DECIMAL(4,2)
-- TODO: Add to sales:      customer_id INT, rep_id INT, sale_amount DECIMAL(10,2)

-- After adding, confirm with:
SELECT table_name, column_name, data_type, column_type
FROM information_schema.columns
WHERE table_schema = '[your_schema]'
ORDER BY table_name, ordinal_position;

-- ============================================================
-- Phase 3: Populate data
-- ============================================================

-- TODO: Add a primary key to customers before updating it
-- Hint: ALTER TABLE customers ADD PRIMARY KEY (customer_id);

-- TODO: Populate contact_details with JSON contact arrays
-- Format: [{"type":"email","value":"..."}, {"type":"phone","value":"..."}]
-- Use UPDATE ... SET contact_details = CASE WHEN customer_id = 1 THEN '...' ... END

-- TODO: Set region = 'YourRegion' for all customers

-- TODO: Populate rep_name and commission_rate in sales_rep using CASE WHEN

-- TODO: Link sales rows to customers and reps using UPDATE ... SET customer_id = CASE ... rep_id = CASE ...

-- TODO: Generate sale_amount values
-- Hint: ROUND(RAND() * 3000 + 1500, 2) gives a value between $1,500 and $4,500

-- Final check — should see all columns with data:
SELECT * FROM customers;
SELECT * FROM sales_rep;
SELECT * FROM sales;
