-- Doris 脚本：查询 ods 库中 BSID/BSAD/BSIK/BSAK 表及字段明细（单结果集展开）
SELECT 
    c.TABLE_NAME                                          AS 表名,
    c.ORDINAL_POSITION                                    AS 字段序号,
    c.COLUMN_NAME                                         AS 字段名,
    c.DATA_TYPE                                           AS 字段类型,
    CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR)           AS 字段长度,
    c.COLUMN_COMMENT                                      AS 字段描述,
    CASE 
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSID%' THEN 'BSID(应收未清)'
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSAD%' THEN 'BSAD(应收已清)'
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSIK%' THEN 'BSIK(应付未清)'
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSAK%' THEN 'BSAK(应付已清)'
    END                                                   AS 数据源
FROM information_schema.COLUMNS c
WHERE c.TABLE_SCHEMA = 'ods'
  AND (
      UPPER(c.TABLE_NAME) LIKE '%BSID%'
   OR UPPER(c.TABLE_NAME) LIKE '%BSAD%'
   OR UPPER(c.TABLE_NAME) LIKE '%BSIK%'
   OR UPPER(c.TABLE_NAME) LIKE '%BSAK%'
  )
ORDER BY 
    CASE 
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSID%' THEN 1
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSAD%' THEN 2
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSIK%' THEN 3
        WHEN UPPER(c.TABLE_NAME) LIKE '%BSAK%' THEN 4
    END,
    c.TABLE_NAME, 
    c.ORDINAL_POSITION;
