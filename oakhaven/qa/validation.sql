-- ============================================================================
-- Oakhaven Outfitters — QA validation suite (Agent D)
-- Contract: DATA_CONTRACT.md v1.1, §6 acceptance criteria 1–10 + §4 D1–D25
-- Read-only: SELECT-only. Rerunnable. Every check emits one row:
--   check_id | description | expected | actual | result
-- Run:  Get-Content qa/validation.sql -Raw |
--         mysql --defaults-extra-file=... --skip-column-names oakhaven
-- Known exceptions (approved):
--   C8.03 — exactly 1 return_date = order date (2026-06-30 refunded order cap)
--   store_id 13 (WEB) is a legitimate fulfillment center in inventory_movements
--   shipments.delivered_date_raw is analytic VARCHAR, exempt from window checks
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Criterion 1 — Row counts vs §2
-- ---------------------------------------------------------------------------
SELECT 'C1.01','row count: stores','=13',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=13,'PASS','FAIL') FROM stores;
SELECT 'C1.02','row count: product_categories','=24',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=24,'PASS','FAIL') FROM product_categories;
SELECT 'C1.03','row count: suppliers','=45',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=45,'PASS','FAIL') FROM suppliers;
SELECT 'C1.04','row count: employees','=240',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=240,'PASS','FAIL') FROM employees;
SELECT 'C1.05','row count: products','=850',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=850,'PASS','FAIL') FROM products;
SELECT 'C1.06','row count: customers','=12000',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=12000,'PASS','FAIL') FROM customers;
SELECT 'C1.07','row count: promotions','=70',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=70,'PASS','FAIL') FROM promotions;
SELECT 'C1.08','row count: calendar','=7670',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=7670,'PASS','FAIL') FROM calendar;
SELECT 'C1.09','row count: orders','=60000',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=60000,'PASS','FAIL') FROM orders;
SELECT 'C1.10','row count: order_items','=156190',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=156190,'PASS','FAIL') FROM order_items;
SELECT 'C1.11','row count: payments (66000 +/-5%)','62700..69300',CAST(COUNT(*) AS CHAR),IF(COUNT(*) BETWEEN 62700 AND 69300,'PASS','FAIL') FROM payments;
SELECT 'C1.12','row count: shipments (29800 +/-5%)','28310..31290',CAST(COUNT(*) AS CHAR),IF(COUNT(*) BETWEEN 28310 AND 31290,'PASS','FAIL') FROM shipments;
SELECT 'C1.13','row count: returns (4900 +/-10%)','4410..5390',CAST(COUNT(*) AS CHAR),IF(COUNT(*) BETWEEN 4410 AND 5390,'PASS','FAIL') FROM returns;
SELECT 'C1.14','row count: inventory_movements (90000 +/-5%)','85500..94500',CAST(COUNT(*) AS CHAR),IF(COUNT(*) BETWEEN 85500 AND 94500,'PASS','FAIL') FROM inventory_movements;

-- ---------------------------------------------------------------------------
-- Criterion 2 — PK uniqueness (COUNT(*) = COUNT(DISTINCT pk), no NULLs)
-- ---------------------------------------------------------------------------
SELECT 'C2.01','PK unique: stores.store_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT store_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT store_id),'PASS','FAIL') FROM stores;
SELECT 'C2.02','PK unique: product_categories.category_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT category_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT category_id),'PASS','FAIL') FROM product_categories;
SELECT 'C2.03','PK unique: suppliers.supplier_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT supplier_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT supplier_id),'PASS','FAIL') FROM suppliers;
SELECT 'C2.04','PK unique: employees.employee_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT employee_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT employee_id),'PASS','FAIL') FROM employees;
SELECT 'C2.05','PK unique: products.product_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT product_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT product_id),'PASS','FAIL') FROM products;
SELECT 'C2.06','PK unique: customers.customer_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT customer_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT customer_id),'PASS','FAIL') FROM customers;
SELECT 'C2.07','PK unique: promotions.promo_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT promo_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT promo_id),'PASS','FAIL') FROM promotions;
SELECT 'C2.08','PK unique: calendar.date_key','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT date_key) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT date_key),'PASS','FAIL') FROM calendar;
SELECT 'C2.09','PK unique: orders.order_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT order_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT order_id),'PASS','FAIL') FROM orders;
SELECT 'C2.10','PK unique: order_items.order_item_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT order_item_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT order_item_id),'PASS','FAIL') FROM order_items;
SELECT 'C2.11','PK unique: payments.payment_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT payment_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT payment_id),'PASS','FAIL') FROM payments;
SELECT 'C2.12','PK unique: shipments.shipment_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT shipment_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT shipment_id),'PASS','FAIL') FROM shipments;
SELECT 'C2.13','PK unique: returns.return_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT return_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT return_id),'PASS','FAIL') FROM returns;
SELECT 'C2.14','PK unique: inventory_movements.movement_id','0 dup/null',CAST(COUNT(*)-COUNT(DISTINCT movement_id) AS CHAR),IF(COUNT(*)=COUNT(DISTINCT movement_id),'PASS','FAIL') FROM inventory_movements;

