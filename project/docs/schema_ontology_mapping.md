# Oakhaven Schema, Ontology & Business Definition Mapping

> **Document Status:** Verified against `project/oakhaven.db` snapshot (Seed `20260630`).  
> **Target Audience:** Analytics Engineers, Data Modelers, and AI Assistants building ontology / semantic layers.

---

## 1. Executive Summary

This document maps the **Oakhaven** SQLite database pipeline—a medallion architecture (Bronze → Silver → Gold)—to a domain **Ontology Layer** (Entities, Relationships, and Attributes) and a **Business Definition Layer** (Semantic Metrics, KPI Formulas, and Transformation Logic).

### Data Pipeline Overview

- **Bronze (Raw Ingestion):** 5 raw tables populated with synthetic retail data containing deliberate data-quality defects (inconsistent text casing, mixed booleans, bad discounts, untrustworthy totals, and orphan foreign keys).
- **Silver (Standardized & Cleaned):** 5 views that standardize string formats, correct domain errors, derive full names, and flag anomaly records without dropping rows.
- **Gold (Star-Schema & Aggregates):** 5 dimensional/fact views and 4 pre-aggregated reporting views engineered for analytics consumption.

---

## 2. Catalog Metadata & Object Inventory

Every row count and column count below is an empirical, verified snapshot from `project/oakhaven.db`:

