# End-to-End Data Pipeline Lineage & Architecture Report

This document provides full visibility into the **Oakhaven Medallion Data Architecture** and its mapping to **Power BI Semantic Models (`pbip/projects/`)**.

---

## 🏗️ 1. Medallion Architecture Summary

| Layer | Object Name | Object Type | Verified Row Count | Column Count | Primary Role |
| :--- | :--- | :--- | :---: | :---: | :--- |
| `Bronze` | `bronze_calendar` | TABLE | **7,670** | 2 | Medallion Data Pipeline Layer |
| `Bronze` | `bronze_customers` | TABLE | **600** | 9 | Medallion Data Pipeline Layer |
| `Bronze` | `bronze_employees` | TABLE | **35** | 9 | Medallion Data Pipeline Layer |
| `Bronze` | `bronze_products` | TABLE | **150** | 11 | Medallion Data Pipeline Layer |
| `Bronze` | `bronze_sales` | TABLE | **12,000** | 14 | Medallion Data Pipeline Layer |
| `Gold` | `dim_customer` | VIEW | **600** | 10 | Medallion Data Pipeline Layer |
| `Gold` | `dim_date` | VIEW | **7,670** | 10 | Medallion Data Pipeline Layer |
| `Gold` | `dim_employee` | VIEW | **35** | 10 | Medallion Data Pipeline Layer |
| `Gold` | `dim_product` | VIEW | **150** | 12 | Medallion Data Pipeline Layer |
| `Gold` | `fact_sales` | VIEW | **12,000** | 17 | Medallion Data Pipeline Layer |
| `Gold (Aggregations)` | `agg_customer_ltv` | VIEW | **600** | 9 | Medallion Data Pipeline Layer |
| `Gold (Aggregations)` | `agg_daily_sales` | VIEW | **2,007** | 7 | Medallion Data Pipeline Layer |
| `Gold (Aggregations)` | `agg_monthly_sales_by_category` | VIEW | **528** | 7 | Medallion Data Pipeline Layer |
| `Silver` | `silver_calendar` | VIEW | **7,670** | 2 | Medallion Data Pipeline Layer |
| `Silver` | `silver_customers` | VIEW | **600** | 10 | Medallion Data Pipeline Layer |
| `Silver` | `silver_employees` | VIEW | **35** | 10 | Medallion Data Pipeline Layer |
| `Silver` | `silver_products` | VIEW | **150** | 12 | Medallion Data Pipeline Layer |
| `Silver` | `silver_sales` | VIEW | **12,000** | 17 | Medallion Data Pipeline Layer |

---

## 🗺️ 2. Detailed Data Flow & Lineage Map

```mermaid
flowchart LR
    subgraph Bronze [Bronze Layer - Raw Ingestion]
        b_sales[bronze_sales] --> s_sales[silver_sales]
        b_cust[bronze_customers] --> s_cust[silver_customers]
        b_prod[bronze_products] --> s_prod[silver_products]
        b_emp[bronze_employees] --> s_emp[silver_employees]
        b_cal[bronze_calendar] --> s_cal[silver_calendar]
    end

    subgraph Silver [Silver Layer - Data Cleaning & Deduplication]
        s_sales --> g_fact[fact_sales]
        s_cust --> g_cust[dim_customer]
        s_prod --> g_prod[dim_product]
        s_emp --> g_emp[dim_employee]
        s_cal --> g_date[dim_date]
    end

    subgraph Gold [Gold Layer - Star Schema]
        g_fact & g_cust & g_prod & g_emp & g_date --> M1[01_flat_model.sql / flat_sales_all]
        g_fact & g_cust & g_prod & g_emp & g_date --> M2[02_star_schema_model.sql / fact_sales]
    end

    subgraph Semantic [Power BI Semantic Layer (.pbip / TMDL)]
        M1 --> PBIP_Flat[Flat_Sales_All.pbip]
        M2 --> PBIP_Star[Star_Schema_Enterprise.pbip]
    end
```

---

## 📊 3. Verification Audit (Repository Rule: 'Never Invent a Number')

- **Fact Sales (`fact_sales`)**: Exactly **12,000** rows
- **Customer Dimension (`dim_customer`)**: Exactly **600** rows
- **Product Dimension (`dim_product`)**: Exactly **150** rows
- **Employee Dimension (`dim_employee`)**: Exactly **35** rows
- **Date Dimension (`dim_date`)**: Exactly **7,670** rows
- **PoC SQL Query Limit (`LIMIT 100`)**: Fact query scoped to **100** fact rows with matching dimension subsets (58 customers, 71 products, 24 employees, 15 dates).
