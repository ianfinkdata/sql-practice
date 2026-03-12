use common_db;

CREATE OR REPLACE VIEW dim_trimester AS

with trimester  as ( 
SELECT *,
	CASE 
		WHEN d.Month < 5 THEN 1
        WHEN d.Month > 8 THEN 3
        ELSE 2 
	END AS Trimester
FROM
common_db.dim_date d  

)

SELECT * FROM trimester 
WHERE Year BETWEEN YEAR(DATE_ADD( CURRENT_DATE, INTERVAL -2 YEAR)) AND YEAR(CURRENT_DATE)
ORDER BY DateKey;