-- ---------------------------------------------------------------------------
-- Criterion 3 — FK constraints declared + anti-join orphan checks (16 FKs)
-- ---------------------------------------------------------------------------
SELECT 'C3.00','declared FK constraints in schema','>=15',CAST(COUNT(*) AS CHAR),IF(COUNT(*)>=15,'PASS','FAIL')
FROM information_schema.referential_constraints WHERE constraint_schema='oakhaven';
SELECT 'C3.01','orphans: employees.store_id -> stores','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM employees e LEFT JOIN stores s ON e.store_id=s.store_id WHERE e.store_id IS NOT NULL AND s.store_id IS NULL;
SELECT 'C3.02','orphans: employees.manager_id -> employees','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM employees e LEFT JOIN employees m ON e.manager_id=m.employee_id WHERE e.manager_id IS NOT NULL AND m.employee_id IS NULL;
SELECT 'C3.03','orphans: product_categories.parent_category_id -> self','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM product_categories c LEFT JOIN product_categories p ON c.parent_category_id=p.category_id WHERE c.parent_category_id IS NOT NULL AND p.category_id IS NULL;
SELECT 'C3.04','orphans: products.category_id -> product_categories','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM products pr LEFT JOIN product_categories c ON pr.category_id=c.category_id WHERE pr.category_id IS NOT NULL AND c.category_id IS NULL;
SELECT 'C3.05','orphans: products.supplier_id -> suppliers','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM products pr LEFT JOIN suppliers s ON pr.supplier_id=s.supplier_id WHERE pr.supplier_id IS NOT NULL AND s.supplier_id IS NULL;
SELECT 'C3.06','orphans: orders.customer_id -> customers','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM orders o LEFT JOIN customers c ON o.customer_id=c.customer_id WHERE o.customer_id IS NOT NULL AND c.customer_id IS NULL;
SELECT 'C3.07','orphans: orders.store_id -> stores','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM orders o LEFT JOIN stores s ON o.store_id=s.store_id WHERE o.store_id IS NOT NULL AND s.store_id IS NULL;
SELECT 'C3.08','orphans: orders.employee_id -> employees','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM orders o LEFT JOIN employees e ON o.employee_id=e.employee_id WHERE o.employee_id IS NOT NULL AND e.employee_id IS NULL;
SELECT 'C3.09','orphans: orders.promo_id -> promotions','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM orders o LEFT JOIN promotions p ON o.promo_id=p.promo_id WHERE o.promo_id IS NOT NULL AND p.promo_id IS NULL;
SELECT 'C3.10','orphans: order_items.order_id -> orders','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM order_items oi LEFT JOIN orders o ON oi.order_id=o.order_id WHERE oi.order_id IS NOT NULL AND o.order_id IS NULL;
SELECT 'C3.11','orphans: order_items.product_id -> products','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM order_items oi LEFT JOIN products p ON oi.product_id=p.product_id WHERE oi.product_id IS NOT NULL AND p.product_id IS NULL;
SELECT 'C3.12','orphans: payments.order_id -> orders','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM payments pm LEFT JOIN orders o ON pm.order_id=o.order_id WHERE pm.order_id IS NOT NULL AND o.order_id IS NULL;
SELECT 'C3.13','orphans: shipments.order_id -> orders','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM shipments sh LEFT JOIN orders o ON sh.order_id=o.order_id WHERE sh.order_id IS NOT NULL AND o.order_id IS NULL;
SELECT 'C3.14','orphans: returns.order_item_id -> order_items','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM returns r LEFT JOIN order_items oi ON r.order_item_id=oi.order_item_id WHERE r.order_item_id IS NOT NULL AND oi.order_item_id IS NULL;
SELECT 'C3.15','orphans: inventory_movements.product_id -> products','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM inventory_movements m LEFT JOIN products p ON m.product_id=p.product_id WHERE m.product_id IS NOT NULL AND p.product_id IS NULL;
SELECT 'C3.16','orphans: inventory_movements.store_id -> stores','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM inventory_movements m LEFT JOIN stores s ON m.store_id=s.store_id WHERE m.store_id IS NOT NULL AND s.store_id IS NULL;

