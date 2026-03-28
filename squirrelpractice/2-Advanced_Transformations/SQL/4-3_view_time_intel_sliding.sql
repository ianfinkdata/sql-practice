/* 
The Final Boss (Tier 3): The Calendar Table Edition
Let's pivot the final challenge to incorporate your existing architecture.

Target View Name: vw_time_intel_rolling

Business Requirement: Create a view that breaks down performance geographically. 
For every month and for every region: 
	display the current month's total revenue
    a Rolling 3-Month Average Revenue (which should calculate the average of the current month and the two strictly preceding months for that specific region).

Technical Constraints:

The Join: You must join your Bronze sales data to your common_db.calendar table (or whatever it is named) to group the data by month, rather than calculating the month inline.
The Window: You must use advanced window framing clauses (e.g., ROWS BETWEEN...) to isolate the 3-month window.
The Partition: The rolling average must respect the regional partitions (the Midwest average should not be skewed by another region's data).

*/
with dimcalendar as ( 
select * from common_db.dim_date as cal
),

rolling3monthavg AS (

select 
sale_date - interval(day(sale_date) - 1) day as sale_month,
SUM(sale_amount) as current_month_sales
from sp_sales 

group by sale_month

)

select * from rolling3monthavg;

-- 1. Rename 'FullDate' to 'Date' and add the new columns
ALTER TABLE common_db.dim_date 
    CHANGE COLUMN FullDate Date DATE, 
    ADD COLUMN week_start_date DATE AFTER Date, 
    ADD COLUMN iso_week_start_date DATE AFTER week_start_date;

-- 2. Update the 'week_start_date' (Assuming Sunday as the start of the week)
UPDATE common_db.dim_date
SET week_start_date = DATE_ADD(Date, INTERVAL(1 - DAYOFWEEK(Date)) DAY);

-- 3. Update the 'iso_week_start_date' (ISO weeks always start on Monday)
UPDATE common_db.dim_date
SET iso_week_start_date = DATE_SUB(Date, INTERVAL WEEKDAY(Date) DAY);