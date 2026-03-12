CREATE TABLE sp_sales_rep(id INT);
CREATE TABLE sp_customers(id INT,j JSON);
CREATE TABLE sales(id INT,d DATE);
INSERT INTO sp_sales_rep VALUES(1),(2),(3),(4),(5),(6),(7);
INSERT INTO sp_customers VALUES(1,'[3]'),(2,'[4]'),(3,'[5]'),(4,'[6]'),(5,'[7]'),(6,'[8]'),(7,'[9]');
INSERT INTO sp_sales VALUES(1,'26-01-01'),(2,'26-01-02'),(3,'26-01-03'),(4,'26-01-04'),(5,'26-01-05'),(6,'26-01-06'),(7,'26-01-07');

-- Schema columns
SELECT 
    table_name, 
    column_name, 
    data_type
FROM 
    information_schema.columns
WHERE 
    table_schema = 'squirrelpractice'
    AND table_name LIKE 'sp_%'
ORDER BY 
    table_name, 
    ordinal_position;

/* Initial query output

TABLE_NAME 	 | COLUMN_NAME | DATA_TYPE
sp_customers |	id		  | int
sp_customers |	j		  | json
sp_sales	 |	id		  | int
sp_sales	 |	d		  | date
sp_sales_rep |	id	      | int

*/