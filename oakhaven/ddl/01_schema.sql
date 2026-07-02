-- Oakhaven Outfitters practice database — schema DDL
-- Contract: oakhaven/DATA_CONTRACT.md v1.0 (source of truth for all specs)
-- Rerunnable: drops child tables first, then parents.

CREATE DATABASE IF NOT EXISTS oakhaven
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE oakhaven;

DROP TABLE IF EXISTS inventory_movements;
DROP TABLE IF EXISTS `returns`;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS calendar;
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS product_categories;
DROP TABLE IF EXISTS stores;

-- ============================================================= dimensions

CREATE TABLE stores (
  store_id      INT          NOT NULL,
  store_code    VARCHAR(10)  NOT NULL,
  city          VARCHAR(50)  NOT NULL,
  state         CHAR(2)      NOT NULL,
  opened_date   DATE         NOT NULL,
  square_feet   INT          NULL,
  PRIMARY KEY (store_id),
  UNIQUE KEY uq_stores_code (store_code)
) ENGINE=InnoDB;

CREATE TABLE product_categories (
  category_id         INT         NOT NULL,
  category_name       VARCHAR(50) NOT NULL,
  parent_category_id  INT         NULL,
  PRIMARY KEY (category_id),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_category_id) REFERENCES product_categories (category_id)
) ENGINE=InnoDB;

CREATE TABLE suppliers (
  supplier_id     INT          NOT NULL,
  supplier_name   VARCHAR(80)  NOT NULL,
  country         VARCHAR(30)  NOT NULL,
  contact_email   VARCHAR(120) NULL,
  phone           VARCHAR(25)  NULL,
  lead_time_days  INT          NOT NULL,
  active_flag     VARCHAR(5)   NOT NULL,
  PRIMARY KEY (supplier_id)
) ENGINE=InnoDB;

