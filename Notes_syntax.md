# Basics

## Statement vs Execution Order

```
// Statement Order
SELECT
FROM
WHERE
GROUP BY
HAVING
ORDER BY
LIMIT
;

//Execution Order
FROM
WHERE
GROUP BY
HAVING
SELECT (Aliases defined)
ORDER BY
LIMIT
;
```

# 1 - Basics

## Choose the data (select, from)  

SELECT
FROM  

```
SELECT first_name, age
FROM customers

```

## Sort the data (order by) and Filter the data (where, limit)  

WHERE
ORDER BY
LIMIT

``` 
SELECT first_name, age
FROM Customers
WHERE age BETWEEN 20 AND 29
ORDER BY age desc
LIMIT 10;

```

## Join the data to other tables

### Common Joins   
INNER JOIN  
    Only related rows are returned
``` 
//only returns orders where the order has a customer id populated
 SELECT o.order_id, c.customer_name FROM Orders AS o
    JOIN Customers as c on o.customer_id = c.id

```    

LEFT JOIN  
    All rows from the left table and matching rows from the right.
    

```
// all orders will be returned even if there is not a customer id. 
    SELECT o.order_id, c.customer_name 
    FROM Orders AS o
    LEFT JOIN Customers as c on o.customer_id = c.id

```
## Less Common

RIGHT JOIN  
    The reverse of left join; right rows > matching left  
    
FULL JOIN (FULL OUTER)  
    Combines all rows from specified tables, regardless of matched or not
    Useful when seeking mismatched and orphaned data (e.g. Contact with no account, order with no address)
    common use case is to identify data entry and correction  

ANTI-JOINS
    Return rows where there is not a match.

# 2 Advanced Analysis

## WINDOW FUNCTIONS

A calculation across a set of rows related to the current row, without aggregating all rows. 
Keep the row level of detail but still calculate; context around indiv rows compared to rest of its group and rows surrounding it

