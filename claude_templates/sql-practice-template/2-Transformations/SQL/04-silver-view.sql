-- ============================================================
-- Exercise 2, Step 4 — Wrap the query in a Silver view
--
-- Goal: Turn the Step 3 query into a reusable view.
-- Naming convention: silver_[descriptive_name]
--
-- Concepts: CREATE OR REPLACE VIEW
-- ============================================================

USE [your_schema];

CREATE OR REPLACE VIEW silver_sales_pipeline AS

-- TODO: Paste your complete Step 3 query here (without the final semicolon
-- until the very end of the CREATE OR REPLACE VIEW statement)

;

-- Immediately verify:
SELECT * FROM silver_sales_pipeline;
