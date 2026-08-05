# PBIP + GitHub Proof of Concept: "Model of Models" & Logic Sprawl

This directory contains a proof-of-concept (PoC) architecture for managing **Power BI Projects (`.pbip`)** backed by a **SQLite data source** (`project/oakhaven.db`).

---

## 🎯 The Core Problem This Solves

Extracting raw SQL statements after they've been shredded through Power Query M, TMDL metadata, `.pbip` folder structures, and GitHub commits is a painful, time-consuming process.

**The Solution:** Maintain a clean **`sql_queries/`** directory where **each model gets exactly 1 master `.sql` file**. 
- Clear, commented table headers (`-- TABLE: table_name`) delineate individual queries.
- SQL code can be version-controlled directly alongside PBIP models.
- AI agents and developers can inspect business logic instantly without wasting time or tokens parsing deep TMDL / M code structures.

---

## 📁 Repository Structure

```
sql-practice/
└── pbip_poc/
    ├── readme_pbip_poc.md               ← You are here: Table of Contents & Architecture Guide
    ├── ai_usage_guide.md                ← Guide on checking usage, avoiding limits & token budgeting
    ├── sql_queries/
    │   ├── 01_flat_model.sql            ← One Flat Table paradigm (Denormalized reporting)
    │   └── 02_star_schema_model.sql     ← Star Schema paradigm (Fact + 4 Dimensions)
    └── projects/                        ← Destination folder for .pbip files & TMDL metadata
```

---

## 📊 Models & SQL Table Index

### 1. [`01_flat_model.sql`](sql_queries/01_flat_model.sql) (One Flat Table Paradigm)
*Designed for self-service or direct reporting models where all customer, product, employee, and sales fields are flattened into single queries.*

| Table Header in `.sql` | Target Row Count | Purpose & Business Logic |
| :--- | :---: | :--- |
| `flat_sales_all` | 100 rows | Main denormalized query. Contains SQL pushdown logic for `gross_amount`, `net_amount`, and `discount_tier`. |
| `flat_sales_completed_variant` | 100 rows | Logic sprawl variant. Demonstrates a second model using the same base query with a hardcoded `WHERE order_status = 'Completed'` filter. |

---

### 2. [`02_star_schema_model.sql`](sql_queries/02_star_schema_model.sql) (Traditional Star Schema)
*Designed for enterprise Power BI models with 1 central fact table joined to 4 dimension tables via 1:N relationships.*

| Table Header in `.sql` | Target Row Count | Relationship Key | Purpose |
| :--- | :---: | :---: | :--- |
| `fact_sales` | 100 rows | `order_id`, `order_line_id` | Central transaction fact table with order metrics. |
| `dim_customer` | ~58 rows | `customer_id` | Customer demographics, state, and segment. |
| `dim_product` | ~71 rows | `product_id` | Product catalog, categories, brand, cost, and price. |
| `dim_employee` | ~24 rows | `employee_id` | Sales rep region and department. |
| `dim_date` | ~15 rows | `datekey` | Date dimension attributes (year, month, quarter, day). |

*Note: Dimension row counts are dynamically scoped to match the 100 fact table rows.*

---

## 🧪 Testing Logic Sprawl Across Models

With these SQL source files, you can build 3 distinct PBIP models inside `pbip_poc/projects/`:

1. **`Flat_SQL_Pushdown.pbip`**: Reads from `01_flat_model.sql` (`flat_sales_all`). Business logic is executed on the database engine.
2. **`Flat_DAX_Logic.pbip`**: Reads raw sales columns and implements `Gross Sales`, `Net Sales`, and `Discount Tiers` via DAX Calculated Columns / Measures.
3. **`Star_Schema_Enterprise.pbip`**: Reads from `02_star_schema_model.sql` and wires standard 1:N relationships in the Power BI semantic model.

Comparing the Git diffs across these PBIP folders demonstrates exactly how business logic sprawl, M code variations, and TMDL metadata diverge across models over time.
