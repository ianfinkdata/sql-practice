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
s.sale_date,
d.date as calendar_sale_date,
d.week_start_date, 
-- sale_date - interval(day(sale_date) - 1) day as sale_month,
SUM(s.sale_amount) as current_period_sales
from sp_sales as s
join dimcalendar as d on d.date = s.sale_date
group by d.date

)

select * from rolling3monthavg WHERE Date >= DATE_FORMAT(CURRENT_DATE - INTERVAL 2 MONTH, '%Y-%m-01')
  AND Date <= LAST_DAY(CURRENT_DATE);