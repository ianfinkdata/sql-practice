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

rolling3montsales AS (

select
d.date as calendar_sale_date,
d.week_start_date, 
d.month_start_date,
-- sale_date - interval(day(sale_date) - 1) day as sale_month,
coalesce(SUM(s.sale_amount),0) as current_period_sales
from dimcalendar as d
left join sp_sales as s on d.date = s.sale_date
where d.month_start_date BETWEEN date_add(current_date, interval -3 month) and current_date
group by calendar_sale_date, week_start_date, month_start_date
)

select * from rolling3monthavg;
-- select * from dimcalendar;

select * from sp_sales; 

select * from sp_sales_rep;

select * from sp_customers;

ALTER TABLE common_db.dim_date 
    DROP COLUMN year_month_date;