-- ---------------------------------------------------------------------------
-- Criterion 4 — zero NULLs in every structural (locked) column, per §3
-- ---------------------------------------------------------------------------
SELECT 'C4.01','no NULLs: stores(store_id,store_code,city,state,opened_date)','0',
CAST(SUM((store_id IS NULL)+(store_code IS NULL)+(city IS NULL)+(state IS NULL)+(opened_date IS NULL)) AS CHAR),
IF(SUM((store_id IS NULL)+(store_code IS NULL)+(city IS NULL)+(state IS NULL)+(opened_date IS NULL))=0,'PASS','FAIL') FROM stores;
SELECT 'C4.02','no NULLs: employees(employee_id,first_name,last_name,store_id,hire_date,hourly_wage)','0',
CAST(SUM((employee_id IS NULL)+(first_name IS NULL)+(last_name IS NULL)+(store_id IS NULL)+(hire_date IS NULL)+(hourly_wage IS NULL)) AS CHAR),
IF(SUM((employee_id IS NULL)+(first_name IS NULL)+(last_name IS NULL)+(store_id IS NULL)+(hire_date IS NULL)+(hourly_wage IS NULL))=0,'PASS','FAIL') FROM employees;
SELECT 'C4.03','no NULLs: suppliers(supplier_id,supplier_name,country,lead_time_days,active_flag)','0',
CAST(SUM((supplier_id IS NULL)+(supplier_name IS NULL)+(country IS NULL)+(lead_time_days IS NULL)+(active_flag IS NULL)) AS CHAR),
IF(SUM((supplier_id IS NULL)+(supplier_name IS NULL)+(country IS NULL)+(lead_time_days IS NULL)+(active_flag IS NULL))=0,'PASS','FAIL') FROM suppliers;
SELECT 'C4.04','no NULLs: product_categories(category_id,category_name)','0',
CAST(SUM((category_id IS NULL)+(category_name IS NULL)) AS CHAR),
IF(SUM((category_id IS NULL)+(category_name IS NULL))=0,'PASS','FAIL') FROM product_categories;
SELECT 'C4.05','no NULLs: products(product_id,sku,product_name,category_id,supplier_id,unit_cost,list_price,intro_date,discontinued_flag)','0',
CAST(SUM((product_id IS NULL)+(sku IS NULL)+(product_name IS NULL)+(category_id IS NULL)+(supplier_id IS NULL)+(unit_cost IS NULL)+(list_price IS NULL)+(intro_date IS NULL)+(discontinued_flag IS NULL)) AS CHAR),
IF(SUM((product_id IS NULL)+(sku IS NULL)+(product_name IS NULL)+(category_id IS NULL)+(supplier_id IS NULL)+(unit_cost IS NULL)+(list_price IS NULL)+(intro_date IS NULL)+(discontinued_flag IS NULL))=0,'PASS','FAIL') FROM products;
SELECT 'C4.06','no NULLs: customers(customer_id,first_name,last_name,street_address,city,state,postal_code,signup_date,loyalty_tier,marketing_opt_in)','0',
CAST(SUM((customer_id IS NULL)+(first_name IS NULL)+(last_name IS NULL)+(street_address IS NULL)+(city IS NULL)+(state IS NULL)+(postal_code IS NULL)+(signup_date IS NULL)+(loyalty_tier IS NULL)+(marketing_opt_in IS NULL)) AS CHAR),
IF(SUM((customer_id IS NULL)+(first_name IS NULL)+(last_name IS NULL)+(street_address IS NULL)+(city IS NULL)+(state IS NULL)+(postal_code IS NULL)+(signup_date IS NULL)+(loyalty_tier IS NULL)+(marketing_opt_in IS NULL))=0,'PASS','FAIL') FROM customers;
SELECT 'C4.07','no NULLs: promotions(promo_id,promo_code,start_date,end_date,discount_pct)','0',
CAST(SUM((promo_id IS NULL)+(promo_code IS NULL)+(start_date IS NULL)+(end_date IS NULL)+(discount_pct IS NULL)) AS CHAR),
IF(SUM((promo_id IS NULL)+(promo_code IS NULL)+(start_date IS NULL)+(end_date IS NULL)+(discount_pct IS NULL))=0,'PASS','FAIL') FROM promotions;
SELECT 'C4.08','no NULLs: calendar(date_key,date)','0',
CAST(SUM((date_key IS NULL)+(date IS NULL)) AS CHAR),
IF(SUM((date_key IS NULL)+(date IS NULL))=0,'PASS','FAIL') FROM calendar;
SELECT 'C4.09','no NULLs: orders(order_id,customer_id,store_id,channel,order_ts,status,order_total_text)','0',
CAST(SUM((order_id IS NULL)+(customer_id IS NULL)+(store_id IS NULL)+(channel IS NULL)+(order_ts IS NULL)+(status IS NULL)+(order_total_text IS NULL)) AS CHAR),
IF(SUM((order_id IS NULL)+(customer_id IS NULL)+(store_id IS NULL)+(channel IS NULL)+(order_ts IS NULL)+(status IS NULL)+(order_total_text IS NULL))=0,'PASS','FAIL') FROM orders;
SELECT 'C4.10','no NULLs: order_items(order_item_id,order_id,product_id,quantity,unit_price,line_discount_pct)','0',
CAST(SUM((order_item_id IS NULL)+(order_id IS NULL)+(product_id IS NULL)+(quantity IS NULL)+(unit_price IS NULL)+(line_discount_pct IS NULL)) AS CHAR),
IF(SUM((order_item_id IS NULL)+(order_id IS NULL)+(product_id IS NULL)+(quantity IS NULL)+(unit_price IS NULL)+(line_discount_pct IS NULL))=0,'PASS','FAIL') FROM order_items;
SELECT 'C4.11','no NULLs: payments(payment_id,order_id,payment_ts,method,amount,status)','0',
CAST(SUM((payment_id IS NULL)+(order_id IS NULL)+(payment_ts IS NULL)+(method IS NULL)+(amount IS NULL)+(status IS NULL)) AS CHAR),
IF(SUM((payment_id IS NULL)+(order_id IS NULL)+(payment_ts IS NULL)+(method IS NULL)+(amount IS NULL)+(status IS NULL))=0,'PASS','FAIL') FROM payments;
SELECT 'C4.12','no NULLs: shipments(shipment_id,order_id,carrier,shipped_ts,tracking_number,ship_cost)','0',
CAST(SUM((shipment_id IS NULL)+(order_id IS NULL)+(carrier IS NULL)+(shipped_ts IS NULL)+(tracking_number IS NULL)+(ship_cost IS NULL)) AS CHAR),
IF(SUM((shipment_id IS NULL)+(order_id IS NULL)+(carrier IS NULL)+(shipped_ts IS NULL)+(tracking_number IS NULL)+(ship_cost IS NULL))=0,'PASS','FAIL') FROM shipments;
SELECT 'C4.13','no NULLs: returns(return_id,order_item_id,return_date,quantity_returned,refund_amount,condition_code)','0',
CAST(SUM((return_id IS NULL)+(order_item_id IS NULL)+(return_date IS NULL)+(quantity_returned IS NULL)+(refund_amount IS NULL)+(condition_code IS NULL)) AS CHAR),
IF(SUM((return_id IS NULL)+(order_item_id IS NULL)+(return_date IS NULL)+(quantity_returned IS NULL)+(refund_amount IS NULL)+(condition_code IS NULL))=0,'PASS','FAIL') FROM returns;
SELECT 'C4.14','no NULLs: inventory_movements(movement_id,product_id,store_id,movement_ts,movement_type,quantity)','0',
CAST(SUM((movement_id IS NULL)+(product_id IS NULL)+(store_id IS NULL)+(movement_ts IS NULL)+(movement_type IS NULL)+(quantity IS NULL)) AS CHAR),
IF(SUM((movement_id IS NULL)+(product_id IS NULL)+(store_id IS NULL)+(movement_ts IS NULL)+(movement_type IS NULL)+(quantity IS NULL))=0,'PASS','FAIL') FROM inventory_movements;