[7 Window Functions MASTERED in 17 Minutes](https://youtu.be/vlltZIgn284?si=HysVbqW_sBysYJSm)

### Three Pieces
1. Calculation OVER (two optional)
2. Partition By (do I need to group?)
3. Order By (does order matter ?)


### ROW_NUMBER (rank function)
```
SELECT * , 
// Ties don't matter
ROW_NUMBER() OVER(ORDER BY sale_date)
FROM Sales
```

### RANK (rank function)
```
// Ties Matter, numbers are skipped (e.g. 1,1,3,4)
SELECT * , 
RANK() OVER(ORDER BY sale_date)
FROM Sales

```
### DENSE_RANK (rank function)
```
// Ties Matter, numbers are not skipped  (e.g. 1,1,2,3)
SELECT * , 
DENSE_RANK() OVER(ORDER BY sale_date)
FROM Sales
```

### SUM

```
// Running Total (revenue/goals over time)
SELECT * , SUM(sales_amount) OVER(order by sale_date) as running_total
FROM Sales
;
```

### AVERAGE

```
// Running Average (average sale over time)
SELECT * , AVG(sales_amount) OVER(order by sale_date) as running_avg
FROM Sales
;
```
### LEAD
```
WITH daily AS (
SELECT sale_date , 
SUM(sales_amount) AS daily_total 
FROM sales
GROUP BY 1
)
SELECT *, LEAD(daily_total, 1) OVER(ORDER BY sale_date) as next_day_total 
FROM daily
ORDER BY 1
;
```

### LAG

```
WITH daily AS (
SELECT sale_date , 
SUM(sales_amount) AS daily_total 
FROM sales
GROUP BY 1
)
SELECT *, LAG(daily_total, 1) OVER(ORDER BY sale_date) as previous_day_total 
FROM daily
ORDER BY 1
;
```

## CTEs

Common Table Expressions  
[What are CTEs in SQL in 13 Minutes](https://www.youtube.com/watchv=XUxBKO25ZyA)

Temporary result set DEFINE > NAME > REUSE
query optimization, readability, specific logic in one query
90% of queries use them, biggest ROI  

### 3 use cases  
1. readable code 
2. nest aggregate logic
3. combine result sets


####  1 Readable Code 

```
// Readable code
WITH customerorders AS (
SELECT customer_id, COUNT(order_id) AS order_total,  SUM(amount) AS Total_Amount
FROM orders
GROUP BY customer_id
ORDER BY order_total DESC
)
SELECT * FROM customerorders;

```

#### 2 Nest Aggregate Functions
(Useful for descriptive statistics and complex calculations)

```
// nest aggregate functions
WITH customerorders AS (
  select
  customer_id, 
sum(amount) as total_amt
from orders
group by 
	1
)

// SELECT customer_id avg(sum(amount)) Doesn't work; you can't nest aggs like this in sql to find an average sum

SELECT avg(total_amt) as avg_amount_per_cust
from customerorders
;

```

#### 3 Combining Data of different grouping levels

```
// count number of customers in each category

WITH customerorders AS (
  select
  customer_id, 
item,	
count(item) as total_items
from orders
group by 
	1, 2
)


SELECT item, COUNT(customer_id) as num_customers, SUM(total_items) as total_items
from customerorders
GROUP BY item
;
```


## SUBQUERIES

Enable complex filtering and calculations based on the results of another query
Retrieve specific rows or values that would be difficult to achieve using just joins
Flexible and can be used with various SQL Commands
Performance limitations within more complex scenarios suce has heavily nested or correlated subqueries

### Nested 
Executes once before the outer query
Independent of the outer query
Usually more efficient for large datasets

e.g. WHERE col IN (SELECT col from table 2)

### Correlated
Executes for each row of the outer query
Dependent on values from the outer query
can be slower since it runs multiple times

e.g. WHERE col > (SELECT AVG(col) FROM Table2 
        WHERE table2.id = outer.id)

[Advanced SQL Tutorial| Subqueries](https://www.youtube.com/watch?v=m1KcNV-Zhmc)

In the SELECT, FROM and WHERE

### SELECT

// Used in place of window funtions

SELECT EmployeeId, Salary (SELECT AVG(Salary) FROM EmployeeSalary) AS AllEmployeeAvg
FROM EmployeeSalary

#### How do do it with WINDOW Functions
SELECT EmployeedId, Salary, AVG(Salary) OVER() as AllAvgSalary
FROM EmployeeSalary

#### Why group by doesn't work
```
// Doesn't give the All Average that subqueries and windows do

SELECT EmployeeId, Salary, AVG(Salary) AS AllAvgSalary 
FROM EmployeeSalary 
GROUP BY EmployeeId, Salary
ORDER BY 1,2 

```

### FROM

Not really recommended; subqueries are slow; CTEs accomplish the same thing faster and are easier to follow

```
SELECT a.EmployeeId, a.AllAvgSalary

FROM (SELECT EmployeedId, Salary, AVG(Salary) OVER() as AllAvgSalary
FROM EmployeeSalary) a

```

### WHERE

SELECT EmployeeId, JobTitle, Salary
FROM EmployeeSalary
// Join could accomplish this too, and if you wanted to show the age you would need it.
WHERE EmployeeID in (
    SELECT EmployeeId 
    FROM EmployeeDemographics
    WHERE Age > 30
    )      


## DATE

GETDATE(), CURRENT_TIMESTAMP() = current datetime
SYSDATETIME() = current datetime w/ higher precision
SYSUTCDATETIME() = used when utc time is needed.

CURRENT_DATE, TODAY(), NOW()

DAY(date) = Day number of date value
MONTH(date) month number of date value
YEAR(date) year number of date value
DATENAME(datepart, date)
    weekday, month, year
DATEADD(datepart, number, date)
DATEDIFF(datepart,startdate,enddate)

# 3 Data Engineer

## STRINGS

TRIM
REPLACE
VIEWS
(deeper data cleaning and prep)