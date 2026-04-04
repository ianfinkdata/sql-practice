use squirrelpractice;

CREATE TABLE recursion AS
WITH RECURSIVE NumberEngine AS (

SELECT 1 as RowNumber

UNION ALL 

SELECT RowNumber + 1
FROM NumberEngine
WHERE 
RowNumber < 100
)

select * from NumberEngine;