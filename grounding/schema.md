# Schema Snapshot — `oakhaven` (bronze)

Live-verified against local MySQL80 on **2026-07-04** via SHOW CREATE TABLE.
Agents ground SQL against THIS file; refresh procedure: `process/mysql-setup.md`.
Column-level business meaning and dirt quotas: `oakhaven/DATA_CONTRACT.md` §3–§4.

## Exact row counts (COUNT(*), 2026-07-04)

| Table | Rows | | Table | Rows |
|---|---|---|---|---|
| stores | 13 | | orders | 60,000 |
| employees | 240 | | order_items | 156,190 |
| suppliers | 45 | | payments | 66,663 |
| product_categories | 24 | | shipments | 29,784 |
| products | 850 | | returns | 5,010 |
| customers | 12,000 | | inventory_movements | 90,000 |
| promotions | 70 | | calendar | 4,748 |

## Verified enum censuses (bronze ground truth)

- `orders.status`: cancelled 1,689 · completed 55,917 · pending 11 · refunded 2,383
- `orders.channel`: STORE 32,819 · WEB 27,181
- `payments.status`: captured 60,615 · failed 3,665 · refunded 2,383
- `inventory_movements.movement_type`: adjustment 5,400 · receipt 19,800 · sale 57,600 · transfer_in 3,600 · transfer_out 3,600
- Order window: `order_ts` 2019-01-01 08:48:34 → 2026-06-30 21:34:10
- Calendar window: 2019-01-01 → 2031-12-31 (wider than facts — constrain in gold `dim_date`)

## Dirty columns at a glance (details: DATA_CONTRACT §4, D1–D25)