CREATE TABLE employees (
  employee_id       INT           NOT NULL,
  first_name        VARCHAR(40)   NOT NULL,
  last_name         VARCHAR(40)   NOT NULL,
  job_title         VARCHAR(60)   NOT NULL,
  store_id          INT           NOT NULL,
  manager_id        INT           NULL,
  hire_date         DATE          NOT NULL,
  termination_date  DATE          NULL,
  hourly_wage       DECIMAL(6,2)  NOT NULL,
  work_email        VARCHAR(120)  NOT NULL,
  PRIMARY KEY (employee_id),
  CONSTRAINT fk_employees_store
    FOREIGN KEY (store_id) REFERENCES stores (store_id),
  CONSTRAINT fk_employees_manager
    FOREIGN KEY (manager_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB;

CREATE TABLE products (
  product_id         INT           NOT NULL,
  sku                VARCHAR(20)   NOT NULL,
  product_name       VARCHAR(100)  NOT NULL,
  category_id        INT           NOT NULL,
  supplier_id        INT           NOT NULL,
  unit_cost          DECIMAL(8,2)  NOT NULL,
  list_price         DECIMAL(8,2)  NOT NULL,
  weight_kg          DECIMAL(7,2)  NULL,
  intro_date         DATE          NOT NULL,
  discontinued_flag  VARCHAR(5)    NOT NULL,
  color              VARCHAR(30)   NULL,
  PRIMARY KEY (product_id),
  UNIQUE KEY uq_products_sku (sku),
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES product_categories (category_id),
  CONSTRAINT fk_products_supplier
    FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
) ENGINE=InnoDB;

CREATE TABLE customers (
  customer_id       INT           NOT NULL,
  first_name        VARCHAR(50)   NOT NULL,
  middle_name       VARCHAR(50)   NULL,
  last_name         VARCHAR(50)   NOT NULL,
  email             VARCHAR(120)  NULL,
  phone             VARCHAR(25)   NULL,
  street_address    VARCHAR(120)  NOT NULL,
  city              VARCHAR(50)   NOT NULL,
  state             VARCHAR(20)   NOT NULL,
  postal_code       VARCHAR(10)   NOT NULL,
  birth_date        DATE          NULL,
  signup_date       DATE          NOT NULL,
  loyalty_tier      VARCHAR(12)   NOT NULL,
  marketing_opt_in  VARCHAR(5)    NOT NULL,
  PRIMARY KEY (customer_id),
  KEY ix_customers_state (state),
  KEY ix_customers_signup (signup_date)
) ENGINE=InnoDB;

CREATE TABLE promotions (
  promo_id      INT           NOT NULL,
  promo_code    VARCHAR(20)   NOT NULL,
  start_date    DATE          NOT NULL,
  end_date      DATE          NOT NULL,
  discount_pct  DECIMAL(4,1)  NOT NULL,
  description   VARCHAR(200)  NULL,
  PRIMARY KEY (promo_id)
) ENGINE=InnoDB;

-- calendar: created and populated by 02_calendar_copy.sql (lift-and-shift of
-- common_db.dim_date, contract v1.1). Run 02 after this script on rebuilds.

-- ================================================================== facts

CREATE TABLE orders (
  order_id          INT           NOT NULL,
  customer_id       INT           NOT NULL,
  store_id          INT           NOT NULL,
  employee_id       INT           NULL,      -- STORE channel only
  promo_id          INT           NULL,
  channel           VARCHAR(5)    NOT NULL,  -- WEB | STORE
  order_ts          DATETIME      NOT NULL,
  status            VARCHAR(10)   NOT NULL,  -- completed|refunded|cancelled|pending
  order_total_text  VARCHAR(15)   NOT NULL,  -- deliberately dirty; truth = SUM(order_items)
  order_notes       VARCHAR(200)  NULL,
  PRIMARY KEY (order_id),
  KEY ix_orders_ts (order_ts),
  KEY ix_orders_status (status),
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
  CONSTRAINT fk_orders_store
    FOREIGN KEY (store_id) REFERENCES stores (store_id),
  CONSTRAINT fk_orders_employee
    FOREIGN KEY (employee_id) REFERENCES employees (employee_id),
  CONSTRAINT fk_orders_promo
    FOREIGN KEY (promo_id) REFERENCES promotions (promo_id)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  order_item_id      BIGINT        NOT NULL,
  order_id           INT           NOT NULL,
  product_id         INT           NOT NULL,
  quantity           TINYINT       NOT NULL,
  unit_price         DECIMAL(8,2)  NOT NULL,
  line_discount_pct  DECIMAL(4,1)  NOT NULL,
  PRIMARY KEY (order_item_id),
  CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products (product_id)
) ENGINE=InnoDB;

CREATE TABLE payments (
  payment_id  INT            NOT NULL,
  order_id    INT            NOT NULL,
  payment_ts  DATETIME       NOT NULL,
  method      VARCHAR(20)    NOT NULL,  -- deliberately inconsistent spellings
  amount      DECIMAL(10,2)  NOT NULL,  -- negative = refund row
  status      VARCHAR(10)    NOT NULL,  -- captured|failed|refunded
  card_last4  CHAR(4)        NULL,
  PRIMARY KEY (payment_id),
  KEY ix_payments_ts (payment_ts),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE=InnoDB;

CREATE TABLE shipments (
  shipment_id         INT           NOT NULL,
  order_id            INT           NOT NULL,
  carrier             VARCHAR(20)   NOT NULL,
  shipped_ts          DATETIME      NOT NULL,
  delivered_date_raw  VARCHAR(20)   NULL,     -- deliberately mixed date formats
  tracking_number     VARCHAR(30)   NOT NULL,
  ship_cost           DECIMAL(6,2)  NOT NULL,
  PRIMARY KEY (shipment_id),
  KEY ix_shipments_shipped (shipped_ts),
  CONSTRAINT fk_shipments_order
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE=InnoDB;

CREATE TABLE `returns` (
  return_id          INT           NOT NULL,
  order_item_id      BIGINT        NOT NULL,
  return_date        DATE          NOT NULL,
  quantity_returned  TINYINT       NOT NULL,
  reason             VARCHAR(100)  NULL,
  refund_amount      DECIMAL(8,2)  NOT NULL,
  condition_code     VARCHAR(10)   NOT NULL,
  PRIMARY KEY (return_id),
  KEY ix_returns_date (return_date),
  CONSTRAINT fk_returns_item
    FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id)
) ENGINE=InnoDB;

CREATE TABLE inventory_movements (
  movement_id        INT           NOT NULL,
  product_id         INT           NOT NULL,
  store_id           INT           NOT NULL,
  movement_ts        DATETIME      NOT NULL,
  movement_type      VARCHAR(15)   NOT NULL,  -- receipt|sale|adjustment|transfer_in|transfer_out
  quantity           INT           NOT NULL,  -- signed; never 0
  reference          VARCHAR(40)   NULL,
  unit_cost_at_time  DECIMAL(8,2)  NULL,
  PRIMARY KEY (movement_id),
  KEY ix_movements_ts (movement_ts),
  CONSTRAINT fk_movements_product
    FOREIGN KEY (product_id) REFERENCES products (product_id),
  CONSTRAINT fk_movements_store
    FOREIGN KEY (store_id) REFERENCES stores (store_id)
) ENGINE=InnoDB;
