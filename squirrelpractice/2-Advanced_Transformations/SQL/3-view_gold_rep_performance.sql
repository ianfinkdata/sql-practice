with monthlysummary as (
select 
rep_name, 
sale_month, 
sum(sale_amount) as total_revenue, 
count(sale_id) as deals_closed,
avg(sale_amount) as average_revenue 
from silver_sales_pipeline
group by rep_name, sale_month
)
select *, SUM(total_revenue) OVER(partition by rep_name) as rep_cumulative_sales from monthlysummary;

