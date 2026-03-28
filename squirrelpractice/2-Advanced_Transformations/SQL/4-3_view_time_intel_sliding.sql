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
with currentmonth AS (

select 
sale_date - interval(day(sale_date) - 1) day as sale_month,
SUM(sale_amount) as current_month_sales
from sp_sales 
group by sale_month

)
select *, 
-- optional parameter default value 
LAG(current_month_sales, 1,0) OVER(ORDER BY sale_month) as previous_month_sales,
-- IFNULL( LAG(current_month_sales, 1,0) OVER(ORDER BY sale_month),0) as prev_month_sales_ifnull,
-- COALESCE(LAG(current_month_sales, 1,0) OVER(ORDER BY sale_month),0) as prev_month_sales_coalesce
SUM(current_month_sales) OVER( PARTITION BY YEAR(sale_month) order by sale_month) as ytd_sales
from currentmonth;

select * from time_intel_windows;