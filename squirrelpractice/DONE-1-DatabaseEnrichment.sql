ALTER TABLE sp_customers RENAME COLUMN id TO customer_id;

ALTER TABLE sp_customers RENAME COLUMN j to contact_details;

ALTER TABLE sp_sales 
RENAME COLUMN id TO sale_id, 
RENAME COLUMN d TO sale_date;


ALTER TABLE sp_sales_rep 
RENAME COLUMN id TO rep_id;