-- ---------------------------------------------------------------------------
-- Criterion 5 — dirty-quota registry D1–D25 (presence > 0; pct quota +/-40%)
-- ---------------------------------------------------------------------------
-- D1 customers.email: NULL 2% | N/A-or-none 1.5% | UPPERCASE 3% | trailing space 2%
SELECT 'D1a','customers.email NULL (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(email IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(email IS NULL)/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM customers;
SELECT 'D1b','customers.email N/A-or-none (quota 1.5%)','0.9..2.1%',CONCAT(ROUND(100*SUM(email IN ('N/A','none'))/COUNT(*),3),'%'),
IF(100*SUM(email IN ('N/A','none'))/COUNT(*) BETWEEN 0.9 AND 2.1,'PASS','FAIL') FROM customers;
SELECT 'D1c','customers.email UPPERCASE (quota 3%)','1.8..4.2%',CONCAT(ROUND(100*SUM(CAST(email AS BINARY)=CAST(UPPER(email) AS BINARY) AND email LIKE '%@%')/COUNT(*),3),'%'),
IF(100*SUM(CAST(email AS BINARY)=CAST(UPPER(email) AS BINARY) AND email LIKE '%@%')/COUNT(*) BETWEEN 1.8 AND 4.2,'PASS','FAIL') FROM customers;
SELECT 'D1d','customers.email trailing space (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(email LIKE '% ')/COUNT(*),3),'%'),
IF(100*SUM(email LIKE '% ')/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM customers;
-- D2 customers.phone six formats 60/20/10/5/1/4 %
SELECT 'D2a','customers.phone (206) 555-0143 fmt (quota 60%)','36..84%',CONCAT(ROUND(100*SUM(phone REGEXP '^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$')/COUNT(*),3),'%'),
IF(100*SUM(phone REGEXP '^\\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$')/COUNT(*) BETWEEN 36 AND 84,'PASS','FAIL') FROM customers;
SELECT 'D2b','customers.phone 206-555-0143 fmt (quota 20%)','12..28%',CONCAT(ROUND(100*SUM(phone REGEXP '^[0-9]{3}-[0-9]{3}-[0-9]{4}$')/COUNT(*),3),'%'),
IF(100*SUM(phone REGEXP '^[0-9]{3}-[0-9]{3}-[0-9]{4}$')/COUNT(*) BETWEEN 12 AND 28,'PASS','FAIL') FROM customers;
SELECT 'D2c','customers.phone 206.555.0143 fmt (quota 10%)','6..14%',CONCAT(ROUND(100*SUM(phone REGEXP '^[0-9]{3}\\.[0-9]{3}\\.[0-9]{4}$')/COUNT(*),3),'%'),
IF(100*SUM(phone REGEXP '^[0-9]{3}\\.[0-9]{3}\\.[0-9]{4}$')/COUNT(*) BETWEEN 6 AND 14,'PASS','FAIL') FROM customers;
SELECT 'D2d','customers.phone +1 206 555 0143 fmt (quota 5%)','3..7%',CONCAT(ROUND(100*SUM(phone REGEXP '^\\+1 [0-9]{3} [0-9]{3} [0-9]{4}$')/COUNT(*),3),'%'),
IF(100*SUM(phone REGEXP '^\\+1 [0-9]{3} [0-9]{3} [0-9]{4}$')/COUNT(*) BETWEEN 3 AND 7,'PASS','FAIL') FROM customers;
SELECT 'D2e','customers.phone N/A (quota 1%)','0.6..1.4%',CONCAT(ROUND(100*SUM(phone='N/A')/COUNT(*),3),'%'),
IF(100*SUM(phone='N/A')/COUNT(*) BETWEEN 0.6 AND 1.4,'PASS','FAIL') FROM customers;
SELECT 'D2f','customers.phone NULL (quota 4%)','2.4..5.6%',CONCAT(ROUND(100*SUM(phone IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(phone IS NULL)/COUNT(*) BETWEEN 2.4 AND 5.6,'PASS','FAIL') FROM customers;
-- D3 customers.state: full name 10% | abbrev-period 5%
SELECT 'D3a','customers.state full name (quota 10%)','6..14%',CONCAT(ROUND(100*SUM(CHAR_LENGTH(state)>2 AND state NOT LIKE '%.')/COUNT(*),3),'%'),
IF(100*SUM(CHAR_LENGTH(state)>2 AND state NOT LIKE '%.')/COUNT(*) BETWEEN 6 AND 14,'PASS','FAIL') FROM customers;
SELECT 'D3b','customers.state abbrev-period (quota 5%)','3..7%',CONCAT(ROUND(100*SUM(state LIKE '%.')/COUNT(*),3),'%'),
IF(100*SUM(state LIKE '%.')/COUNT(*) BETWEEN 3 AND 7,'PASS','FAIL') FROM customers;
-- D4 customers.city: lead/trail space 2% | ALLCAPS 2% | lowercase 2%
SELECT 'D4a','customers.city lead/trail space (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(city<>TRIM(city))/COUNT(*),3),'%'),
IF(100*SUM(city<>TRIM(city))/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM customers;
SELECT 'D4b','customers.city ALLCAPS (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(CAST(city AS BINARY)=CAST(UPPER(city) AS BINARY) AND CAST(city AS BINARY)<>CAST(LOWER(city) AS BINARY))/COUNT(*),3),'%'),
IF(100*SUM(CAST(city AS BINARY)=CAST(UPPER(city) AS BINARY) AND CAST(city AS BINARY)<>CAST(LOWER(city) AS BINARY))/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM customers;
SELECT 'D4c','customers.city lowercase (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(CAST(city AS BINARY)=CAST(LOWER(city) AS BINARY) AND CAST(city AS BINARY)<>CAST(UPPER(city) AS BINARY))/COUNT(*),3),'%'),
IF(100*SUM(CAST(city AS BINARY)=CAST(LOWER(city) AS BINARY) AND CAST(city AS BINARY)<>CAST(UPPER(city) AS BINARY))/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM customers;
-- D5 customers.birth_date: NULL 5% | 1900-01-01 0.5% | future 0.2% | age>95 0.3%
SELECT 'D5a','customers.birth_date NULL (quota 5%)','3..7%',CONCAT(ROUND(100*SUM(birth_date IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(birth_date IS NULL)/COUNT(*) BETWEEN 3 AND 7,'PASS','FAIL') FROM customers;
SELECT 'D5b','customers.birth_date 1900-01-01 sentinel (quota 0.5%)','0.3..0.7%',CONCAT(ROUND(100*SUM(birth_date='1900-01-01')/COUNT(*),3),'%'),
IF(100*SUM(birth_date='1900-01-01')/COUNT(*) BETWEEN 0.3 AND 0.7,'PASS','FAIL') FROM customers;
SELECT 'D5c','customers.birth_date future (quota 0.2%)','0.12..0.28%',CONCAT(ROUND(100*SUM(birth_date>'2026-06-30')/COUNT(*),3),'%'),
IF(100*SUM(birth_date>'2026-06-30')/COUNT(*) BETWEEN 0.12 AND 0.28,'PASS','FAIL') FROM customers;
SELECT 'D5d','customers.birth_date age>95 (quota 0.3%)','0.18..0.42%',CONCAT(ROUND(100*SUM(birth_date<'1931-06-30' AND birth_date<>'1900-01-01')/COUNT(*),3),'%'),
IF(100*SUM(birth_date<'1931-06-30' AND birth_date<>'1900-01-01')/COUNT(*) BETWEEN 0.18 AND 0.42,'PASS','FAIL') FROM customers;
-- D6 customers.loyalty_tier wrong casing 5%
SELECT 'D6','customers.loyalty_tier casing dirt (quota 5%)','3..7%',CONCAT(ROUND(100*SUM(CAST(loyalty_tier AS BINARY) NOT IN ('Basic','Silver','Gold','Platinum'))/COUNT(*),3),'%'),
IF(100*SUM(CAST(loyalty_tier AS BINARY) NOT IN ('Basic','Silver','Gold','Platinum'))/COUNT(*) BETWEEN 3 AND 7,'PASS','FAIL') FROM customers;
-- D7 near-dupe block 11851-12000 fully populated
SELECT 'D7','customers near-dupe ids 11851-12000 present','=150',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=150,'PASS','FAIL')
FROM customers WHERE customer_id BETWEEN 11851 AND 12000;
-- D8 orders.order_total_text: $1,234.56 90% | $1234.56 5% | no-$ 3% | leading space 2%
SELECT 'D8a','orders.order_total_text leading space (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(order_total_text LIKE ' %')/COUNT(*),3),'%'),
IF(100*SUM(order_total_text LIKE ' %')/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM orders;
SELECT 'D8b','orders.order_total_text no dollar sign (quota 3%)','1.8..4.2%',CONCAT(ROUND(100*SUM(order_total_text NOT LIKE '%$%')/COUNT(*),3),'%'),
IF(100*SUM(order_total_text NOT LIKE '%$%')/COUNT(*) BETWEEN 1.8 AND 4.2,'PASS','FAIL') FROM orders;
SELECT 'D8c','orders.order_total_text $-comma share of $-fmt >=1000 (quota 90/95=94.7%)','56.8..100%',
CONCAT(ROUND(100*SUM(order_total_text REGEXP '^\\$[0-9]{1,3}(,[0-9]{3})+\\.[0-9]{2}$')/SUM(order_total_text LIKE '$%' AND CAST(REPLACE(REPLACE(order_total_text,'$',''),',','') AS DECIMAL(12,2))>=1000),3),'%'),
IF(100*SUM(order_total_text REGEXP '^\\$[0-9]{1,3}(,[0-9]{3})+\\.[0-9]{2}$')/SUM(order_total_text LIKE '$%' AND CAST(REPLACE(REPLACE(order_total_text,'$',''),',','') AS DECIMAL(12,2))>=1000) BETWEEN 56.8 AND 100,'PASS','FAIL') FROM orders;
SELECT 'D8d','orders.order_total_text $-no-comma share of $-fmt >=1000 (quota 5/95=5.3%)','3.2..7.4%',
CONCAT(ROUND(100*SUM(order_total_text REGEXP '^\\$[0-9]{4,}\\.[0-9]{2}$')/SUM(order_total_text LIKE '$%' AND CAST(REPLACE(REPLACE(order_total_text,'$',''),',','') AS DECIMAL(12,2))>=1000),3),'%'),
IF(100*SUM(order_total_text REGEXP '^\\$[0-9]{4,}\\.[0-9]{2}$')/SUM(order_total_text LIKE '$%' AND CAST(REPLACE(REPLACE(order_total_text,'$',''),',','') AS DECIMAL(12,2))>=1000) BETWEEN 3.2 AND 7.4,'PASS','FAIL') FROM orders;
-- D9 orders.order_notes 20% non-NULL
SELECT 'D9','orders.order_notes non-NULL (quota 20%)','12..28%',CONCAT(ROUND(100*SUM(order_notes IS NOT NULL)/COUNT(*),3),'%'),
IF(100*SUM(order_notes IS NOT NULL)/COUNT(*) BETWEEN 12 AND 28,'PASS','FAIL') FROM orders;
-- D10 shipments.delivered_date_raw: ISO 55 | MM/DD/YYYY 30 | Mon D, YYYY 5 | PENDING 4 | NULL 6 %
SELECT 'D10a','shipments.delivered_date_raw YYYY-MM-DD (quota 55%)','33..77%',CONCAT(ROUND(100*SUM(delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')/COUNT(*),3),'%'),
IF(100*SUM(delivered_date_raw REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')/COUNT(*) BETWEEN 33 AND 77,'PASS','FAIL') FROM shipments;
SELECT 'D10b','shipments.delivered_date_raw MM/DD/YYYY (quota 30%)','18..42%',CONCAT(ROUND(100*SUM(delivered_date_raw REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$')/COUNT(*),3),'%'),
IF(100*SUM(delivered_date_raw REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$')/COUNT(*) BETWEEN 18 AND 42,'PASS','FAIL') FROM shipments;
SELECT 'D10c','shipments.delivered_date_raw Mon D, YYYY (quota 5%)','3..7%',CONCAT(ROUND(100*SUM(delivered_date_raw REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$')/COUNT(*),3),'%'),
IF(100*SUM(delivered_date_raw REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$')/COUNT(*) BETWEEN 3 AND 7,'PASS','FAIL') FROM shipments;
SELECT 'D10d','shipments.delivered_date_raw PENDING (quota 4%)','2.4..5.6%',CONCAT(ROUND(100*SUM(delivered_date_raw='PENDING')/COUNT(*),3),'%'),
IF(100*SUM(delivered_date_raw='PENDING')/COUNT(*) BETWEEN 2.4 AND 5.6,'PASS','FAIL') FROM shipments;
SELECT 'D10e','shipments.delivered_date_raw NULL (quota 6%)','3.6..8.4%',CONCAT(ROUND(100*SUM(delivered_date_raw IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(delivered_date_raw IS NULL)/COUNT(*) BETWEEN 3.6 AND 8.4,'PASS','FAIL') FROM shipments;
-- D11 shipments.carrier casing variants 6%
SELECT 'D11','shipments.carrier casing variants (quota 6%)','3.6..8.4%',CONCAT(ROUND(100*SUM(CAST(carrier AS BINARY) NOT IN ('UPS','FedEx','USPS','OnTrac'))/COUNT(*),3),'%'),
IF(100*SUM(CAST(carrier AS BINARY) NOT IN ('UPS','FedEx','USPS','OnTrac'))/COUNT(*) BETWEEN 3.6 AND 8.4,'PASS','FAIL') FROM shipments;
-- D12 payments.method >= 8 distinct spellings
SELECT 'D12','payments.method distinct spellings','>=8',CAST(COUNT(DISTINCT CAST(method AS BINARY)) AS CHAR),
IF(COUNT(DISTINCT CAST(method AS BINARY))>=8,'PASS','FAIL') FROM payments;
-- D13 products.weight_kg NULL 6% | -999 1%
SELECT 'D13a','products.weight_kg NULL (quota 6%)','3.6..8.4%',CONCAT(ROUND(100*SUM(weight_kg IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(weight_kg IS NULL)/COUNT(*) BETWEEN 3.6 AND 8.4,'PASS','FAIL') FROM products;
SELECT 'D13b','products.weight_kg -999 sentinel (quota 1%)','0.6..1.4%',CONCAT(ROUND(100*SUM(weight_kg=-999)/COUNT(*),3),'%'),
IF(100*SUM(weight_kg=-999)/COUNT(*) BETWEEN 0.6 AND 1.4,'PASS','FAIL') FROM products;
-- D14 products.discontinued_flag >= 5 distinct values
SELECT 'D14','products.discontinued_flag distinct values','>=5',CAST(COUNT(DISTINCT CAST(discontinued_flag AS BINARY)) AS CHAR),
IF(COUNT(DISTINCT CAST(discontinued_flag AS BINARY))>=5,'PASS','FAIL') FROM products;
-- D15 products.product_name: double space 3% | trailing space 2% | ALLCAPS 1%
SELECT 'D15a','products.product_name double space (quota 3%)','1.8..4.2%',CONCAT(ROUND(100*SUM(product_name LIKE '%  %')/COUNT(*),3),'%'),
IF(100*SUM(product_name LIKE '%  %')/COUNT(*) BETWEEN 1.8 AND 4.2,'PASS','FAIL') FROM products;
SELECT 'D15b','products.product_name trailing space (quota 2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(product_name LIKE '% ')/COUNT(*),3),'%'),
IF(100*SUM(product_name LIKE '% ')/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM products;
SELECT 'D15c','products.product_name ALLCAPS (quota 1%)','0.6..1.4%',CONCAT(ROUND(100*SUM(CAST(product_name AS BINARY)=CAST(UPPER(product_name) AS BINARY) AND product_name REGEXP '[A-Za-z]')/COUNT(*),3),'%'),
IF(100*SUM(CAST(product_name AS BINARY)=CAST(UPPER(product_name) AS BINARY) AND product_name REGEXP '[A-Za-z]')/COUNT(*) BETWEEN 0.6 AND 1.4,'PASS','FAIL') FROM products;
-- D16 products.list_price below unit_cost ~2%
SELECT 'D16','products.list_price < unit_cost (quota ~2%)','1.2..2.8%',CONCAT(ROUND(100*SUM(list_price<unit_cost)/COUNT(*),3),'%'),
IF(100*SUM(list_price<unit_cost)/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM products;
-- D17 order_items.unit_price penny error 0.2%
SELECT 'D17','order_items.unit_price = 0.01 (quota 0.2%)','0.12..0.28%',CONCAT(ROUND(100*SUM(unit_price=0.01)/COUNT(*),3),'%'),
IF(100*SUM(unit_price=0.01)/COUNT(*) BETWEEN 0.12 AND 0.28,'PASS','FAIL') FROM order_items;
-- D18 employees.hourly_wage outlier > 150 (>= 2 rows)
SELECT 'D18','employees.hourly_wage > 150 outliers','>=2',CAST(SUM(hourly_wage>150) AS CHAR),
IF(SUM(hourly_wage>150)>=2,'PASS','FAIL') FROM employees;
-- D19 employees.job_title casing variants 6%
SELECT 'D19','employees.job_title casing variants (quota 6%)','3.6..8.4%',
CONCAT(ROUND(100*SUM(CAST(job_title AS BINARY) NOT IN ('Store Manager','Assistant Manager','Sales Associate','Cashier','Web Support','Buyer','Warehouse Lead'))/COUNT(*),3),'%'),
IF(100*SUM(CAST(job_title AS BINARY) NOT IN ('Store Manager','Assistant Manager','Sales Associate','Cashier','Web Support','Buyer','Warehouse Lead'))/COUNT(*) BETWEEN 3.6 AND 8.4,'PASS','FAIL') FROM employees;
-- D20 suppliers.country >= 3 USA codings
SELECT 'D20','suppliers.country USA codings','>=3',CAST(COUNT(DISTINCT country) AS CHAR),
IF(COUNT(DISTINCT country)>=3,'PASS','FAIL') FROM suppliers WHERE country IN ('USA','US','United States','U.S.','U.S.A.');
-- D21 suppliers.lead_time_days -999 sentinels exactly 2
SELECT 'D21','suppliers.lead_time_days = -999 sentinels','=2',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=2,'PASS','FAIL')
FROM suppliers WHERE lead_time_days=-999;
-- D22 returns.reason NULL 6% + casing dupes present
SELECT 'D22a','returns.reason NULL (quota 6%)','3.6..8.4%',CONCAT(ROUND(100*SUM(reason IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(reason IS NULL)/COUNT(*) BETWEEN 3.6 AND 8.4,'PASS','FAIL') FROM returns;
SELECT 'D22b','returns.reason casing-dupe groups','>0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)>0,'PASS','FAIL')
FROM (SELECT LOWER(TRIM(reason)) k FROM returns WHERE reason IS NOT NULL GROUP BY LOWER(TRIM(reason)) HAVING COUNT(DISTINCT CAST(reason AS BINARY))>1) x;
-- D23 inventory_movements.reference: MIGRATION 3% | junk 2% | NULL 25%
SELECT 'D23a','inventory_movements.reference MIGRATION (quota 3%)','1.8..4.2%',CONCAT(ROUND(100*SUM(reference='MIGRATION')/COUNT(*),3),'%'),
IF(100*SUM(reference='MIGRATION')/COUNT(*) BETWEEN 1.8 AND 4.2,'PASS','FAIL') FROM inventory_movements;
SELECT 'D23b','inventory_movements.reference junk (quota 2%)','1.2..2.8%',
CONCAT(ROUND(100*SUM(reference IS NOT NULL AND reference<>'MIGRATION' AND reference NOT REGEXP '^(PO|SO|TR|ADJ)-[0-9]+$')/COUNT(*),3),'%'),
IF(100*SUM(reference IS NOT NULL AND reference<>'MIGRATION' AND reference NOT REGEXP '^(PO|SO|TR|ADJ)-[0-9]+$')/COUNT(*) BETWEEN 1.2 AND 2.8,'PASS','FAIL') FROM inventory_movements;
SELECT 'D23c','inventory_movements.reference NULL (quota 25%)','15..35%',CONCAT(ROUND(100*SUM(reference IS NULL)/COUNT(*),3),'%'),
IF(100*SUM(reference IS NULL)/COUNT(*) BETWEEN 15 AND 35,'PASS','FAIL') FROM inventory_movements;
-- D24 orders before customer signup (migration artifact) — must be > 0
SELECT 'D24','orders with order_ts < customer signup_date (emergent)','>0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)>0,'PASS','FAIL')
FROM orders o JOIN customers c ON o.customer_id=c.customer_id WHERE o.order_ts < c.signup_date;
-- D25 shipments.tracking_number duplicated values ~1% of rows involved
SELECT 'D25','shipments rows sharing a tracking_number (quota ~1%)','0.6..1.4%',
CONCAT(ROUND(100*dup_rows/total,3),'%'),IF(100*dup_rows/total BETWEEN 0.6 AND 1.4,'PASS','FAIL')
FROM (SELECT (SELECT COUNT(*) FROM shipments s JOIN (SELECT tracking_number FROM shipments GROUP BY tracking_number HAVING COUNT(*)>1) d USING (tracking_number)) dup_rows,
             (SELECT COUNT(*) FROM shipments) total) t;

-- ---------------------------------------------------------------------------
-- Criterion 6 — business window 2019-01-01 .. 2026-06-30 23:59:59
-- ---------------------------------------------------------------------------
SELECT 'C6.01','window: orders.order_ts','0 outside',
CONCAT(SUM(order_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59'),' outside; min=',MIN(order_ts),' max=',MAX(order_ts)),
IF(SUM(order_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59')=0,'PASS','FAIL') FROM orders;
SELECT 'C6.02','window: payments.payment_ts','0 outside',
CONCAT(SUM(payment_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59'),' outside; min=',MIN(payment_ts),' max=',MAX(payment_ts)),
IF(SUM(payment_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59')=0,'PASS','FAIL') FROM payments;
SELECT 'C6.03','window: shipments.shipped_ts','0 outside',
CONCAT(SUM(shipped_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59'),' outside; min=',MIN(shipped_ts),' max=',MAX(shipped_ts)),
IF(SUM(shipped_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59')=0,'PASS','FAIL') FROM shipments;
SELECT 'C6.04','window: inventory_movements.movement_ts','0 outside',
CONCAT(SUM(movement_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59'),' outside; min=',MIN(movement_ts),' max=',MAX(movement_ts)),
IF(SUM(movement_ts NOT BETWEEN '2019-01-01 00:00:00' AND '2026-06-30 23:59:59')=0,'PASS','FAIL') FROM inventory_movements;

-- ---------------------------------------------------------------------------
-- Criterion 7 — seasonality
-- ---------------------------------------------------------------------------
SELECT 'C7.01','seasonality: Jul 2025 orders > 1.5 x Feb 2025','jul > 1.5*feb',
CONCAT('jul=',SUM(order_ts>='2025-07-01' AND order_ts<'2025-08-01'),' feb=',SUM(order_ts>='2025-02-01' AND order_ts<'2025-03-01')),
IF(SUM(order_ts>='2025-07-01' AND order_ts<'2025-08-01') > 1.5*SUM(order_ts>='2025-02-01' AND order_ts<'2025-03-01'),'PASS','FAIL') FROM orders;
SELECT 'C7.02','seasonality: Apr 2020 orders < Jan 2020','apr < jan',
CONCAT('apr=',SUM(order_ts>='2020-04-01' AND order_ts<'2020-05-01'),' jan=',SUM(order_ts>='2020-01-01' AND order_ts<'2020-02-01')),
IF(SUM(order_ts>='2020-04-01' AND order_ts<'2020-05-01') < SUM(order_ts>='2020-01-01' AND order_ts<'2020-02-01'),'PASS','FAIL') FROM orders;
SELECT 'C7.03','seasonality: 2024 orders > 2021 orders','2024 > 2021',
CONCAT('y2024=',SUM(order_ts>='2024-01-01' AND order_ts<'2025-01-01'),' y2021=',SUM(order_ts>='2021-01-01' AND order_ts<'2022-01-01')),
IF(SUM(order_ts>='2024-01-01' AND order_ts<'2025-01-01') > SUM(order_ts>='2021-01-01' AND order_ts<'2022-01-01'),'PASS','FAIL') FROM orders;

-- ---------------------------------------------------------------------------
-- Criterion 8 — sequence sanity
-- ---------------------------------------------------------------------------
SELECT 'C8.01','shipped_ts >= order_ts violations','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM shipments sh JOIN orders o ON sh.order_id=o.order_id WHERE sh.shipped_ts < o.order_ts;
-- §3.9 "True total = Σ line quantity × unit_price × (1 − line_discount_pct/100),
-- rounded 2dp" parses two ways. Both are checked:
--   C8.02a — ROUND(SUM(line),2)  (sum-then-round)
--   C8.02b — SUM(ROUND(line,2))  (round-per-line; the convention Agent B used —
--            payments match it EXACTLY for all completed orders)
-- Known divergence: order 122965 (8 lines, all ending in .5 mills rounding up)
-- differs by $0.03 between the two conventions. RULED (DATA_CONTRACT.md v1.2,
-- 2026-07-02): C8.02a is retired, expected to show exactly 1 FAIL forever;
-- C8.02b (per-line rounding) is the binding check and must show 0.
SELECT 'C8.02a','completed orders: captured sum <> truth ROUND(SUM(line),2) (+/-0.02)','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM (
  SELECT o.order_id
  FROM orders o
  JOIN (SELECT order_id, ROUND(SUM(quantity*unit_price*(1-line_discount_pct/100)),2) truth
        FROM order_items GROUP BY order_id) t ON t.order_id=o.order_id
  LEFT JOIN (SELECT order_id, SUM(amount) cap FROM payments WHERE status='captured' GROUP BY order_id) p ON p.order_id=o.order_id
  WHERE o.status='completed' AND ABS(COALESCE(p.cap,0)-t.truth) > 0.02
) v;
SELECT 'C8.02b','completed orders: captured sum <> truth SUM(ROUND(line,2)) (+/-0.02)','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM (
  SELECT o.order_id
  FROM orders o
  JOIN (SELECT order_id, SUM(ROUND(quantity*unit_price*(1-line_discount_pct/100),2)) truth
        FROM order_items GROUP BY order_id) t ON t.order_id=o.order_id
  LEFT JOIN (SELECT order_id, SUM(amount) cap FROM payments WHERE status='captured' GROUP BY order_id) p ON p.order_id=o.order_id
  WHERE o.status='completed' AND ABS(COALESCE(p.cap,0)-t.truth) > 0.02
) v;
-- Known exception: exactly 1 approved violation (refunded order dated 2026-06-30,
-- return capped at window end so return_date = order date). 1 = PASS-with-note.
SELECT 'C8.03','return_date > DATE(order_ts) violations (1 approved cap case)','=1 (approved)',CAST(COUNT(*) AS CHAR),
CASE COUNT(*) WHEN 1 THEN 'PASS-with-note' ELSE 'FAIL' END
FROM returns r JOIN order_items oi ON r.order_item_id=oi.order_item_id JOIN orders o ON oi.order_id=o.order_id
WHERE r.return_date <= DATE(o.order_ts);
SELECT 'C8.04','quantity_returned > quantity violations','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM returns r JOIN order_items oi ON r.order_item_id=oi.order_item_id WHERE r.quantity_returned > oi.quantity;

-- ---------------------------------------------------------------------------
-- Criterion 9 — status logic
-- ---------------------------------------------------------------------------
SELECT 'C9.01','pending orders older than 14 days before 2026-06-30','0',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=0,'PASS','FAIL')
FROM orders WHERE status='pending' AND order_ts < '2026-06-16 00:00:00';
SELECT 'C9.02','cancelled orders with captured payments','0',CAST(COUNT(DISTINCT o.order_id) AS CHAR),IF(COUNT(DISTINCT o.order_id)=0,'PASS','FAIL')
FROM orders o JOIN payments p ON p.order_id=o.order_id AND p.status='captured' WHERE o.status='cancelled';
SELECT 'C9.03','cancelled orders with shipments','0',CAST(COUNT(DISTINCT o.order_id) AS CHAR),IF(COUNT(DISTINCT o.order_id)=0,'PASS','FAIL')
FROM orders o JOIN shipments s ON s.order_id=o.order_id WHERE o.status='cancelled';

-- ---------------------------------------------------------------------------
-- Criterion 10 — calendar (contract v1.3: generated directly, no common_db)
-- ---------------------------------------------------------------------------
SELECT 'C10.01','calendar row count','=7670',CAST(COUNT(*) AS CHAR),IF(COUNT(*)=7670,'PASS','FAIL') FROM calendar;
SELECT 'C10.02','calendar gapless on date','span=count, distinct=count',
CONCAT('span=',DATEDIFF(MAX(date),MIN(date))+1,' rows=',COUNT(*),' distinct=',COUNT(DISTINCT date)),
IF(DATEDIFF(MAX(date),MIN(date))+1=COUNT(*) AND COUNT(DISTINCT date)=COUNT(*),'PASS','FAIL') FROM calendar;
SELECT 'C10.03','calendar covers business window + full span','min=2018-01-01, max=2038-12-31',
CONCAT('min=',MIN(date),' max=',MAX(date)),
IF(MIN(date)='2018-01-01' AND MAX(date)='2038-12-31','PASS','FAIL') FROM calendar;

-- ---------------------------------------------------------------------------
-- Emergent anomalies — informational (counted and reported, not pass/fail
-- except D24 above which must be > 0)
-- ---------------------------------------------------------------------------
SELECT 'E01','INFO: inventory movements predating product intro_date','n/a (informational)',CAST(COUNT(*) AS CHAR),'INFO'
FROM inventory_movements m JOIN products p ON m.product_id=p.product_id WHERE m.movement_ts < p.intro_date;
