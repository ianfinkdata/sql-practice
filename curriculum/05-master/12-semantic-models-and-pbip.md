# 12: Semantic Models, Power BI PBIP, & Logic Sprawl Prevention

## Concept Explainer

When building an enterprise data architecture, transformations can be executed at two distinct layers:
1. **The Database Engine (SQL Pushdown)**: Computations, joins, aggregations, and business logic are executed directly in SQL views within the data warehouse or database (e.g. `project/oakhaven.db`).
2. **The Presentation/Semantic Layer (Power BI DAX / TMDL)**: Raw relational tables are loaded into BI engines, where relationships, calculated columns, and measures are declared in semantic model definitions like **TMDL (Tabular Model Definition Language)** or **DAX**.

Understanding where business logic should reside—and preventing **logic sprawl** (where different BI tools invent divergent definitions for the same metric)—is a core discipline for senior data engineers and analytics engineers.

---

## Why It Matters

In many organizations, business logic accidentally splits across multiple systems:
- A SQL view computes `net_amount = quantity * unit_price * (1 - discount_pct)`.
- A Power BI model re-implements `Net Revenue = SUMX(Sales, Sales[Quantity] * Sales[UnitPrice])` in DAX.
- A secondary dashboard filters `order_status = 'Completed'` directly in Power Query M.

When definitions diverge, stakeholders see conflicting numbers for the same KPI. **Centralizing business logic in verified SQL Gold views** ensures consistent metrics across Power BI, Python notebooks, web dashboards, and SQL clients.

---

## Power BI Project (`.pbip`) & TMDL Architecture

Modern BI tools store semantic models as text files under version control. In Power BI Projects (`.pbip`), model metadata is defined in `.tmdl` files:

```
pbip_poc/projects/
└── flat_sales_all/
    └── flat_sales_all.SemanticModel/
        └── definition/
            ├── model.tmdl              ← Model settings & table references
            ├── relationships.tmdl      ← 1:N relationship keys
            └── tables/
                ├── fact_sales.tmdl     ← Table schema & M partition script
                └── dim_customer.tmdl   ← Dimension schema
```

By inspecting TMDL definitions directly in text editors or via CLI tools on Linux (such as `pbip_linter.py`), engineers can audit and lint semantic models without running Power BI Desktop.

---

## Verified Examples on Oakhaven Data

### Example 1: SQL Pushdown Model (One Flat Table)

Executing calculations directly in SQL before feeding BI presentation layers:

```sql
SELECT 
    f.order_id,
    f.order_line_id,
    f.order_date,
    c.full_name AS customer_name,
    p.product_name,
    f.quantity,
    f.net_amount,
    CASE 
        WHEN f.discount_pct >= 0.20 THEN 'High Discount (20%+)'
        WHEN f.discount_pct > 0 THEN 'Standard Discount'
        ELSE 'Full Price'
    END AS discount_tier
FROM fact_sales f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
LEFT JOIN dim_product p ON f.product_id = p.product_id
ORDER BY f.order_date DESC, f.order_id, f.order_line_id
LIMIT 5;
```

**Verified Live Query Output:**

```
order_id  order_line_id  order_date  customer_name  product_name         quantity  net_amount  discount_tier       
--------  -------------  ----------  -------------  -------------------  --------  ----------  --------------------
89        1              2026-06-30  Michele Perez  Meridian Chalk Bags  3         1689.04     Standard Discount   
89        2              2026-06-30  Michele Perez                       3         548.75      High Discount (20%+)
89        3              2026-06-30  Michele Perez  Highline Paddle      2         1471.08     Full Price          
342       1              2026-06-30  Jimmy Mullins  Glacier Snowshoe     2         164.37      High Discount (20%+)
2342      1              2026-06-30  Tyler Rush     Switchback Sandals   1         130.47      Standard Discount   
```

---

## Common Mistakes

1. **Duplicate Business Logic**: Calculating metrics twice (once in SQL, once in DAX) with subtle variations (e.g. handling of NULL discounts or canceled orders).
2. **Hardcoded Machine Dependencies**: Embedding hardcoded local file paths (e.g. `C:\Users\...`) inside M partition queries instead of dynamic environment parameters.
3. **Bypassing the Medallion Pipeline**: Querying messy Bronze tables directly in BI reports rather than clean Gold star-schema views.

---

## Key Takeaways

- **Push Down Heavy Transformations**: Perform joins, data cleaning, and core business metrics in SQL views (`project/gold/`).
- **Use TMDL for Semantic Metadata**: Leverage Power BI Project (`.pbip`) text files to version-control 1:N relationships and DAX measures.
- **Audit Semantic Models with Linters**: Run automated TMDL linters in CI/CD pipelines to ensure cross-platform compatibility and logic consistency.
