CREATE OR REPLACE VIEW `dictionary` AS
    SELECT 
        `c`.`TABLE_NAME`,
        `c`.`COLUMN_NAME`,
        `c`.`COLUMN_TYPE`,
        `c`.`IS_NULLABLE`,
        `c`.`COLUMN_DEFAULT`,
        `c`.`COLUMN_KEY`,
        `c`.`EXTRA`
    FROM
        `information_schema`.`COLUMNS` `c`
    WHERE
        `c`.`TABLE_SCHEMA` = 'sales_pipeline'
    ORDER BY 
        `c`.`TABLE_NAME`, 
        `c`.`ORDINAL_POSITION`;
