CREATE OR REPLACE VIEW silver_rolling_three_month_daily_sales as

with dimcalendar as ( 
select * from common_db.dim_date as cal
),

rolling3monthsales AS (

select
d.date as calendar_sale_date,
d.week_start_date, 
d.month_start_date,
-- sale_date - interval(day(sale_date) - 1) day as sale_month,
coalesce(SUM(s.sale_amount),0) as current_period_sales
from dimcalendar as d
left join sp_sales as s on d.date = s.sale_date
where d.month_start_date BETWEEN date_add(current_date, interval -4 month) and current_date
group by calendar_sale_date, week_start_date, month_start_date
)

select * from rolling3monthsales;

select * from silver_rolling_three_month_daily_sales;

