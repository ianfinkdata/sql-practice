-- Oakhaven bronze layer: raw, messy, as-ingested tables.
-- Deliberately NO primary keys, foreign keys, or CHECK constraints --
-- that omission is intentional (see docs/data_dictionary.md and the
-- Tier 4 constraints lesson, which contrasts this against proper DDL).

DROP TABLE IF EXISTS bronze_customers;
CREATE TABLE bronze_customers (
    customer_id     INTEGER,
    first_name      TEXT,
    last_name       TEXT,
    email           TEXT,
    phone           TEXT,
    state           TEXT,
    signup_date     TEXT,
    is_active       TEXT,
    customer_segment TEXT
);

DROP TABLE IF EXISTS bronze_products;
CREATE TABLE bronze_products (
    product_id      INTEGER,
    product_name    TEXT,
    category        TEXT,
    subcategory     TEXT,
    brand           TEXT,
    unit_cost       REAL,
    unit_price      REAL,
    is_discontinued TEXT,
    sku             TEXT,
    weight_kg       TEXT,
    created_at      TEXT
);

DROP TABLE IF EXISTS bronze_employees;
CREATE TABLE bronze_employees (
    employee_id       INTEGER,
    first_name        TEXT,
    last_name         TEXT,
    department        TEXT,
    region            TEXT,
    hire_date         TEXT,
    termination_date  TEXT,
    is_manager        TEXT,
    email             TEXT
);

DROP TABLE IF EXISTS bronze_sales;
CREATE TABLE bronze_sales (
    order_id        INTEGER,
    order_line_id   INTEGER,
    customer_id     INTEGER,
    product_id      INTEGER,
    employee_id     INTEGER,
    order_date      TEXT,
    ship_date       TEXT,
    quantity        INTEGER,
    unit_price      REAL,
    discount_pct    REAL,
    order_total     TEXT,
    payment_method  TEXT,
    order_status    TEXT,
    channel         TEXT
);

-- bronze_calendar is a manufactured date spine, not raw/messy data. Its
-- authoritative definition + population lives in
-- bronze/calendar_recursive_cte.sql (which re-creates this table via
-- DROP/CREATE so that file is runnable standalone). It is declared here
-- too purely so this file documents all 5 bronze tables in one place.
DROP TABLE IF EXISTS bronze_calendar;
CREATE TABLE bronze_calendar (
    datekey INTEGER,
    date    TEXT
);
