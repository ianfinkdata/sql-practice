
# SQL CODE

## Problem: What was the top revenue month for each rep?

## Data setup

```

CREATE TABLE CLIENT_ACCT (CLIENT_ACCT_NO VARCHAR(10), REP_NAME VARCHAR(10));

INSERT INTO CLIENT_ACCT VALUES('1000', 'Diana');

INSERT INTO CLIENT_ACCT VALUES('1001', 'Diana');

INSERT INTO CLIENT_ACCT VALUES('1002', 'Steve');

INSERT INTO CLIENT_ACCT VALUES('1003', 'John');
 

CREATE TABLE ACCT_REV (ACCT_NO VARCHAR(10), JAN_REVENUE INT, FEB_REVENUE INT, MAR_REVENUE INT);

INSERT INTO ACCT_REV VALUES('1000', 300, 1000, 100);

INSERT INTO ACCT_REV VALUES('1001', 0, 0, 1000);

INSERT INTO ACCT_REV VALUES('1002', 900, 500, NULL);

 

CREATE TABLE SOLUTION (FA_NAME VARCHAR(10), HIGHEST_REV INT);

INSERT INTO SOLUTION VALUES('Diana', 1100);

INSERT INTO SOLUTION VALUES('Steve', 900);

INSERT INTO SOLUTION VALUES('John', 0);

```

## Table Outputs


### client_acct
```
CLIENT_ACCT_NO REP_NAME
1000   Diana
1001   Diana
1002   Steve
1003   John
```

### acct_rev
```
ACCT_NO    JAN_REVENUE    FEB_REVENUE    MAR_REVENUE
1000       300            1000           100
1001       0              0              1000
1002       900            500            NULL
```

## Where I got on my own
```
WITH revmonths as(
SELECT ACCT_NO, 'JAN' AS Month, SUM(JAN_REVENUE) as Revenue FROM ACCT_REV GROUP BY 1,2
UNION ALL 
SELECT ACCT_NO, 'FEB' AS Month, SUM(FEB_REVENUE) as Revenue FROM ACCT_REV GROUP BY 1,2
UNION ALL
SELECT ACCT_NO, 'MAR' AS Month, SUM(MAR_REVENUE) as Revenue FROM ACCT_REV GROUP BY 1,2
 )

/*

FAIL here not sure how to update this to only include the top month.
My instinct was to chain another CTE but I went cross eyed and pulled the AI rip cord. That was the right instinct.
I wouldn't have gotten to the 3rd CTE and window function on my own

*/

SELECT  ca.REP_NAME, rm.Month, IFNULL(SUM(rm.Revenue),0) as revenue  
FROM client_acct ca
LEFT JOIN revmonths rm on ca.CLIENT_ACCT_NO = rm.ACCT_NO
group by 1,2
ORDER BY rep_name, revenue desc;

```

### My table output
```
Diana	MAR	1100
Diana	FEB	1000
Diana	JAN	300
John		0
Steve	JAN	900
Steve	FEB	500
Steve	MAR	0
```

## AI Solution
```
WITH revmonths AS (
    -- Step 1: Unpivot the columns into rows (Optimized without GROUP BY)
    SELECT ACCT_NO, 'JAN' AS Month, JAN_REVENUE AS Revenue FROM ACCT_REV
    UNION ALL
    SELECT ACCT_NO, 'FEB' AS Month, FEB_REVENUE AS Revenue FROM ACCT_REV
    UNION ALL
    SELECT ACCT_NO, 'MAR' AS Month, MAR_REVENUE AS Revenue FROM ACCT_REV
),
RepMonthlyRevenue AS (
    -- Step 2: Aggregate revenue by Rep and Month (Your exact logic)
    SELECT 
        ca.REP_NAME, 
        rm.Month, 
        IFNULL(SUM(rm.Revenue),0) as revenue  
    FROM client_acct ca
    LEFT JOIN revmonths rm on ca.CLIENT_ACCT_NO = rm.ACCT_NO
    GROUP BY 1, 2
),
RankedRevenue AS (
    -- Step 3: Rank the months for each rep
    SELECT 
        REP_NAME,
        revenue,
        ROW_NUMBER() OVER(PARTITION BY REP_NAME ORDER BY revenue DESC) as rn
    FROM RepMonthlyRevenue
)
-- Step 4: Filter for the top rank and sort
SELECT 
    REP_NAME, 
    revenue 
FROM RankedRevenue
WHERE rn = 1
ORDER BY revenue DESC;
```

## Revisit of the practice problem 3/12
```
USE squirrelpractice; 
WITH revmonths as(
SELECT ACCT_NO, 'JAN' AS Month, SUM(JAN_REVENUE) as Revenue FROM ACCT_REV GROUP BY 1,2
UNION ALL 
SELECT ACCT_NO, 'FEB' AS Month, SUM(FEB_REVENUE) as Revenue FROM ACCT_REV GROUP BY 1,2
UNION ALL
SELECT ACCT_NO, 'MAR' AS Month, SUM(MAR_REVENUE) as Revenue FROM ACCT_REV GROUP BY 1,2
 ),

/*

FAIL here not sure how to update this to only include the top month.
My instinct was to chain another CTE but I went cross eyed and pulled the AI rip cord. That was the right instinct.
I wouldn't have gotten to the 3rd CTE and window function on my own

*/
aggregated as (
SELECT  ca.REP_NAME, rm.Month, IFNULL(SUM(rm.Revenue),0) as revenue  
FROM client_acct ca
LEFT JOIN revmonths rm on ca.CLIENT_ACCT_NO = rm.ACCT_NO
group by 1,2
ORDER BY rep_name, revenue desc
)

SELECT REP_NAME, MAX(revenue) as TopRevenue FROM aggregated group by rep_name order by TopRevenue desc; 
```

### Revisited output table

```
REP_NAME    TopRevenue
Diana	    1100
Steve	    900
John	    0
```