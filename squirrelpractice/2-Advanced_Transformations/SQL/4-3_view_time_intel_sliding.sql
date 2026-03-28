/* 
The Final Boss: Tier 3 (The Sliding Frame Approach)
You are cleared to move on to the final challenge of this exercise.

Target View Name: vw_time_intel_rolling
Business Requirement: Create a view that breaks down performance geographically. For every month and for every region, display the current month's total revenue and a Rolling 3-Month Average Revenue (which should calculate the average of the current month and the two strictly preceding months for that specific region).

Technical Constraints:
You must use advanced window framing clauses (e.g., ROWS BETWEEN ...) to isolate the 3-month window.
The rolling average must respect the regional partitions (the Midwest average should not be skewed by another region's data).
Remember, you'll need to join your fact table (sp_sales) to the dimension table (sp_customers) to get the region attribute before you aggregate!

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