- **Text-that-should-be-typed:** orders.order_total_text (money), shipments.delivered_date_raw (date)
- **Flag chaos:** customers.marketing_opt_in, products.discontinued_flag, suppliers.active_flag
- **Format chaos:** customers.phone/state/city/email, payments.method, shipments.carrier, employees.job_title
- **Sentinels:** products.weight_kg = -999, suppliers.lead_time_days = -999, customers.birth_date = 1900-01-01/future
- **Near-dupes:** customers 11851–12000 fuzzy-copy 150 originals
- **Planted anomalies (leave visible, don't "fix"):** orders before signup_date; movements before product intro_date; penny-price lines (0.2%); below-cost list prices (~2%); transfer_out without transfer_in (1.5%)

---

# Live DDL (SHOW CREATE TABLE, verbatim)

## stores
```sql
CREATE TABLE `stores` (
  `store_id` int NOT NULL,
  `store_code` varchar(10) NOT NULL,
  `city` varchar(50) NOT NULL,
  `state` char(2) NOT NULL,
  `opened_date` date NOT NULL,
  `square_feet` int DEFAULT NULL,
  PRIMARY KEY (`store_id`),
  UNIQUE KEY `uq_stores_code` (`store_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## employees
```sql
CREATE TABLE `employees` (
  `employee_id` int NOT NULL,
  `first_name` varchar(40) NOT NULL,
  `last_name` varchar(40) NOT NULL,
  `job_title` varchar(60) NOT NULL,
  `store_id` int NOT NULL,
  `manager_id` int DEFAULT NULL,
  `hire_date` date NOT NULL,
  `termination_date` date DEFAULT NULL,
  `hourly_wage` decimal(6,2) NOT NULL,
  `work_email` varchar(120) NOT NULL,
  PRIMARY KEY (`employee_id`),
  KEY `fk_employees_store` (`store_id`),
  KEY `fk_employees_manager` (`manager_id`),
  CONSTRAINT `fk_employees_manager` FOREIGN KEY (`manager_id`) REFERENCES `employees` (`employee_id`),
  CONSTRAINT `fk_employees_store` FOREIGN KEY (`store_id`) REFERENCES `stores` (`store_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## suppliers
```sql
CREATE TABLE `suppliers` (
  `supplier_id` int NOT NULL,
  `supplier_name` varchar(80) NOT NULL,
  `country` varchar(30) NOT NULL,
  `contact_email` varchar(120) DEFAULT NULL,
  `phone` varchar(25) DEFAULT NULL,
  `lead_time_days` int NOT NULL,
  `active_flag` varchar(5) NOT NULL,
  PRIMARY KEY (`supplier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## product_categories
```sql
CREATE TABLE `product_categories` (
  `category_id` int NOT NULL,
  `category_name` varchar(50) NOT NULL,
  `parent_category_id` int DEFAULT NULL,
  PRIMARY KEY (`category_id`),
  KEY `fk_categories_parent` (`parent_category_id`),
  CONSTRAINT `fk_categories_parent` FOREIGN KEY (`parent_category_id`) REFERENCES `product_categories` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## products
```sql
CREATE TABLE `products` (
  `product_id` int NOT NULL,
  `sku` varchar(20) NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `category_id` int NOT NULL,
  `supplier_id` int NOT NULL,
  `unit_cost` decimal(8,2) NOT NULL,
  `list_price` decimal(8,2) NOT NULL,
  `weight_kg` decimal(7,2) DEFAULT NULL,
  `intro_date` date NOT NULL,
  `discontinued_flag` varchar(5) NOT NULL,
  `color` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`product_id`),
  UNIQUE KEY `uq_products_sku` (`sku`),
  KEY `fk_products_category` (`category_id`),
  KEY `fk_products_supplier` (`supplier_id`),
  CONSTRAINT `fk_products_category` FOREIGN KEY (`category_id`) REFERENCES `product_categories` (`category_id`),
  CONSTRAINT `fk_products_supplier` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`supplier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## customers
```sql
CREATE TABLE `customers` (
  `customer_id` int NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `middle_name` varchar(50) DEFAULT NULL,
  `last_name` varchar(50) NOT NULL,
  `email` varchar(120) DEFAULT NULL,
  `phone` varchar(25) DEFAULT NULL,
  `street_address` varchar(120) NOT NULL,
  `city` varchar(50) NOT NULL,
  `state` varchar(20) NOT NULL,
  `postal_code` varchar(10) NOT NULL,
  `birth_date` date DEFAULT NULL,
  `signup_date` date NOT NULL,
  `loyalty_tier` varchar(12) NOT NULL,
  `marketing_opt_in` varchar(5) NOT NULL,
  PRIMARY KEY (`customer_id`),
  KEY `ix_customers_state` (`state`),
  KEY `ix_customers_signup` (`signup_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## promotions
```sql
CREATE TABLE `promotions` (
  `promo_id` int NOT NULL,
  `promo_code` varchar(20) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `discount_pct` decimal(4,1) NOT NULL,
  `description` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`promo_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## calendar
```sql
CREATE TABLE `calendar` (
  `date_key` int GENERATED ALWAYS AS (cast(`date` as unsigned)) STORED NOT NULL,
  `date` date NOT NULL,
  `year` int DEFAULT NULL,
  `month_num` int DEFAULT NULL,
  `month` varchar(3) DEFAULT NULL,
  `quarter` int DEFAULT NULL,
  `week_day` int DEFAULT NULL,
  `week_day_name` varchar(3) DEFAULT NULL,
  `is_weekend` int NOT NULL DEFAULT '0',
  `week_start` date DEFAULT NULL,
  `iso_week_start` date DEFAULT NULL,
  PRIMARY KEY (`date_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## orders
```sql
CREATE TABLE `orders` (
  `order_id` int NOT NULL,
  `customer_id` int NOT NULL,
  `store_id` int NOT NULL,
  `employee_id` int DEFAULT NULL,
  `promo_id` int DEFAULT NULL,
  `channel` varchar(5) NOT NULL,
  `order_ts` datetime NOT NULL,
  `status` varchar(10) NOT NULL,
  `order_total_text` varchar(15) NOT NULL,
  `order_notes` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`order_id`),
  KEY `ix_orders_ts` (`order_ts`),
  KEY `ix_orders_status` (`status`),
  KEY `fk_orders_customer` (`customer_id`),
  KEY `fk_orders_store` (`store_id`),
  KEY `fk_orders_employee` (`employee_id`),
  KEY `fk_orders_promo` (`promo_id`),
  CONSTRAINT `fk_orders_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`),
  CONSTRAINT `fk_orders_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`employee_id`),
  CONSTRAINT `fk_orders_promo` FOREIGN KEY (`promo_id`) REFERENCES `promotions` (`promo_id`),
  CONSTRAINT `fk_orders_store` FOREIGN KEY (`store_id`) REFERENCES `stores` (`store_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## order_items
```sql
CREATE TABLE `order_items` (
  `order_item_id` bigint NOT NULL,
  `order_id` int NOT NULL,
  `product_id` int NOT NULL,
  `quantity` tinyint NOT NULL,
  `unit_price` decimal(8,2) NOT NULL,
  `line_discount_pct` decimal(4,1) NOT NULL,
  PRIMARY KEY (`order_item_id`),
  KEY `fk_items_order` (`order_id`),
  KEY `fk_items_product` (`product_id`),
  CONSTRAINT `fk_items_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`),
  CONSTRAINT `fk_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## payments
```sql
CREATE TABLE `payments` (
  `payment_id` int NOT NULL,
  `order_id` int NOT NULL,
  `payment_ts` datetime NOT NULL,
  `method` varchar(20) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` varchar(10) NOT NULL,
  `card_last4` char(4) DEFAULT NULL,
  PRIMARY KEY (`payment_id`),
  KEY `ix_payments_ts` (`payment_ts`),
  KEY `fk_payments_order` (`order_id`),
  CONSTRAINT `fk_payments_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## shipments
```sql
CREATE TABLE `shipments` (
  `shipment_id` int NOT NULL,
  `order_id` int NOT NULL,
  `carrier` varchar(20) NOT NULL,
  `shipped_ts` datetime NOT NULL,
  `delivered_date_raw` varchar(20) DEFAULT NULL,
  `tracking_number` varchar(30) NOT NULL,
  `ship_cost` decimal(6,2) NOT NULL,
  PRIMARY KEY (`shipment_id`),
  KEY `ix_shipments_shipped` (`shipped_ts`),
  KEY `fk_shipments_order` (`order_id`),
  CONSTRAINT `fk_shipments_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## returns
```sql
CREATE TABLE `returns` (
  `return_id` int NOT NULL,
  `order_item_id` bigint NOT NULL,
  `return_date` date NOT NULL,
  `quantity_returned` tinyint NOT NULL,
  `reason` varchar(100) DEFAULT NULL,
  `refund_amount` decimal(8,2) NOT NULL,
  `condition_code` varchar(10) NOT NULL,
  PRIMARY KEY (`return_id`),
  KEY `ix_returns_date` (`return_date`),
  KEY `fk_returns_item` (`order_item_id`),
  CONSTRAINT `fk_returns_item` FOREIGN KEY (`order_item_id`) REFERENCES `order_items` (`order_item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

## inventory_movements
```sql
CREATE TABLE `inventory_movements` (
  `movement_id` int NOT NULL,
  `product_id` int NOT NULL,
  `store_id` int NOT NULL,
  `movement_ts` datetime NOT NULL,
  `movement_type` varchar(15) NOT NULL,
  `quantity` int NOT NULL,
  `reference` varchar(40) DEFAULT NULL,
  `unit_cost_at_time` decimal(8,2) DEFAULT NULL,
  PRIMARY KEY (`movement_id`),
  KEY `ix_movements_ts` (`movement_ts`),
  KEY `fk_movements_product` (`product_id`),
  KEY `fk_movements_store` (`store_id`),
  CONSTRAINT `fk_movements_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`),
  CONSTRAINT `fk_movements_store` FOREIGN KEY (`store_id`) REFERENCES `stores` (`store_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```


