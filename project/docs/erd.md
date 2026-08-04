# Oakhaven — Entity Relationship Diagrams

Two diagrams: the raw bronze layer (no declared constraints — that's
deliberate, see `data_dictionary.md`) and the business-ready gold star
schema built on top of it via the silver cleaning layer.

Note: bronze has **no actual foreign keys** in the database (SQLite
enforces nothing here). The relationships below are the *intended*
ones, made real only after the silver/gold layers standardize types
and formats. Bronze also contains intentional orphan FKs
(`bronze_sales.customer_id` / `product_id` pointing at nonexistent
rows) and duplicate people/SKUs — the diagram shows the logical
relationship, not a guarantee that every row honors it.

## Bronze layer (raw, messy)

```mermaid
erDiagram
    bronze_customers {
        INTEGER customer_id
        TEXT first_name
        TEXT last_name
        TEXT email
        TEXT phone
        TEXT state
        TEXT signup_date
        TEXT is_active
        TEXT customer_segment
    }
    bronze_products {
        INTEGER product_id
        TEXT product_name
        TEXT category
        TEXT subcategory
        TEXT brand
        REAL unit_cost
        REAL unit_price
        TEXT is_discontinued
        TEXT sku
        TEXT weight_kg
        TEXT created_at
    }
    bronze_employees {
        INTEGER employee_id
        TEXT first_name
        TEXT last_name
        TEXT department
        TEXT region
        TEXT hire_date
        TEXT termination_date
        TEXT is_manager
        TEXT email
    }
    bronze_sales {
        INTEGER order_id
        INTEGER order_line_id
        INTEGER customer_id
        INTEGER product_id
        INTEGER employee_id
        TEXT order_date
        TEXT ship_date
        INTEGER quantity
        REAL unit_price
        REAL discount_pct
        TEXT order_total
        TEXT payment_method
        TEXT order_status
        TEXT channel
    }
    bronze_calendar {
        INTEGER datekey
        TEXT date
    }

    bronze_customers ||--o{ bronze_sales : "places (~1% orphaned)"
    bronze_products ||--o{ bronze_sales : "sold in (~1% orphaned)"
    bronze_employees |o--o{ bronze_sales : "sold by (~10% NULL)"
```

## Gold layer (star schema, business-ready)

```mermaid
erDiagram
    dim_customer {
        INTEGER customer_id PK
        TEXT full_name
        TEXT email
        TEXT phone
        TEXT state
        TEXT signup_date
        INTEGER is_active
        TEXT customer_segment
    }
    dim_product {
        INTEGER product_id PK
        TEXT product_name
        TEXT category
        TEXT subcategory
        TEXT brand
        REAL unit_cost
        REAL unit_price
        INTEGER is_discontinued
        TEXT sku
        INTEGER sku_is_duplicate
        REAL weight_kg
    }
    dim_employee {
        INTEGER employee_id PK
        TEXT full_name
        TEXT department
        TEXT region
        TEXT hire_date
        TEXT termination_date
        INTEGER is_manager
    }
    dim_date {
        INTEGER datekey PK
        TEXT date
        INTEGER year
        INTEGER month
        TEXT month_name
        INTEGER quarter
        INTEGER day_of_week
        TEXT day_name
        INTEGER is_weekend
    }
    fact_sales {
        INTEGER order_id
        INTEGER order_line_id
        INTEGER customer_id FK
        INTEGER product_id FK
        INTEGER employee_id FK
        INTEGER datekey FK
        INTEGER quantity
        REAL unit_price
        REAL discount_pct
        REAL net_amount
        TEXT payment_method
        TEXT order_status
        TEXT channel
        INTEGER is_customer_orphan
        INTEGER is_product_orphan
    }

    dim_customer ||--o{ fact_sales : "customer_id"
    dim_product ||--o{ fact_sales : "product_id"
    dim_employee |o--o{ fact_sales : "employee_id (nullable)"
    dim_date ||--o{ fact_sales : "datekey"
```

`fact_sales` grain = one row per order line. It carries FK columns to
all four dimensions but does **not** join to them internally — join
`fact_sales` to a dim view when you need that dimension's attributes.
`is_customer_orphan` / `is_product_orphan` flag the ~1% of rows whose
FK doesn't resolve against `dim_customer` / `dim_product`; `datekey`
is NULL when `order_date` itself was NULL in bronze (~0.5% of rows).
