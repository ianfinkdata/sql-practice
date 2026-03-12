-- Phase 1 - Renaming Columns
ALTER TABLE sp_customers RENAME COLUMN id TO customer_id;

ALTER TABLE sp_customers RENAME COLUMN j to contact_details;

ALTER TABLE sp_sales 
RENAME COLUMN id TO sale_id, 
RENAME COLUMN d TO sale_date;


ALTER TABLE sp_sales_rep 
RENAME COLUMN id TO rep_id;


-- Phase 2 - Adding Columns
ALTER TABLE sp_customers 
ADD customer_name VARCHAR(50), 
ADD region VARCHAR(50)  
;


ALTER TABLE sp_sales_rep
ADD rep_name VARCHAR(50), 
ADD commission_rate DECIMAL  
;

ALTER TABLE sp_sales
ADD customer_id INT, 
ADD rep_id INT,
ADD sale_amount DECIMAL
;

-- Phase 3 Inserting Records
SELECT * from sp_customers;

-- error about not having a primary key. made it the key first
ALTER TABLE sp_customers ADD PRIMARY KEY(customer_id);

UPDATE sp_customers SET contact_details = CASE
WHEN customer_id = 1 THEN '[{"type":"email","value":"customer1@abc.com"},{"type":"phone","value":"314-555-1111"}]'
WHEN customer_id = 2 THEN '[{"type":"email","value":"customer2@bbbb.com"},{"type":"phone","value":"314-555-2222"}]'
WHEN customer_id = 3 THEN '[{"type":"email","value":"customer3@ccc.com"},{"type":"phone","value":"314-555-3333"}]'
WHEN customer_id = 4 THEN '[{"type":"email","value":"customer4@ddd.com"},{"type":"phone","value":"314-555-4444"}]'
WHEN customer_id = 5 THEN '[{"type":"email","value":"customer5@eee.com"},{"type":"phone","value":"314-555-5555"}]'
WHEN customer_id = 6 THEN '[{"type":"email","value":"customer6@fff.com"},{"type":"phone","value":"314-555-6666"}]'
WHEN customer_id = 7 THEN '[{"type":"email","value":"customer7@ggg.com"},{"type":"phone","value":"314-555-7777"}]'
END WHERE customer_id BETWEEN 1 and 7;


UPDATE sp_customers SET region = 'Midwest' WHERE customer_id BETWEEN 1 AND 7;

SELECT * from sp_sales; 
-- customer_id, rep_id, sale_amount

SELECT * from sp_sales_rep;

UPDATE sp_sales_rep SET rep_name = 
CASE 
WHEN rep_id = 1 THEN 'Samuel Snake'
WHEN rep_id = 2 THEN 'Benjamin Boa'
WHEN rep_id = 3 THEN 'Thomas Tortoise'
END, 
commission_rate = .1 
WHERE rep_id > 1;

ALTER TABLE sp_sales_rep MODIFY commission_rate DECIMAL(4,2);

UPDATE sp_sales_rep set rep_name = 'Sammy Snake' WHERE rep_id = 1;

SELECT * FROM sp_sales;
SELECT * from sp_sales_rep;
SELECT * FROM sp_customers;

-- Great task to work WITH AI
UPDATE sp_sales SET 
 customer_id = CASE WHEN sale_id < 5 THEN sale_id ELSE 5 END,
 rep_id = CASE WHEN sale_id < 5 THEN 1 ELSE 2 END
WHERE sale_id <= 7;


UPDATE sp_sales
SET sale_amount = ROUND(RAND() * 3000 + 1500, 2)
WHERE sale_id <= 7;

ALTER TABLE sp_sales MODIFY sale_amount DECIMAL(10,2);

