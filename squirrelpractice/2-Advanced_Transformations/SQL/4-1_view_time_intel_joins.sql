/* 
Tier 1: The Relational Approach
Target View Name: vw_time_intel_joins

Business Requirement: Create a view that returns a continuous monthly summary of the entire company's sales.  
For every month, show the current month's total revenue, the previous month's total revenue, and the raw dollar variance between the two.

Technical Constraints:
You must accomplish the prior-month comparison using a Self-Join combined with date manipulation/interval math.
Window functions are strictly prohibited. 
*/

use squirrelpractice;

CREATE OR REPLACE VIEW time_intel_joins AS 
with currentmonth AS (

select 
sale_date - interval(day(sale_date) - 1) day as sale_month,
SUM(sale_amount) as sale_amount 
from sp_sales 
group by sale_month

)

select 
c.sale_month, 
IFNULL(c.sale_amount,0) as current_month_sales,
IFNULL(p.sale_amount,0) as previous_month_sales,
IFNULL(c.sale_amount,0) - IFNULL(p.sale_amount,0) as variance 
from currentmonth as c
left join currentmonth as p on p.sale_month = DATE_ADD(c.sale_month, INTERVAL -1 MONTH) 
order by c.sale_month;

select * from time_intel_joins;


