/* 
Tier 2: The Analytical Approach
Target View Name: vw_time_intel_windows
Business Requirement: Create a view that returns a continuous monthly summary of the entire company's sales. 
For every month, show the current month's total revenue, the previous month's total revenue, and a Year-to-Date (YTD) cumulative total that resets every January 1st.
Technical Constraints:
You must accomplish both the prior-month retrieval and the YTD running total using Window Functions.
Self-joins for the purpose of time comparison are strictly prohibited.

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
SUM(current_month_sales) OVER( PARTITION BY YEAR(sale_month)) as ytd_sales
from currentmonth;


-- updated a sales order to last year to test the partition on year.
UPDATE sp_sales
SET sale_date = '2025-12-30'
WHERE sale_id = 1;

