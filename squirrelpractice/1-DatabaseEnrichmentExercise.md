# Scenario

Practice DDL and DML while building out the practice database.  Start here if you do not have a database to use. 

## Steps
1. Run the CREATE TABLE and INSERT INTO queries from the included .sql file
2. Customize the prompt as needed.  My initial prompt and the resulting instructions are included below.
3. Once completed,  You will want to share the output back in the chat.

## Prompt, starting with table output:

Here's the table output for tables and columns in my practice database: 

TABLE_NAME 	 | COLUMN_NAME | DATA_TYPE  
sp_customers |	id		   | int  
sp_customers |	j		   | json  
sp_sales	 |	id		   | int  
sp_sales	 |	d		   | date  
sp_sales_rep |	id	       | int

I want to first rename the existing columns into more friendly names.  Then I want to add new columns and insert data into those new columns.  I will let you decide the specifics.  I also want to call out that the j, json column on sp_customers is there to stage up json arrays that I would have to use JSON_EXTRACT for.  Come up with some other name that represents an actual json array column I might expect to find on a customers table.   I want you to build out a practice training scenario that gives me the requirements without revealing the answer.  I will come back to this chat with the queries that I wrote as well as the output for assessment. 

### Prompt output

This is a great starting point. To make this practice highly relevant to the MySQL medallion architecture demo you are staging up for your GitHub portfolio, let's treat these initial tables as the raw "bronze" layer that needs some initial cleanup and enrichment before it can be properly modeled.

Here is your first set of training requirements.

#### Phase 1: Schema Refinement (Renaming Columns)

Your first task is to write the DDL (Data Definition Language) queries to rename the existing columns to be more descriptive and standard for a relational model.

**Requirements:**

1. **`sp_customers` table:** * Rename `id` to `customer_id`.
* Rename the `j` column to `contact_details`. This is a very common use case for JSON in customer tables, allowing you to store a flexible array of phone numbers, emails, and social media handles that we can later parse out using `JSON_EXTRACT()`.


2. **`sp_sales` table:**
* Rename `id` to `sale_id`.
* Rename `d` to `sale_date`.


3. **`sp_sales_rep` table:**
* Rename `id` to `rep_id`.



#### Phase 2: Schema Expansion (Adding Columns)

Now that the base columns have friendly names, we need to add the missing attributes to make these tables functional for a sales data pipeline.

**Requirements:**
Write the queries to add the following columns with appropriate data types (you decide the exact types, like `VARCHAR`, `DECIMAL`, etc.):

1. **`sp_customers` table:** Add a `customer_name` column and a `region` column.
2. **`sp_sales_rep` table:** Add a `rep_name` column and a `commission_rate` column.
3. **`sp_sales` table:** Add a `customer_id` column, a `rep_id` column, and a `sale_amount` column. *(Note: Don't worry about setting up foreign key constraints just yet, just get the columns added).*

#### Phase 3: Data Seeding (Inserting Records)

With the tables built out, it's time to load some initial mock data.

**Requirements:**
Write the DML (Data Manipulation Language) queries to insert **at least 3 rows** into each of the three tables.

* **Crucial JSON Requirement:** For the `sp_customers` table, ensure the `contact_details` column contains a valid JSON array of objects for each row. For example, structure it so it holds multiple contact methods like this:
`[{"type": "email", "value": "customer@email.com"}, {"type": "phone", "value": "555-0199"}]`

Whenever you are ready, reply with the SQL scripts you wrote for these three phases, along with the output of a `SELECT *` from each table so we can review your work and move on to the next step!
