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
select distinct month_start_date from common_db.dim_date as cal
),

regions as (
select distinct region
from squirrelpractice.sp_customers
where region is not null
),

-- cross join to ensure every region has a row for every month even when there are no sales
monthlyregions as (
select 
d.month_start_date,
r.region
from dimcalendar as d
cross join regions as r
)

select 
mr.month_start_date,
mr.region,
coalesce(sum(s.sale_amount),0) as current_period_sales,
avg(coalesce(sum(s.sale_amount),0)) over(
	partition by mr.region 
    order by mr.month_start_date
    rows between 3 preceding and current row
    ) as rolling_avg_sales
from monthlyregions as mr
left join squirrelpractice.sp_customers as c
	on mr.region = c.region
left join squirrelpractice.sp_sales as s
	on c.customer_id = s.customer_id
    and s.sale_date >= mr.month_start_date
    and s.sale_date < DATE_ADD(mr.month_start_date, interval 1 month)
where month_start_date BETWEEN date_add(current_date, interval -4 month) and current_date    
group by 
	mr.month_start_date,
    mr.region
order by
	mr.region,
    mr.month_start_date

;

select 
d.month_start_date, 
c.region,
coalesce(sum(s.sale_amount),0) as monthly_sales  
from sp_sales as s
left join sp_customers as c on s.customer_id = c.customer_id
left join common_db.dim_date as d on s.sale_date = d.date
group by 
month_start_date,
region
;

