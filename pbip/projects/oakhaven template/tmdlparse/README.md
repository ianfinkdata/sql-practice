# TMDL Parsing & SQL Extraction Toolkit (Tmdlparse)

This toolkit contains Python utilities for splitting monolithic Power BI TMDL exports, extracting Power Query M expressions, and restoring embedded SQL statements to standard ANSI SQL.

---

## 📁 Directory Structure

`	ext
tmdlparse/
│
├── split_full_tmdl.py`````# Section 1: Splits monolithic TMDL into PBIP .SemanticModel layout
├── extract_m_and_sql.py````# Sections 2 & 3: Extracts raw M code & restores clean ANSI SQL queries
├── oakhaventemplateFullTMDL.txt# Source Full TMDL script input
│
├── m_code/`````````` # Section 2 Outputs: 13 extracted raw Power Query .m scripts
│` ├── sql_fact_sales.m
│` ├── flat_sales_all.m
│` └── ...
│
└── sql_queries/````````# Section 3 Outputs: 13 restored standard ANSI .sql queries
``├── sql_fact_sales.sql
``├── sql_flat_sales_all.sql
``└── ...
`

---

## 🚀 How to Run

### 1. Split Full Monolithic TMDL
`powershell
python split_full_tmdl.py
`

### 2. Extract M Expressions & Restore ANSI SQL Queries
`powershell
python extract_m_and_sql.py
`
