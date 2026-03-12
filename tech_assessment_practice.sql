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
