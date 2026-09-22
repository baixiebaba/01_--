/*******************************************************************************/
/* Oracle - Scripting                                                          */
/* Database TAGETIK                                                            */
/*                                                                             */
/*******************************************************************************/

COL timestamp_heading NEW_VALUE timestamp NOPRINT;
SELECT TO_CHAR(SYSDATE, 'YYYY_MM_DD_HH24_MI_SS') timestamp_heading FROM DUAL;

spool repo_install_oracle_&timestamp;

PROMPT 'Tagetik'
PROMPT ;

SELECT user||'@'||global_name "user@global_name" FROM global_name;
SELECT TO_CHAR(SYSDATE, 'YYYY_MM_DD_HH24:MI:SS') "timestamp" FROM dual;

PROMPT ;

-- Checks. If success, run repo_install_oracle_sub.sql
SET VERIFY OFF;

COLUMN col_errore NEW_VALUE local_errore NOPRINT;
COLUMN col_testo_errore NEW_VALUE local_testo_errore NOPRINT;
COLUMN ora_version NEW_VALUE local_ora_version NOPRINT;

-- Check n.1: oracle version >= 10
SELECT
  SUBSTR(VERSION, 1, INSTR(VERSION,'.')-1) AS ora_version,
  (CASE WHEN SUBSTR(VERSION, 1, INSTR(VERSION,'.')-1) < 10
        THEN '1'
        ELSE 'repo_install_oracle_sub.sql'
   END) AS col_errore,
  (CASE WHEN SUBSTR(VERSION, 1, INSTR(VERSION,'.')-1) < 10
        THEN '1'
        ELSE '0'
   END) AS col_testo_errore
FROM PRODUCT_COMPONENT_VERSION
WHERE PRODUCT LIKE '%Oracle%';

-- Check n.2: CONFIG_NAME_DB existence
SELECT
(CASE WHEN '&local_testo_errore' = '0'
            THEN
                (CASE WHEN count(*) = 0
                            THEN '2'
                            ELSE 'repo_install_oracle_sub.sql'
                END)
            ELSE '&local_errore'
 END) AS col_errore,
(CASE WHEN '&local_testo_errore' = '0'
            THEN
                (CASE WHEN count(*) = 0
                            THEN '2'
                            ELSE '0'
                END)
            ELSE '&local_testo_errore'
 END) AS col_testo_errore
FROM USER_TABLES
WHERE TABLE_NAME = 'CONFIG_NAME_DB';

-- Check n.3: CONFIG_NAME_DB ROW existence
SELECT
(CASE WHEN '&local_testo_errore' = '0'
            THEN
                (CASE WHEN count(*) = 0
                            THEN '3'
                            ELSE 'repo_install_oracle_sub.sql'
                END)
            ELSE '&local_errore'
 END) AS col_errore,
(CASE WHEN '&local_testo_errore' = '0'
            THEN
                (CASE WHEN count(*) = 0
                            THEN '3'
                            ELSE '0'
                END)
            ELSE '&local_testo_errore'
 END) AS col_testo_errore
FROM CONFIG_NAME_DB;

-- Check n.4: CONFIG_NAME_DB
SELECT
    (CASE WHEN '&local_testo_errore' = '0'
                THEN
                    (CASE WHEN TABSPACE_DATA IS NULL OR TABSPACE_INDEX IS NULL OR TABSPACE_TEMP IS NULL
                                THEN '4'
                                ELSE 'repo_install_oracle_sub.sql'
                    END)
                ELSE '&local_errore'
     END) AS col_errore,
    (CASE WHEN '&local_testo_errore' = '0'
                THEN
                    (CASE WHEN TABSPACE_DATA IS NULL OR TABSPACE_INDEX IS NULL OR TABSPACE_TEMP IS NULL
                                THEN '4'
                                ELSE '0'
                    END)
                ELSE '&local_testo_errore'
     END) AS col_testo_errore
FROM CONFIG_NAME_DB;

SET VERIFY ON;
SET ECHO ON
SET TIME ON
SET TIMING ON

-- Run script
@@&local_errore;

SET ECHO OFF
SET TIME OFF
SET TIMING OFF
SET VERIFY OFF;

PROMPT ;

PROMPT ;

PROMPT ;

BEGIN
 IF &local_testo_errore = 1
        THEN raise_application_error (-20000, 'Install stopped - Oracle version is: &local_ora_version. This version is not compatible with Tagetik');
        ELSE
            IF &local_testo_errore = 2
                THEN raise_application_error (-20000, 'Install stopped - CONFIG_NAME_DB not present');
                ELSE
                    IF &local_testo_errore = 3
                        THEN raise_application_error (-20000, 'Install stopped - CONFIG_NAME_DB not valorized');
                        ELSE
                             IF &local_testo_errore = 4
                                 THEN raise_application_error (-20000, 'Install stopped - CONFIG_NAME_DB not valorized');
                             END IF;
                    END IF;
            END IF;
 END IF;
END;
/
--

spool off