| Layer | Object Name | Object Type | Primary Key / Grain | Row Count | Column Count |
|---|---|---|---|---|---|
| **Bronze** | [`bronze_customers`](file:///home/ian/github/sql-practice/project/docs/data_dictionary.md#L21) | Table | `customer_id` (raw 1..600) | 600 | 9 |
| **Bronze** | [`bronze_products`](file:///home/ian/github/sql-practice/project/docs/data_dictionary.md#L46) | Table | `product_id` (raw 1..150) | 150 | 11 |
| **Bronze** | [`bronze_employees`](file:///home/ian/github/sql-practice/project/docs/data_dictionary.md#L64) | Table | `employee_id` (raw 1..35) | 35 | 9 |
| **Bronze** | [`bronze_sales`](file:///home/ian/github/sql-practice/project/docs/data_dictionary.md#L79) | Table | Order line (`order_id`, `order_line_id`) | 12,000 | 14 |
| **Bronze** | [`bronze_calendar`](file:///home/ian/github/sql-practice/project/docs/data_dictionary.md#L106) | Table | Date key (`datekey` `YYYYMMDD`) | 7,670 | 2 |
| **Silver** | `silver_customers` | View | `customer_id` | 600 | 10 |
| **Silver** | `silver_products` | View | `product_id` | 150 | 12 |
| **Silver** | `silver_employees` | View | `employee_id` | 35 | 10 |
| **Silver** | `silver_sales` | View | Order line (`order_id`, `order_line_id`) | 12,000 | 17 |
| **Silver** | `silver_calendar` | View | `datekey` | 7,670 | 2 |
| **Gold** | `dim_customer` | View | `customer_id` | 600 | 10 |
| **Gold** | `dim_product` | View | `product_id` | 150 | 12 |
| **Gold** | `dim_employee` | View | `employee_id` | 35 | 10 |
| **Gold** | `dim_date` | View | `datekey` | 7,670 | 10 |
| **Gold** | `dim_date_revised` | View | `datekey` | 7,670 | 12 |
| **Gold** | `fact_sales` | View | Order line (`order_id`, `order_line_id`) | 12,000 | 17 |
| **Gold** | `agg_customer_ltv` | View | `customer_id` | 600 | 9 |
| **Gold** | `agg_daily_sales` | View | `date` | 2,007 | 7 |
| **Gold** | `agg_monthly_sales_by_category` | View | (`year_month`, `category`) | 528 | 7 |

---

## 3. Domain Ontology Layer

The Ontology Layer models the core business concepts, their relationships, and properties.

```
                        +-------------------+
                        |    Date Entity    |
                        |   (dim_date)      |
                        +-------------------+
                        | PK: datekey       |
                        +---------+---------+
                                  |
                                  | 1:N (order_date)
                                  v
+-------------------+   +-------------------+   +-------------------+
|  Customer Entity  |   | Sales Event Line  |   |  Product Entity   |
|  (dim_customer)   |   |   (fact_sales)    |   |   (dim_product)   |
+-------------------+   +-------------------+   +-------------------+
| PK: customer_id   |<--| FK: customer_id   |-->| PK: product_id    |
+-------------------+ 1:N| FK: product_id    |1:N+-------------------+
                        | FK: employee_id   |
                        | FK: datekey       |
                        +---------+---------+
                                  ^
                                  | 1:N (optional)
                        +---------+---------+
                        |  Employee Entity  |
                        |  (dim_employee)   |
                        +-------------------+
                        | PK: employee_id   |
                        +-------------------+
```

### 3.1 Entities (Nodes)

1. **Customer (`Customer`)**
   - **Source:** `dim_customer` / `silver_customers`
   - **Key Attributes:** `customer_id` (ID), `full_name` (Text), `email` (Text), `state` (ISO Code), `signup_date` (ISO Date), `customer_segment` (`Retail` / `Wholesale` / `VIP`).
   - **Description:** Individual or organization purchasing outdoor products from Oakhaven.

2. **Product (`Product`)**
   - **Source:** `dim_product` / `silver_products`
   - **Key Attributes:** `product_id` (ID), `product_name` (Text), `category` (Text), `subcategory` (Text), `brand` (Text), `unit_cost` (Currency), `unit_price` (Currency), `sku` (Text), `is_discontinued` (Boolean).
   - **Description:** Retail item offered for purchase across 8 outdoor categories.

3. **Employee (`Employee`)**
   - **Source:** `dim_employee` / `silver_employees`
   - **Key Attributes:** `employee_id` (ID), `full_name` (Text), `department` (Text), `region` (Text), `hire_date` (ISO Date), `termination_date` (ISO Date / Null), `is_manager` (Boolean).
   - **Description:** Oakhaven staff member associated with point-of-sale transactions and regional management.

4. **Date / Time Spine (`CalendarDay`)**
   - **Source:** `dim_date` / `dim_date_revised`
   - **Key Attributes:** `datekey` (Integer `YYYYMMDD`), `date` (ISO Date), `year` (Integer), `quarter` (Text), `month` (Integer), `day_of_week` (Text), `is_weekend` (Boolean).
   - **Description:** Continuous date spine spanning 2018-01-01 through 2038-12-31 for trend analysis and zero-order day filling.

5. **Sales Transaction Line Event (`OrderLineEvent`)**
   - **Source:** `fact_sales` / `silver_sales`
   - **Key Attributes:** `order_id` (ID), `order_line_id` (Integer), `quantity` (Integer), `unit_price` (Currency), `discount_pct` (Percentage), `net_amount` (Currency), `payment_method` (Text), `order_status` (Text), `channel` (`Online` / `In-Store`).
   - **Description:** Granular event capturing item purchases, quantities, pricing, and fulfillment.

---

## 4. Business Definition & Semantic Layer

### 4.1 Core Metric Definitions

1. **Net Revenue (`net_amount`)**
   - **Formula:** $\text{quantity} \times \text{unit\_price} \times (1 - \text{discount\_pct})$
   - **Business Rule:** Raw `order_total` from Bronze is untrustworthy due to missing discounts, formatted strings (`$`), or pre-discount values. All revenue metrics MUST recompute from this formula.

2. **Customer Lifetime Value (LTV)**
   - **Formula:** $\sum \text{net\_amount} \quad \text{WHERE order\_status} \neq \text{'CANCELLED'}$
   - **Aggregation Grain:** Per `customer_id`.

3. **Daily Sales Volume**
   - **Formula:** Total net revenue per date joined against `dim_date` spine to preserve days with zero orders (`net_amount` coerced to `0.0`).

4. **Channel Classification**
   - **Online Channel:** `channel = 'Online'` (represented by `employee_id IS NULL`).
   - **In-Store Channel:** `channel = 'In-Store'` (serviced by an on-site employee).

### 4.2 Data Quality & Transformation Rules (Silver → Gold)

- **Discount Rate Normalization:** If $\text{discount\_pct} > 1.0$, transform using $\frac{\text{discount\_pct}}{100.0}$ (fixing whole-number entry errors like `15` $\rightarrow$ `0.15`).
- **Orphan Foreign Key Handling:**
  - `is_customer_orphan = 1` if `customer_id` is not present in `bronze_customers`.
  - `is_product_orphan = 1` if `product_id` is not present in `bronze_products`.
- **SKU Duplicate Flagging:** `sku_is_duplicate = 1` when an identical SKU string is shared across multiple `product_id` records.

---

## 5. Summary & Verification

This mapping has been derived empirically from `project/oakhaven.db`. Any downstream semantic tools, metadata cataloging, or ontology definitions can safely rely on these explicit table views, metric definitions, and column schemas.
