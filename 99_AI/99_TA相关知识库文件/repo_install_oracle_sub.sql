-- *********************************************************************
-- Update Database Script
-- *********************************************************************
-- Change Log: liquibase/framework/install.xml
-- Ran at: 3/7/24, 9:52 AM
-- Against: null@offline:oracle?outputLiquibaseSql=true&changeLogFile=/home/ubuntu/cpm/5.3.27/gse_ef/./build/databasechangelog.csv
-- Liquibase version: 3.4.1
-- *********************************************************************

SET DEFINE OFF;

declare
x number;

begin
   select count(*) INTO x from tab where tname IN ('databasechangelog','DATABASECHANGELOG');
       if x=0 then
           begin
execute immediate ('CREATE TABLE DATABASECHANGELOG (ID VARCHAR2(255) NOT NULL, AUTHOR VARCHAR2(255) NOT NULL, FILENAME VARCHAR2(255) NOT NULL, DATEEXECUTED TIMESTAMP NOT NULL, ORDEREXECUTED NUMBER(10) NOT NULL, EXECTYPE VARCHAR2(10) NOT NULL, MD5SUM VARCHAR2(35), DESCRIPTION VARCHAR2(255), COMMENTS VARCHAR2(255), TAG VARCHAR2(255), LIQUIBASE VARCHAR2(20), CONTEXTS VARCHAR2(255), LABELS VARCHAR2(255))');
            end;
       end if;
end;
/
 --;

-- Changeset liquibase/framework/install/tables/fw_create.xml::ui-38f94e42-5b60-4ed1-80c6-3898564d14a3::liquibase
SET DEFINE ON;

COLUMN col_tbs_data NEW_VALUE tbs_data NOPRINT;

COLUMN col_tbs_index NEW_VALUE tbs_idx NOPRINT;

COLUMN col_tbs_temp NEW_VALUE tbs_temp NOPRINT;

SELECT TABSPACE_DATA col_tbs_data FROM CONFIG_NAME_DB;

SELECT TABSPACE_INDEX col_tbs_index FROM CONFIG_NAME_DB;

SELECT TABSPACE_TEMP col_tbs_temp FROM CONFIG_NAME_DB;

PROMPT;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-1::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-1' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE APPLICATION_OBJECT (COD_OBJECT VARCHAR2(30) NOT NULL, DESC_OBJECT0 VARCHAR2(300), DESC_OBJECT1 VARCHAR2(300), DESC_OBJECT2 VARCHAR2(300), DESC_OBJECT3 VARCHAR2(300), TIPO_OBJECT VARCHAR2(2), ORDINAMENTO NUMBER(5, 0), FLAG_TEMPLATE NUMBER(1, 0) NOT NULL, FLAG_SYSTEM NUMBER(1, 0) NOT NULL, DATE_DEPLOYMENT DATE, USER_DEPLOYMENT VARCHAR2(30), ORACLE_BODY CLOB, MSSQL_BODY CLOB, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-1', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 2, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-2::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-2' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE APP_TABLES (NOME_TABELLA VARCHAR2(32) NOT NULL, INT_DATA_ALLOCAZIONE NUMBER(20, 0), OID_LOCK VARCHAR2(36), COD_UTENTE VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-2', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 4, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-9::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-9' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_ADDITIONAL_LANG (COD_LANG VARCHAR2(30) NOT NULL, ORDINAMENTO NUMBER(5, 0) NOT NULL, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-9', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 6, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-10::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-10' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AGENT_MONITOR (AGENT_ID VARCHAR2(36) NOT NULL, NAME VARCHAR2(255), CURRENT_ACTION CLOB, POLLING_TIME NUMBER(8, 0), LAST_HB DATE, AGENT_VERSION VARCHAR2(30), CONTAINER_VERSION VARCHAR2(30), SECRET VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-10', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 8, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-11::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-11' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AGGIORNAMENTO_DB (VERSIONE_DB VARCHAR2(15) NOT NULL, VERSIONE_AGGIORNAMENTO VARCHAR2(15) NOT NULL, DATA_AGGIORNAMENTO DATE, NUMERO_PATCH NUMBER(3, 0) DEFAULT 0, DATA_PATCH DATE, NOTE VARCHAR2(255), FLAG_AGGIORNAMENTO_IN_CORSO NUMBER(1, 0) DEFAULT 0 NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-11', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 10, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-12::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-12' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_DATI (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, CODICE_DIMENSIONE VARCHAR2(255), TIPO_MODIFICA VARCHAR2(10) NOT NULL, BEAN_PRIMA BLOB, BEAN_DOPO BLOB, CLASS_NAME VARCHAR2(255), CHIAVE VARCHAR2(255) NOT NULL, NOME_TABELLA VARCHAR2(40)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-12', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 12, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-13::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-13' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_LOGS (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, XML BLOB NOT NULL, ELAPSED NUMBER(9, 0) NOT NULL, JDBC_STATS VARCHAR2(100) NOT NULL, ESITO NUMBER(2, 0) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-13', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 14, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-14::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-14' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_LOGS_ECCEZIONE (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, XML BLOB NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-14', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 16, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-15::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-15' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_LOGS_SQL (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, XML BLOB NOT NULL, NOME_TABELLA VARCHAR2(40), OP_MASSIVA NUMBER(1, 0) DEFAULT 0 NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-15', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 18, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-16::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-16' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_OPERAZIONE (OID VARCHAR2(36) NOT NULL, CORRELATION_OID VARCHAR2(36) NOT NULL, PARTE NUMBER(3, 0) NOT NULL, TIPO VARCHAR2(20) NOT NULL, DESCRIZIONE VARCHAR2(100) NOT NULL, UTENTE VARCHAR2(255) NOT NULL, SESSION_ID VARCHAR2(255) NOT NULL, COD_DB VARCHAR2(100) NOT NULL, CLIENT VARCHAR2(10) NOT NULL, SERVER_ID VARCHAR2(255), OP_TIME DATE NOT NULL, REMOTE_ADDRESS VARCHAR2(255), FUNCTION_CODE VARCHAR2(7), ELABORAZIONE VARCHAR2(50), EXECUTION_MODE VARCHAR2(1), CONCURRENCY_LEVEL VARCHAR2(2), EAR_RELEASE VARCHAR2(100)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-16', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 20, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-17::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-17' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_PARAMETRI_DIM (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, CODICE_DIMENSIONE VARCHAR2(255) NOT NULL, VALORE VARCHAR2(255) NOT NULL, READ_OR_WRITE CHAR(1) NOT NULL, NOME_PARAMETRO VARCHAR2(255) NOT NULL, CLASSE VARCHAR2(500), MULTIVALUE CHAR(1) NOT NULL, MANDATORY CHAR(1) NOT NULL, INIZIALE CHAR(1) NOT NULL, TIPO_MODIFICA CHAR(1) NOT NULL, ID_CORRELAZIONE NUMBER(5, 0) DEFAULT -1, ID_PADRE NUMBER(5, 0) DEFAULT -1, CODICE_CAPTION VARCHAR2(128)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-17', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 22, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-18::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-18' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUDIT_PARAMETRI_LIBERI (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, VALORE VARCHAR2(255) NOT NULL, READ_OR_WRITE CHAR(1) NOT NULL, NOME_PARAMETRO VARCHAR2(255) NOT NULL, CODICE_CAPTION VARCHAR2(128) NOT NULL, CLASSE VARCHAR2(500), MULTIVALUE CHAR(1) NOT NULL, MANDATORY CHAR(1) NOT NULL, INIZIALE CHAR(1) NOT NULL, ID_CORRELAZIONE NUMBER(5, 0) DEFAULT -1, ID_PADRE NUMBER(5, 0) DEFAULT -1) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-18', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 24, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-19::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-19' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_AUTHENTICATION (COD_INFORMAZIONE VARCHAR2(30) NOT NULL, NUMERO_CONFIGURAZIONE NUMBER(3, 0) NOT NULL, CAMPO_STRINGA VARCHAR2(4000), CAMPO_NUMERO NUMBER(22, 4), CAMPO_DATA DATE, COD_CAPTION_INFORMAZIONE VARCHAR2(128), ORDINAMENTO VARCHAR2(15), TIPO_CAMPO VARCHAR2(1), CONTROLLO_INFORMAZIONE VARCHAR2(255), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-19', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 26, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-20::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-20' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_BINARY_DATA (OID_BINARY_DATA VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255), TIPO VARCHAR2(30) NOT NULL, CONTENUTO BLOB NOT NULL, FINGERPRINT VARCHAR2(36), USERUPD VARCHAR2(255), DATEUPD DATE, PROVENIENZA VARCHAR2(80)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-20', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 28, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-21::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-21' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_CONFIGURAZIONE (COD_INFORMAZIONE VARCHAR2(30) NOT NULL, CAMPO_STRINGA VARCHAR2(4000), CAMPO_NUMERO NUMBER(22, 4), CAMPO_DATA DATE, COD_CAPTION_INFORMAZIONE VARCHAR2(128), SEZIONE VARCHAR2(5), COD_CAPTION_FOLDER VARCHAR2(128), ORDINAMENTO VARCHAR2(15), TIPO_CAMPO VARCHAR2(1), CONTROLLO_INFORMAZIONE VARCHAR2(255), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, ORDINAMENTO_FOLDER VARCHAR2(3)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-21', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 30, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-22::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-22' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_DB (COD_DB VARCHAR2(50) NOT NULL, DESC_DB VARCHAR2(200), COD_DB_APPOGGIO VARCHAR2(50), DESC_DB_APPOGGIO VARCHAR2(200)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-22', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 32, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-23::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-23' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_ELABORAZIONE (ELABORAZIONE VARCHAR2(50) NOT NULL, TIPO_ELABORAZIONE VARCHAR2(1) DEFAULT ''A'', MAX_CONC_TASK VARCHAR2(3), COD_CAPTION VARCHAR2(128), AUDIT_SQL NUMBER(1, 0) DEFAULT 0, COD_CAPTION_SHORT_DESC VARCHAR2(128), TIMEOUT NUMBER(6, 0) DEFAULT -1 NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-23', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 34, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-24::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-24' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_ENDPOINT (COD_ENDPOINT VARCHAR2(30) NOT NULL, DESC_ENDPOINT VARCHAR2(330), TIPO_ENDPOINT VARCHAR2(1) DEFAULT ''U'', URL VARCHAR2(255), USERNAME VARCHAR2(50), PWD VARCHAR2(50), AGENT_ID VARCHAR2(36), TIPO_SOURCE VARCHAR2(1) DEFAULT ''P'', PATH VARCHAR2(50), DATA_SOURCE VARCHAR2(50), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, COD_PROFILO_AREA VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-24', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 36, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-25::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-25' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_ENDPOINT_SOURCE (AGENT_ID VARCHAR2(36) NOT NULL, SOURCE VARCHAR2(50), TIPO_SOURCE VARCHAR2(1)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-25', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 38, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-26::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-26' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_FILES (OID_FILES VARCHAR2(36) NOT NULL, COD_DB VARCHAR2(50), COD_UTENTE VARCHAR2(255), SERVER VARCHAR2(255), SESSIONE VARCHAR2(255), DATA_UPDATE DATE, NOTE VARCHAR2(1000)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-26', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 40, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-27::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-27' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_FILES_TEMP (OID_FILES_TEMP VARCHAR2(36) NOT NULL, DATI BLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-27', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 42, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-28::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-28' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_FILTRI_PREFERITI (OID_FILTRI_PREFERITI VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255) NOT NULL, COD_FUNZIONE VARCHAR2(7) NOT NULL, TAG VARCHAR2(300), DESC_FILTRI_PREFERITI0 VARCHAR2(200), DESC_FILTRI_PREFERITI1 VARCHAR2(200), DESC_FILTRI_PREFERITI2 VARCHAR2(200), DESC_FILTRI_PREFERITI3 VARCHAR2(200), PARAMETRI CLOB, USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-28', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 44, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-29::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-29' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_DATI (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, CODICE_DIMENSIONE VARCHAR2(255), TIPO_MODIFICA VARCHAR2(10) NOT NULL, BEAN_PRIMA BLOB, BEAN_DOPO BLOB, CLASS_NAME VARCHAR2(255), CHIAVE VARCHAR2(255) NOT NULL, NOME_TABELLA VARCHAR2(40)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-29', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 46, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-30::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-30' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_LOGS (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, XML BLOB NOT NULL, ELAPSED NUMBER(9, 0) NOT NULL, JDBC_STATS VARCHAR2(100) NOT NULL, ESITO NUMBER(2, 0) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-30', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 48, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-31::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-31' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_LOGS_ECCEZIONE (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, XML BLOB NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-31', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 50, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-32::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-32' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_LOGS_SQL (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, XML BLOB NOT NULL, NOME_TABELLA VARCHAR2(40), OP_MASSIVA NUMBER(1, 0) DEFAULT 0 NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-32', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 52, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-33::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-33' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_OPERAZIONE (OID VARCHAR2(36) NOT NULL, CORRELATION_OID VARCHAR2(36) NOT NULL, PARTE NUMBER(3, 0) NOT NULL, TIPO VARCHAR2(20) NOT NULL, DESCRIZIONE VARCHAR2(100) NOT NULL, UTENTE VARCHAR2(255) NOT NULL, SESSION_ID VARCHAR2(255) NOT NULL, COD_DB VARCHAR2(100) NOT NULL, CLIENT VARCHAR2(10) NOT NULL, SERVER_ID VARCHAR2(255), OP_TIME DATE NOT NULL, REMOTE_ADDRESS VARCHAR2(255), FUNCTION_CODE VARCHAR2(7), ELABORAZIONE VARCHAR2(50), EXECUTION_MODE VARCHAR2(1), CONCURRENCY_LEVEL VARCHAR2(2), EAR_RELEASE VARCHAR2(100)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-33', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 54, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-34::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-34' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_PARAMETRI_DIM (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, CODICE_DIMENSIONE VARCHAR2(255) NOT NULL, VALORE VARCHAR2(255) NOT NULL, READ_OR_WRITE CHAR(1) NOT NULL, NOME_PARAMETRO VARCHAR2(255) NOT NULL, CLASSE VARCHAR2(500), MULTIVALUE CHAR(1) NOT NULL, MANDATORY CHAR(1) NOT NULL, INIZIALE CHAR(1) NOT NULL, TIPO_MODIFICA CHAR(1) NOT NULL, ID_CORRELAZIONE NUMBER(5, 0), ID_PADRE NUMBER(5, 0), CODICE_CAPTION VARCHAR2(128)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-34', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 56, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-35::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-35' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_H_AUDIT_PARAMETRI_LIBERI (REP_AUDIT_OPERAZIONE_OID VARCHAR2(36) NOT NULL, VALORE VARCHAR2(255) NOT NULL, READ_OR_WRITE CHAR(1) NOT NULL, NOME_PARAMETRO VARCHAR2(255) NOT NULL, CODICE_CAPTION VARCHAR2(128) NOT NULL, CLASSE VARCHAR2(500), MULTIVALUE CHAR(1) NOT NULL, MANDATORY CHAR(1) NOT NULL, INIZIALE CHAR(1) NOT NULL, ID_CORRELAZIONE NUMBER(5, 0), ID_PADRE NUMBER(5, 0)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-35', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 58, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-51::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-51' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_LICENSE (COD_DB VARCHAR2(50) NOT NULL, LICENSE_KEY VARCHAR2(4000) NOT NULL, LICENSE_VIOLATION NUMBER(22, 4), LICENSE_DATE DATE, XML CLOB, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-51', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 60, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-52::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-52' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_LOCALIZATION (LOCALIZATION_ID VARCHAR2(40) NOT NULL, COD_LANG VARCHAR2(30) NOT NULL, LANG_TYPE NUMBER(1, 0) NOT NULL, VERSION VARCHAR2(100) NOT NULL, CAPTIONS BLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-52', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 62, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-53::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-53' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_LOCKS (OID_LOCKS VARCHAR2(36) NOT NULL, DB_TYPE VARCHAR2(1), COD_DB VARCHAR2(50), LOGIN VARCHAR2(1) DEFAULT ''0'', COD_UTENTE VARCHAR2(255), DATA_UPDATE DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-53', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 64, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-54::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-54' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_LOG (OID_LOG VARCHAR2(36) NOT NULL, OID_TEIC VARCHAR2(36), ORDINAMENTO NUMBER(5, 0), ATTIVITA VARCHAR2(600), INIZIO_FINE VARCHAR2(1), OID_LOG_INIZIO VARCHAR2(36), OID_LOG_INIZIO_PADRE VARCHAR2(36), DATA_ATTIVITA TIMESTAMP, NOTE VARCHAR2(2000), TASK_NAME VARCHAR2(255), ESITO NUMBER(5) DEFAULT 0) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-54', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 66, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-55::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-55' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_MESSAGGIO (OID_MESSAGGIO VARCHAR2(36) NOT NULL, COD_UTENTE_MITTENTE VARCHAR2(255), COD_UTENTE_DESTINATARIO VARCHAR2(255), DATA DATE, OGGETTO VARCHAR2(1000), CORPO CLOB, PRIORITA NUMBER(1, 0) DEFAULT 0) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-55', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 68, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-56::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-56' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_MON_CONFIG_HISTORY (SERVER_NAME VARCHAR2(100), DATEUPD DATE, DATEUPD_DAY NUMBER(19, 0), COD_UTENTE VARCHAR2(255), CONFIGURATION VARCHAR2(2000), NOTE VARCHAR2(2000)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-56', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 70, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-57::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-57' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_MON_CONFIG_SYSTEM (COD_INFO VARCHAR2(100), VALUE_STRINGA VARCHAR2(100), VALUE_NUM NUMBER(19, 0), NOTE VARCHAR2(2000)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-57', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 72, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-58::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-58' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_MON_SERVER_INFO (SERVER_NAME VARCHAR2(100), DATEUPD DATE, DATEUPD_DAY NUMBER(19, 0), CPU_ID NUMBER(5, 0), CPU_MHZ NUMBER(10, 0), CPU_VENDOR VARCHAR2(100), CPU_MODEL VARCHAR2(100), MEM_TOTAL NUMBER(19, 0), SWAP_TOTAL NUMBER(19, 0), JVM_TOTAL NUMBER(19, 0), NOTE VARCHAR2(2000), EAR_RELEASE VARCHAR2(100)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-58', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 74, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-59::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-59' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_MON_USAGE (MON_EVENTS CLOB NOT NULL, MON_MESSAGE VARCHAR2(200)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-59', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 76, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-60::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-60' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_PORTLET (OID_PORTLET VARCHAR2(36) NOT NULL, DESC_PORTLET VARCHAR2(255), COD_UTENTE VARCHAR2(255), OID_SHORTCUT VARCHAR2(36), PORTLET_X NUMBER(5, 0) DEFAULT 0, PORTLET_Y NUMBER(5, 0) DEFAULT 0, PORTLET_WIDTH NUMBER(5, 0) DEFAULT 0, PORTLET_HEIGHT NUMBER(5, 0) DEFAULT 0, COD_DB VARCHAR2(50), OID_PORTLET_TAB VARCHAR2(36), PORTLET_TYPE VARCHAR2(1) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-60', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 78, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-61::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-61' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_PORTLET_SHORTCUTS (OID_PORTLET VARCHAR2(36) NOT NULL, OID_SHORTCUT VARCHAR2(36) NOT NULL, SHORTCUT_POSITION NUMBER(3, 0) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-61', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 80, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-62::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-62' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_PORTLET_TAB (OID_PORTLET_TAB VARCHAR2(36) NOT NULL, DESC_PORTLET_TAB VARCHAR2(255), COD_UTENTE VARCHAR2(255), COD_DB VARCHAR2(50), ORDINAMENTO NUMBER(2, 0) DEFAULT 0) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-62', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 82, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-63::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-63' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_PREFERENZE (OID_PREFERENZE VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255), PREFERENZE CLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-63', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 84, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-64::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-64' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_PWD_REGOLA (COD_PWD_REGOLA VARCHAR2(5) NOT NULL, DESC_PWD_REGOLA VARCHAR2(200), NUM_GIORNI_VALIDITA NUMBER(3, 0) DEFAULT 0, NUM_MIN_LUNGHEZZA NUMBER(2, 0) DEFAULT 6, NUM_MAX_LUNGHEZZA NUMBER(2, 0) DEFAULT 50, NUM_MIN_CIFRE NUMBER(2, 0) DEFAULT 0, NUM_MIN_CAR_SPECIALI NUMBER(2, 0) DEFAULT 0, NUM_MIN_CAR_INIZIALI NUMBER(2, 0) DEFAULT 0, NUM_MIN_DIFF_INIZIALI NUMBER(2, 0) DEFAULT 0, NUM_MAX_FALLIMENTI NUMBER(5, 0) DEFAULT 0, NUM_RIPETIZIONI NUMBER(5, 0) DEFAULT 0, NUM_GIORNI_AVVERT NUMBER(3, 0) DEFAULT 0, NUM_GIORNI_BLOCCO NUMBER(3, 0) DEFAULT 0, COD_PROFILO_AREA VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-64', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 86, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-65::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-65' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_PWD_STORICO (OID_REP_PWD_STORICO VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255), DATA_CAMBIO_PWD DATE, PWD VARCHAR2(50)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-65', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 88, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-66::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-66' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_RUOLO (COD_RUOLO VARCHAR2(30) NOT NULL, DESC_RUOLO VARCHAR2(200), FLAG_BASE NUMBER(1, 0) DEFAULT 0, RUOLO_IMPORT VARCHAR2(30), COD_PROFILO_AREA VARCHAR2(30), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-66', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 90, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-67::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-67' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_RUOLO_FUNZIONE (COD_RUOLO VARCHAR2(30) NOT NULL, COD_FUNZIONE VARCHAR2(7) NOT NULL, AZIONE VARCHAR2(1) DEFAULT ''1'') TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-67', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 92, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-68::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-68' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_RUOLO_FUNZIONE_DEF (OID_RUOLO_FUNZIONE_DEF VARCHAR2(36) NOT NULL, COD_RUOLO VARCHAR2(30), COD_MODULO VARCHAR2(30), COD_FUNZIONE VARCHAR2(7), AZIONE VARCHAR2(1) DEFAULT ''1'', PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-68', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 94, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-69::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-69' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_RUOLO_PADRE (COD_RUOLO VARCHAR2(30) NOT NULL, COD_RUOLO_PADRE VARCHAR2(30) NOT NULL, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-69', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 96, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-70::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-70' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SCHEDULAZIONE (OID_SCHEDULAZIONE VARCHAR2(36) NOT NULL, DATA_BEGIN DATE, LAST_RUN DATE, REPEAT_NUMBER NUMBER(18, 0), FLAG_RUNNING NUMBER(1, 0) DEFAULT 0, COD_UTENTE VARCHAR2(255), ELABORAZIONE VARCHAR2(50), PARAMETRI CLOB, FLAG_VALID NUMBER(1, 0) DEFAULT 0, MSG_NOT_VALID VARCHAR2(255), NEXT_RUN DATE, OID_TEIC VARCHAR2(36), SERVER VARCHAR2(255), DESC_SCHEDULAZIONE VARCHAR2(255), EMAIL_NOTE CLOB, RECIPIENTS CLOB, CRONTAB VARCHAR2(400), EXIT_STATUS VARCHAR2(1), ACTION_ON_ERROR VARCHAR2(10), PREVALIDATION_MAX_WAIT NUMBER(5, 0) DEFAULT -1 NOT NULL, DATA_CREATION DATE, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, FAIL_REPEAT_NUMBER NUMBER(3, 0) DEFAULT 0, FAIL_WAIT_BEFORE_REPEAT NUMBER(5, 0) DEFAULT -1, COD_PADRE VARCHAR2(64), FLAG_GROUP_LEADER NUMBER(1, 0) DEFAULT 0, ORDINAMENTO NUMBER(3, 0) DEFAULT -1, COD_GROUP VARCHAR2(64), COUNT_RUNNING NUMBER(18, 0), SERVER_LIST CLOB, DATA_END DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-70', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 98, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-71::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-71' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SERVER_STATUS (SERVER_ID VARCHAR2(255), EAR_RELEASE VARCHAR2(100), HEARTBEAT DATE, STATUS VARCHAR2(10), STATUS_UPDATEDBY VARCHAR2(255), STATUS_UPDATEDWHEN DATE, NOTE VARCHAR2(2000), DUMP_REQUIRED NUMBER(1, 0), DUMP_INFO CLOB, SCHEDULED_ALLOWED NUMBER(5) DEFAULT 1) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-71', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 100, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-72::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-72' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SERVICE_KEYS (SERVICE_TYPE VARCHAR2(15) NOT NULL, PRIVATE_KEY VARCHAR2(4000), PUBLIC_KEY VARCHAR2(4000), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, COD_PROFILO_AREA VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-72', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 102, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-73::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-73' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SERVICE_NODE (COD_NODE VARCHAR2(30) NOT NULL, SERVICE_URL VARCHAR2(256) NOT NULL, SERVICE_AVAILABLE NUMBER(1, 0), CLIENT_ID VARCHAR2(30), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, COD_PROFILO_AREA VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-73', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 104, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-74::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-74' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SERVICE_NODE_RESOURCE (COD_NODE VARCHAR2(30) NOT NULL, COD_RESOURCE VARCHAR2(30) NOT NULL, MAX_INSTANCES NUMBER(6, 0) NOT NULL, PING_SECONDS NUMBER(5, 0) NOT NULL, PROPS CLOB, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, COD_PROFILO_AREA VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-74', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 106, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-75::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-75' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SHORTCUT (OID_SHORTCUT VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255), COD_DATABASE VARCHAR2(50), COD_FUNZIONE VARCHAR2(100), VERSIONE VARCHAR2(30), PARAMETRI CLOB, CONTESTO VARCHAR2(20), TIPO_SHORTCUT VARCHAR2(1), DESC_SHORTCUT VARCHAR2(1000), VISIBILITY VARCHAR2(1), COD_MODULO VARCHAR2(30)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-75', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 108, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-76::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-76' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_SYS_COMPONENTS (OID VARCHAR2(50) NOT NULL, COD_DB VARCHAR2(50) NOT NULL, CATEGORY VARCHAR2(30) NOT NULL, SUB_CATEGORY VARCHAR2(30), DEPLOY_DATE DATE NOT NULL, TGK_DATE_UPD_WHEN_DEPLOYED DATE NOT NULL, TGK_VERSION_WHEN_DEPLOYED VARCHAR2(100) NOT NULL, DEPLOYED_BY_USER VARCHAR2(30) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-76', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 110, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-77::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-77' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_TEIC (OID_TEIC VARCHAR2(36) NOT NULL, COD_DB VARCHAR2(50), COD_UTENTE VARCHAR2(255), UTENTE_CLIENT VARCHAR2(255), CLIENT VARCHAR2(50), SERVER VARCHAR2(255), SESSIONE VARCHAR2(255), ELABORAZIONE VARCHAR2(50), FLAG_NOTIFICATO NUMBER(1, 0), FLAG_INTERROMPI NUMBER(1, 0), STATO VARCHAR2(1), PARAMETRI CLOB, QUERYSTOP_DATE TIMESTAMP, CREATION_DATE DATE, VERSION_ID VARCHAR2(36) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-77', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 112, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-78::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-78' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_TEIC_FILTRO (OID_TEIC VARCHAR2(36), READ_OR_WRITE CHAR(1), ID_CORRELAZIONE NUMBER(3, 0) DEFAULT -1, ID_PADRE NUMBER(3, 0) DEFAULT -1, CODICE_DIMENSIONE VARCHAR2(255), VALORE VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-78', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 114, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-79::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-79' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_TEIC_SERVICE (OID_TEIC VARCHAR2(36) NOT NULL, COD_NODE VARCHAR2(30) NOT NULL, COD_RESOURCE VARCHAR2(30) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-79', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 116, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-80::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-80' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_TOKEN_SESSIONE (OID_TOKEN_SESSIONE VARCHAR2(36) NOT NULL, SESSIONE VARCHAR2(255), SERVER VARCHAR2(255), DATA_SCADENZA DATE, LINGUA_CAPTION NUMBER(1, 0), LINGUA_DESCRIZIONE NUMBER(1, 0), COD_UTENTE VARCHAR2(255), COD_DB VARCHAR2(50)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-80', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 118, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-81::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-81' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE (COD_UTENTE VARCHAR2(255) NOT NULL, DESC_UTENTE VARCHAR2(1000), EMAIL VARCHAR2(120), EMAIL_USER VARCHAR2(200), EMAIL_PWD VARCHAR2(50), TELEFONO VARCHAR2(100), FLAG_BLOCCATO NUMBER(1, 0) DEFAULT 1, PWD VARCHAR2(50), DATA_CAMBIO_PWD DATE, COD_PWD_REGOLA VARCHAR2(5), NUM_FALLIMENTI NUMBER(2, 0) DEFAULT 0, LINGUA_DESCRIZIONE NUMBER(1, 0), COD_NAZIONALITA VARCHAR2(5), FLAG_PWD_FROM_ADMIN NUMBER(1, 0) DEFAULT 0, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, TIPO_UTENTE VARCHAR2(1) DEFAULT ''L'', COD_UTENTE_DOMINIO VARCHAR2(255), FLAG_EREDITA_RUOLO_DB NUMBER(1, 0) DEFAULT 0, FLAG_UTENTE_RIFERIMENTO NUMBER(1, 0) DEFAULT 0, FLAG_PROFILO_AREA NUMBER(1, 0) DEFAULT 0, COD_PROFILO_AREA VARCHAR2(255), NOTE VARCHAR2(1500), LINGUA_CAPTION VARCHAR2(2) NOT NULL, FLAG_VISUALIZZAZIONE_SIMBOLICA NUMBER(1, 0) DEFAULT 0, LINGUA_CAPTION_DEFAULT VARCHAR2(2) NOT NULL, ISSUE_TRACKER_USER VARCHAR2(30), ISSUE_TRACKER_PWD VARCHAR2(50), FLAG_ELIMINATO VARCHAR2(1) DEFAULT ''0'' NOT NULL, COD_UTENTE_OLD VARCHAR2(255), DATA_INIZIO DATE, DATA_FINE DATE, FLAG_EREDITA_PROFILO_AREA NUMBER(1, 0) DEFAULT 0 NOT NULL, DATA_ULTIMO_ACCESSO DATE, FLAG_HIDE_TOOLTIPS NUMBER(1, 0) DEFAULT 0 NOT NULL, COUNTRY_CAPTION VARCHAR2(2), COUNTRY_CAPTION_DEFAULT VARCHAR2(2), MAX_USERS_AREA NUMBER(22, 0), GIVENNAME VARCHAR2(255), SURNAME VARCHAR2(255), COMPANY VARCHAR2(255), DEPARTMENT VARCHAR2(255), LINGUA_REPORT NUMBER(5)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-81', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 120, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-82::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-82' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_CONNESSO (OID_UTENTE_CONNESSO VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255), COD_UTENTE_CLIENT VARCHAR2(255), CLIENT VARCHAR2(50), SERVER VARCHAR2(255), SESSIONE VARCHAR2(255), DATA_LOGIN DATE, DATEUPD DATE, PAGINA VARCHAR2(255)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-82', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 122, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-83::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-83' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_DA_ALLINEARE (COD_UTENTE VARCHAR2(255) NOT NULL, COD_DB VARCHAR2(50) NOT NULL, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-83', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 124, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-84::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-84' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_DB (COD_UTENTE VARCHAR2(255) NOT NULL, COD_DB VARCHAR2(50) NOT NULL, FLAG_BLOCCATO NUMBER(1, 0) DEFAULT 1, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, FLAG_ALLINEA_NO_LIM VARCHAR2(1) DEFAULT ''0'' NOT NULL, DATA_INIZIO DATE, DATA_FINE DATE, FLAG_MULTI_RUOLO NUMBER(1, 0) DEFAULT 0 NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-84', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 126, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-85::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-85' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_DB_FUNZIONE (COD_UTENTE VARCHAR2(255) NOT NULL, COD_DB VARCHAR2(50) NOT NULL, COD_FUNZIONE VARCHAR2(7) NOT NULL, AZIONE VARCHAR2(1), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-85', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 128, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-86::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-86' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_DB_RUOLO (COD_UTENTE VARCHAR2(255) NOT NULL, COD_DB VARCHAR2(50) NOT NULL, COD_RUOLO VARCHAR2(30) NOT NULL, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-86', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 130, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-87::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-87' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_INFO (COD_UTENTE VARCHAR2(255) NOT NULL, DATA_TYPE VARCHAR2(3) NOT NULL, DATA_NAME VARCHAR2(500) NOT NULL, DATA_BLOB BLOB, DATA_CLOB CLOB, DATA_NUMBER NUMBER(22, 4), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-87', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 132, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-88::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-88' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_NOTE (OID_UTENTE_NOTE VARCHAR2(36) NOT NULL, COD_UTENTE VARCHAR2(255), COD_FUNZIONE VARCHAR2(100), ID_NODO VARCHAR2(36), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-88', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 134, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-89::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-89' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_UTENTE_RIFERIMENTO (COD_UTENTE VARCHAR2(255) NOT NULL, COD_UTENTE_RIFERIMENTO VARCHAR2(255) NOT NULL, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-89', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 136, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-92::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-92' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_DB (COD_DB, DESC_DB, COD_DB_APPOGGIO, DESC_DB_APPOGGIO) VALUES ('[!]', 'Repository', NULL, NULL);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-92', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 138, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-94::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-94' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_MON_CONFIG_SYSTEM (COD_INFO, VALUE_STRINGA, VALUE_NUM, NOTE) VALUES ('ENTRY_ON', NULL, 1, NULL);

INSERT INTO REP_MON_CONFIG_SYSTEM (COD_INFO, VALUE_STRINGA, VALUE_NUM, NOTE) VALUES ('HTTP_ON', NULL, 1, NULL);

INSERT INTO REP_MON_CONFIG_SYSTEM (COD_INFO, VALUE_STRINGA, VALUE_NUM, NOTE) VALUES ('JDBC_ON', NULL, 1, NULL);

INSERT INTO REP_MON_CONFIG_SYSTEM (COD_INFO, VALUE_STRINGA, VALUE_NUM, NOTE) VALUES ('JMS_ON', NULL, 1, NULL);

INSERT INTO REP_MON_CONFIG_SYSTEM (COD_INFO, VALUE_STRINGA, VALUE_NUM, NOTE) VALUES ('ELAB_ON', NULL, 1, NULL);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-94', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 140, NULL, 'sql, customChange (x5)', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-95::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-95' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_MON_USAGE (MON_EVENTS, MON_MESSAGE) VALUES ('H4sIAAAAAAAAAO3Yyw3lMAhA0ZYA8y3HYNN/CeOZ5Ssgm2ER5aPIOWQRXUXWBbYuXSJCuUgLuKkkDY0SRfoE4KYG2CTCx64HtCCJHgHmE1bLjbo2NCl4YSzakdHseg+pR+2Oo16yEVUCQADcmW/hCb83/C22C3UV662UXhAaCN0LzwEN8ZZ9TccznvGMZzzjGc94xvOtx7aU+t2uTuEVfG4FxsH2gh0mmk6GLky2kXy1r0A5ZNIY1oeXZmjqCgUE4m678JrzoPRdWpHuJrh2v+EBf72tYsFsZjdSdtntgH3Wda9Xqzye8YxnPOMZz3jGM55vPcB7HbmI6UjH87dftbTR3/0Uaa9NHRSx2SrXOWvl0XJX3VRbX8mCqt6dtCz3cy9oP/s95iLnXe/417uK3oS+rMC2EdHB93K2vzHiPbvGM57xjGc84xnPeMbzradlHUJwpb7pakp0T0lXrToC/6ry6AHSfMvoM0qWiRS/Cu30zsc/TC8su8sJKFd2Ix7xTVdcQ1fzTZMSZDsR7daEyr6tTtBOpteokSR0yg4j4mO8Tm41HM94xjOe8YxnPOMZz7ce9a104e+PzMpseAut15uo4Ju9mKFCdBG2iwVl6D3+OLuItsJlOXmuHEDYEXZyaYlbVMUL1fXE7+Lml6m8no7c8u1AFLevaLO+h7cdW6ztCqH22tb4qd8geccznvGMZzzjGc94xvOtB/YtzONXCS0ZeqlE7rCXlkKxbcHmtdhWpYvyWxKQX72qNWfqurEwi9H5kNnVjZtCrN9EeO+L2NNe5NeZkEEXO3rmfZV6hZO0FFHfK9nnnSG3wKvj5Ipkds7xjGc84/lfPb/f67plHvm2Lk3KP6m7lrJwOAAA', NULL);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-95', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 142, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-96::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-96' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_PWD_REGOLA (COD_PWD_REGOLA, DESC_PWD_REGOLA, NUM_GIORNI_VALIDITA, NUM_MIN_LUNGHEZZA, NUM_MAX_LUNGHEZZA, NUM_MIN_CIFRE, NUM_MIN_CAR_SPECIALI, NUM_MIN_CAR_INIZIALI, NUM_MIN_DIFF_INIZIALI, NUM_MAX_FALLIMENTI, NUM_RIPETIZIONI, NUM_GIORNI_AVVERT, NUM_GIORNI_BLOCCO) VALUES ('$PWD', 'Default password rule', 999, 1, 8, 0, 0, 0, 0, 10, 0, 0, 0);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-96', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 144, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-97::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-97' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0000005', '2');

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0000013', '2');

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0001939', '2');

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0002806', '2');

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0002807', '2');

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0003229', '2');

INSERT INTO REP_RUOLO_FUNZIONE (COD_RUOLO, COD_FUNZIONE, AZIONE) VALUES ('$SYSADMIN', '0003230', '2');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-97', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 146, NULL, 'sql, customChange (x7)', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-98::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-98' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_UTENTE (COD_UTENTE, DESC_UTENTE, EMAIL, EMAIL_USER, EMAIL_PWD, TELEFONO, FLAG_BLOCCATO, PWD, DATA_CAMBIO_PWD, COD_PWD_REGOLA, NUM_FALLIMENTI, LINGUA_DESCRIZIONE, COD_NAZIONALITA, FLAG_PWD_FROM_ADMIN, PROVENIENZA, USERUPD, DATEUPD, TIPO_UTENTE, COD_UTENTE_DOMINIO, FLAG_EREDITA_RUOLO_DB, FLAG_UTENTE_RIFERIMENTO, FLAG_PROFILO_AREA, COD_PROFILO_AREA, NOTE, LINGUA_CAPTION, FLAG_VISUALIZZAZIONE_SIMBOLICA, LINGUA_CAPTION_DEFAULT, ISSUE_TRACKER_USER, ISSUE_TRACKER_PWD, FLAG_ELIMINATO, COD_UTENTE_OLD, DATA_INIZIO, DATA_FINE, FLAG_EREDITA_PROFILO_AREA, DATA_ULTIMO_ACCESSO, FLAG_HIDE_TOOLTIPS, COUNTRY_CAPTION, COUNTRY_CAPTION_DEFAULT, MAX_USERS_AREA, GIVENNAME, SURNAME, COMPANY, DEPARTMENT, LINGUA_REPORT) VALUES ('$USER', 'Default user', NULL, NULL, NULL, '+39-0583-96811', 0, NULL, to_date('2015-10-23 08:57:41', 'YYYY-MM-DD HH24:MI:SS'), '$PWD', 0, 0, 'en_US', 0, NULL, NULL, NULL, 'L', NULL, 0, 0, 0, NULL, NULL, 'en', 0, 'en', NULL, NULL, '0', NULL, NULL, NULL, 0, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-98', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 148, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-99::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-99' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_UTENTE_DB (COD_UTENTE, COD_DB, FLAG_BLOCCATO, PROVENIENZA, USERUPD, DATEUPD, FLAG_ALLINEA_NO_LIM, DATA_INIZIO, DATA_FINE, FLAG_MULTI_RUOLO) VALUES ('$USER', '[!]', 0, NULL, NULL, NULL, '0', NULL, NULL, 0);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-99', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 150, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-100::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-100' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_UTENTE_DB_RUOLO (COD_UTENTE, COD_DB, COD_RUOLO, PROVENIENZA, USERUPD, DATEUPD) VALUES ('$USER', '[!]', '$SYSADMIN', NULL, NULL, NULL);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-100', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 152, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-101::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-101' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE APPLICATION_OBJECT ADD CONSTRAINT PK_APPLICATION_OBJECT PRIMARY KEY (COD_OBJECT) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-101', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 154, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-102::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-102' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE APP_TABLES ADD CONSTRAINT PK_APP_TABLES PRIMARY KEY (NOME_TABELLA) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-102', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 156, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-109::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-109' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_ADDITIONAL_LANG ADD CONSTRAINT PK_REP_ADDITIONAL_LANG PRIMARY KEY (ORDINAMENTO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-109', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 158, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-110::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-110' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_AGENT_MONITOR ADD CONSTRAINT PK_REP_AGENT_MONITOR PRIMARY KEY (AGENT_ID) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-110', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 160, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-111::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-111' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_AUTHENTICATION ADD CONSTRAINT PK_REP_AUTHENTICATION PRIMARY KEY (COD_INFORMAZIONE, NUMERO_CONFIGURAZIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-111', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 162, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-112::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-112' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_BINARY_DATA ADD CONSTRAINT PK_REP_BINARY_DATA PRIMARY KEY (OID_BINARY_DATA) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-112', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 164, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-113::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-113' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_CONFIGURAZIONE ADD CONSTRAINT PK_REP_CONFIGURAZIONE PRIMARY KEY (COD_INFORMAZIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-113', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 166, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-114::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-114' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_DB ADD CONSTRAINT PK_REP_DB PRIMARY KEY (COD_DB) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-114', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 168, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-115::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-115' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_ELABORAZIONE ADD CONSTRAINT PK_REP_ELABORAZIONE PRIMARY KEY (ELABORAZIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-115', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 170, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-116::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-116' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_FILES ADD CONSTRAINT PK_REP_FILES PRIMARY KEY (OID_FILES) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-116', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 172, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-117::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-117' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_FILES_TEMP ADD CONSTRAINT PK_REP_FILES_TEMP PRIMARY KEY (OID_FILES_TEMP) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-117', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 174, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-118::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-118' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_FILTRI_PREFERITI ADD CONSTRAINT PK_REP_FILTRI_PREFERITI PRIMARY KEY (OID_FILTRI_PREFERITI) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-118', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 176, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-120::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-120' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_LICENSE ADD CONSTRAINT PK_REP_LICENSE PRIMARY KEY (COD_DB) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-120', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 178, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-121::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-121' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_LOCALIZATION ADD CONSTRAINT PK_REP_LOCALIZATION PRIMARY KEY (LOCALIZATION_ID, COD_LANG) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-121', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 180, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-122::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-122' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_LOCKS ADD CONSTRAINT PK_REP_LOCKS PRIMARY KEY (OID_LOCKS) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-122', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 182, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-123::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-123' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_MESSAGGIO ADD CONSTRAINT PK_REP_MESSAGGIO PRIMARY KEY (OID_MESSAGGIO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-123', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 184, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-124::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-124' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_PORTLET ADD CONSTRAINT PK_REP_PORTLET PRIMARY KEY (OID_PORTLET) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-124', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 186, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-125::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-125' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_PORTLET_TAB ADD CONSTRAINT PK_REP_PORTLET_TAB PRIMARY KEY (OID_PORTLET_TAB) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-125', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 188, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-126::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-126' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_PREFERENZE ADD CONSTRAINT PK_REP_PREFERENZE PRIMARY KEY (OID_PREFERENZE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-126', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 190, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-127::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-127' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_PWD_REGOLA ADD CONSTRAINT PK_REP_PWD_REGOLA PRIMARY KEY (COD_PWD_REGOLA) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-127', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 192, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-128::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-128' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_PWD_STORICO ADD CONSTRAINT PK_REP_PWD_STORICO PRIMARY KEY (OID_REP_PWD_STORICO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-128', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 194, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-129::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-129' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_RUOLO ADD CONSTRAINT PK_REP_RUOLO PRIMARY KEY (COD_RUOLO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-129', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 196, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-130::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-130' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_RUOLO_FUNZIONE ADD CONSTRAINT PK_REP_RUOLO_FUNZIONE PRIMARY KEY (COD_RUOLO, COD_FUNZIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-130', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 198, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-131::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-131' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_RUOLO_FUNZIONE_DEF ADD CONSTRAINT PK_REP_RUOLO_FUNZIONE_DEF PRIMARY KEY (OID_RUOLO_FUNZIONE_DEF) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-131', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 200, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-132::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-132' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_RUOLO_PADRE ADD CONSTRAINT PK_REP_RUOLO_PADRE PRIMARY KEY (COD_RUOLO, COD_RUOLO_PADRE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-132', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 202, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-133::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-133' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_SCHEDULAZIONE ADD CONSTRAINT PK_REP_SCHEDULAZIONE PRIMARY KEY (OID_SCHEDULAZIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-133', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 204, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-134::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-134' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_SERVICE_KEYS ADD CONSTRAINT PK_REP_SERVICE_KEYS PRIMARY KEY (SERVICE_TYPE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-134', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 206, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-135::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-135' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_SERVICE_NODE ADD CONSTRAINT PK_REP_SERVICE_NODE PRIMARY KEY (COD_NODE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-135', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 208, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-136::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-136' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_SERVICE_NODE_RESOURCE ADD CONSTRAINT PK_REP_SERVICE_NODE_RESOURCE PRIMARY KEY (COD_NODE, COD_RESOURCE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-136', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 210, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-137::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-137' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_SHORTCUT ADD CONSTRAINT PK_REP_SHORTCUT PRIMARY KEY (OID_SHORTCUT) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-137', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 212, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-138::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-138' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_TEIC ADD CONSTRAINT PK_REP_TEIC PRIMARY KEY (OID_TEIC) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-138', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 214, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-139::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-139' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_TOKEN_SESSIONE ADD CONSTRAINT PK_REP_TOKEN_SESSIONE PRIMARY KEY (OID_TOKEN_SESSIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-139', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 216, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-140::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-140' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE ADD CONSTRAINT PK_REP_UTENTE PRIMARY KEY (COD_UTENTE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-140', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 218, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-141::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-141' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_CONNESSO ADD CONSTRAINT PK_REP_UTENTE_CONNESSO PRIMARY KEY (OID_UTENTE_CONNESSO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-141', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 220, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-142::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-142' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_DA_ALLINEARE ADD CONSTRAINT PK_REP_UTENTE_DA_ALLINEARE PRIMARY KEY (COD_UTENTE, COD_DB) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-142', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 222, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-143::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-143' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_DB ADD CONSTRAINT PK_REP_UTENTE_DB PRIMARY KEY (COD_UTENTE, COD_DB) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-143', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 224, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-144::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-144' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_DB_FUNZIONE ADD CONSTRAINT PK_REP_UTENTE_DB_FUNZIONE PRIMARY KEY (COD_UTENTE, COD_DB, COD_FUNZIONE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-144', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 226, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-145::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-145' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_DB_RUOLO ADD CONSTRAINT PK_REP_UTENTE_DB_RUOLO PRIMARY KEY (COD_UTENTE, COD_DB, COD_RUOLO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-145', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 228, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-146::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-146' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_INFO ADD CONSTRAINT PK_REP_UTENTE_INFO PRIMARY KEY (COD_UTENTE, DATA_TYPE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-146', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 230, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-147::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-147' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_NOTE ADD CONSTRAINT PK_REP_UTENTE_NOTE PRIMARY KEY (OID_UTENTE_NOTE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-147', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 232, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-148::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-148' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_UTENTE_RIFERIMENTO ADD CONSTRAINT PK_REP_UTENTE_RIFERIMENTO PRIMARY KEY (COD_UTENTE, COD_UTENTE_RIFERIMENTO) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-148', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 234, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-149::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-149' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_EP_H_AUDIT_PARAMETRI_DIM_01 ON REP_H_AUDIT_PARAMETRI_DIM(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-149', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 236, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-152::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-152' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_H_AUDIT_PARAMETRI_LIBERI_01 ON REP_H_AUDIT_PARAMETRI_LIBERI(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-152', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 238, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-153::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-153' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_P_AUDIT_PARAMETRI_LIBERI_01 ON REP_AUDIT_PARAMETRI_LIBERI(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-153', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 240, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-154::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-154' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_P_H_AUDIT_LOGS_ECCEZIONE_01 ON REP_H_AUDIT_LOGS_ECCEZIONE(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-154', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 242, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-155::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-155' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AGGIORNAMENTO_DB_01 ON REP_AGGIORNAMENTO_DB(VERSIONE_DB, VERSIONE_AGGIORNAMENTO) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-155', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 244, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-156::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-156' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AUDIT_DATI_01 ON REP_AUDIT_DATI(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-156', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 246, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-157::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-157' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AUDIT_LOGS_01 ON REP_AUDIT_LOGS(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-157', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 248, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-158::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-158' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AUDIT_LOGS_ECCEZIONE_01 ON REP_AUDIT_LOGS_ECCEZIONE(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-158', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 250, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-159::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-159' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AUDIT_LOGS_SQL_01 ON REP_AUDIT_LOGS_SQL(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-159', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 252, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-160::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-160' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AUDIT_OPERAZIONE_01 ON REP_AUDIT_OPERAZIONE(CORRELATION_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-160', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 254, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-161::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-161' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_AUDIT_PARAMETRI_DIM_01 ON REP_AUDIT_PARAMETRI_DIM(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-161', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 256, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-162::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-162' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_FILTRI_PREFERITI_01 ON REP_FILTRI_PREFERITI(COD_UTENTE, COD_FUNZIONE) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-162', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 258, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-163::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-163' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_DATI_01 ON REP_H_AUDIT_DATI(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-163', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 260, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-164::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-164' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_DATI_02 ON REP_H_AUDIT_DATI(CODICE_DIMENSIONE) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-164', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 262, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-165::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-165' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_DATI_03 ON REP_H_AUDIT_DATI(CLASS_NAME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-165', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 264, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-166::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-166' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_DATI_04 ON REP_H_AUDIT_DATI(CHIAVE) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-166', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 266, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-167::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-167' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_LOGS_01 ON REP_H_AUDIT_LOGS(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-167', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 268, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-168::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-168' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_LOGS_SQL_01 ON REP_H_AUDIT_LOGS_SQL(REP_AUDIT_OPERAZIONE_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-168', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 270, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-169::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-169' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_OPERAZIONE_01 ON REP_H_AUDIT_OPERAZIONE(CORRELATION_OID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-169', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 272, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-170::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-170' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_OPERAZIONE_02 ON REP_H_AUDIT_OPERAZIONE(TIPO) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-170', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 274, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-171::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-171' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_OPERAZIONE_03 ON REP_H_AUDIT_OPERAZIONE(UTENTE) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-171', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 276, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-172::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-172' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_H_AUDIT_OPERAZIONE_04 ON REP_H_AUDIT_OPERAZIONE(OP_TIME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-172', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 278, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-182::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-182' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_LOG_01 ON REP_LOG(OID_TEIC) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-182', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 280, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-183::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-183' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_MON_CONFIG_HISTORY_01 ON REP_MON_CONFIG_HISTORY(DATEUPD_DAY) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-183', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 282, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-184::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-184' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_MON_SERVER_INFO_01 ON REP_MON_SERVER_INFO(DATEUPD_DAY) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-184', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 284, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-185::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-185' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_PWD_STORICO_01 ON REP_PWD_STORICO(COD_UTENTE) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-185', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 286, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/fw_create.xml::1445583933336-186::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445583933336-186' and author = 'liquibase (generated)' and filename = 'liquibase/framework/install/tables/fw_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE INDEX IX_REP_RUOLO_FUNZIONE_DEF_01 ON REP_RUOLO_FUNZIONE_DEF(COD_RUOLO) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445583933336-186', 'liquibase (generated)', 'liquibase/framework/install/tables/fw_create.xml', SYSTIMESTAMP, 288, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/201905071713_tgk_141322.xml::2019050713_001_tgk_141322::froggies
declare
x number;

begin
select count(*) into x from databasechangelog where id = '2019050713_001_tgk_141322' and author = 'froggies' and filename = 'liquibase/framework/install/tables/201905071713_tgk_141322.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_CONFIGURAZIONE (COD_INFORMAZIONE, CAMPO_STRINGA, CAMPO_NUMERO, CAMPO_DATA, COD_CAPTION_INFORMAZIONE, SEZIONE, COD_CAPTION_FOLDER, ORDINAMENTO, TIPO_CAMPO, CONTROLLO_INFORMAZIONE, PROVENIENZA, USERUPD, DATEUPD, ORDINAMENTO_FOLDER) VALUES ('ENCRYPT_DOTNET_TRAFFIC', NULL, 0, NULL, 'R003311', 'REP', 'R003308', NULL, 'F', NULL, NULL, NULL, NULL, '052');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('2019050713_001_tgk_141322', 'froggies', 'liquibase/framework/install/tables/201905071713_tgk_141322.xml', SYSTIMESTAMP, 290, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100001::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100001' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_DATASTORE (ID VARCHAR2(255) NOT NULL, LENGTH NUMBER, LAST_MODIFIED NUMBER, DATA BLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100001', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 292, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100002::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100002' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_FS_FSENTRY (FSENTRY_PATH VARCHAR2(2048) NOT NULL, FSENTRY_NAME VARCHAR2(255) NOT NULL, FSENTRY_DATA BLOB, FSENTRY_LASTMOD NUMBER(38) NOT NULL, FSENTRY_LENGTH NUMBER(38)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100002', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 294, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100003::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100003' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_J_GLOBAL_REVISION (REVISION_ID DECIMAL(20) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100003', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 296, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100004::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100004' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_J_JOURNAL (REVISION_ID DECIMAL(20) NOT NULL, JOURNAL_ID VARCHAR2(255), PRODUCER_ID VARCHAR2(255), REVISION_DATA BLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100004', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 298, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100005::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100005' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_J_LOCAL_REVISIONS (JOURNAL_ID VARCHAR2(255) NOT NULL, REVISION_ID DECIMAL(20) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100005', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 300, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100006::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100006' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_VER_FS_FSENTRY (FSENTRY_PATH VARCHAR2(2048) NOT NULL, FSENTRY_NAME VARCHAR2(255) NOT NULL, FSENTRY_DATA BLOB, FSENTRY_LASTMOD NUMBER(38) NOT NULL, FSENTRY_LENGTH NUMBER(38)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100006', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 302, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100007::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100007' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_VER_PM_BINVAL (BINVAL_ID VARCHAR2(64) NOT NULL, BINVAL_DATA BLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100007', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 304, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100008::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100008' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_VER_PM_BUNDLE (NODE_ID RAW(16) NOT NULL, BUNDLE_DATA BLOB NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100008', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 306, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100009::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100009' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_VER_PM_NAMES (ID NUMBER(10) NOT NULL, NAME VARCHAR2(255) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100009', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 308, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100010::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100010' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_VER_PM_REFS (NODE_ID RAW(16) NOT NULL, REFS_DATA BLOB NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100010', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 310, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100011::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100011' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_WS_FS_TGK_FSENTRY (FSENTRY_PATH VARCHAR2(2048) NOT NULL, FSENTRY_NAME VARCHAR2(255) NOT NULL, FSENTRY_DATA BLOB, FSENTRY_LASTMOD NUMBER(38) NOT NULL, FSENTRY_LENGTH NUMBER(38)) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100011', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 312, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100012::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100012' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_WS_PM_TGK_BINVAL (BINVAL_ID VARCHAR2(64) NOT NULL, BINVAL_DATA BLOB) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100012', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 314, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100013::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100013' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_WS_PM_TGK_BUNDLE (NODE_ID RAW(16) NOT NULL, BUNDLE_DATA BLOB NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100013', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 316, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100014::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100014' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_WS_PM_TGK_NAMES (ID NUMBER(10) NOT NULL, NAME VARCHAR2(255) NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100014', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 318, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100015::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100015' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE REP_JCK_WS_PM_TGK_REFS (NODE_ID RAW(16) NOT NULL, REFS_DATA BLOB NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100015', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 320, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100016::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100016' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_JCK_DATASTORE ADD CONSTRAINT PK_REP_JCK_DATASTORE PRIMARY KEY (ID) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100016', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 322, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100017::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100017' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_JCK_VER_PM_NAMES ADD CONSTRAINT PK_REP_JCK_VER_PM_NAMES PRIMARY KEY (ID) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100017', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 324, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100018::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100018' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE REP_JCK_WS_PM_TGK_NAMES ADD CONSTRAINT PK_REP_JCK_WS_PM_TGK_NAMES PRIMARY KEY (ID) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100018', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 326, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100019::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100019' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_FS_FSENTRY_01 ON REP_JCK_FS_FSENTRY(FSENTRY_PATH, FSENTRY_NAME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100019', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 328, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100020::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100020' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_EP_JCK_J_GLOBAL_REVISION_01 ON REP_JCK_J_GLOBAL_REVISION(REVISION_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100020', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 330, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100021::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100021' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_J_JOURNAL_01 ON REP_JCK_J_JOURNAL(REVISION_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100021', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 332, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100022::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100022' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_VER_FS_FSENTRY_01 ON REP_JCK_VER_FS_FSENTRY(FSENTRY_PATH, FSENTRY_NAME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100022', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 334, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100023::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100023' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_VER_PM_BINVAL_01 ON REP_JCK_VER_PM_BINVAL(BINVAL_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100023', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 336, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100024::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100024' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_VER_PM_BUNDLE_01 ON REP_JCK_VER_PM_BUNDLE(NODE_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100024', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 338, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100025::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100025' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_VER_PM_NAMES_01 ON REP_JCK_VER_PM_NAMES(NAME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100025', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 340, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100026::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100026' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_VER_PM_REFS_01 ON REP_JCK_VER_PM_REFS(NODE_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100026', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 342, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100027::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100027' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_EP_JCK_WS_FS_TGK_FSENTRY_01 ON REP_JCK_WS_FS_TGK_FSENTRY(FSENTRY_PATH, FSENTRY_NAME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100027', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 344, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100028::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100028' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_WS_PM_TGK_BINVAL_01 ON REP_JCK_WS_PM_TGK_BINVAL(BINVAL_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100028', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 346, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100029::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100029' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_WS_PM_TGK_BUNDLE_01 ON REP_JCK_WS_PM_TGK_BUNDLE(NODE_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100029', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 348, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100030::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100030' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_WS_PM_TGK_NAMES_01 ON REP_JCK_WS_PM_TGK_NAMES(NAME) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100030', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 350, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100031::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100031' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE UNIQUE INDEX IX_REP_JCK_WS_PM_TGK_REFS_01 ON REP_JCK_WS_PM_TGK_REFS(NODE_ID) TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100031', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 352, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install/tables/jack_rabbit_oracle.xml::20151026100032::liquibase
declare
x number;

begin
select count(*) into x from databasechangelog where id = '20151026100032' and author = 'liquibase' and filename = 'liquibase/framework/install/tables/jack_rabbit_oracle.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO REP_JCK_J_GLOBAL_REVISION (REVISION_ID) VALUES (0);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('20151026100032', 'liquibase', 'liquibase/framework/install/tables/jack_rabbit_oracle.xml', SYSTIMESTAMP, 354, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-4::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-4' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE MDM_ROUTINE (COD_MDM_ROUTINE VARCHAR2(30) NOT NULL, DESC_MDM_ROUTINE0 VARCHAR2(330), DESC_MDM_ROUTINE1 VARCHAR2(330), DESC_MDM_ROUTINE2 VARCHAR2(330), DESC_MDM_ROUTINE3 VARCHAR2(330), TIPO_ROUTINE VARCHAR2(3) DEFAULT ''DTD'', COD_DB_SOURCE VARCHAR2(50), COD_DB_TAGET VARCHAR2(50), FLAG_DISABLE_AUDIT NUMBER(5) DEFAULT 0, FLAG_ALL_FKCODE NUMBER(5) DEFAULT 0, ORDINAMENTO NUMBER(5, 0) DEFAULT 0, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, FLAG_ESEGUI_SOLO_STEP NUMBER(5) DEFAULT 0, FLAG_NO_ESEGUI_STESSO_UTENTE NUMBER(5) DEFAULT 0, FLAG_NO_ESEGUI_DEPLOYMENT NUMBER(5) DEFAULT 0 NOT NULL) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-4', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 356, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-5::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-5' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE MDM_ROUTINE_FIELD (OID_MDM_ROUTINE_FIELD VARCHAR2(36) NOT NULL, OID_MDM_ROUTINE_TABLE VARCHAR2(36), COD_TAB_ANAGRAFICA VARCHAR2(30), COD_FIELD_ANAGRAFICA VARCHAR2(30), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-5', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 358, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-6::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-6' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE MDM_ROUTINE_GERARCHIA (COD_MDM_ROUTINE_GERARCHIA VARCHAR2(5) NOT NULL, COD_MDM_ROUTINE_ELEGER VARCHAR2(30) NOT NULL, TIPO_MDM_ROUTINE_ELEGER VARCHAR2(1), COD_MDM_ROUTINE_GERAR_PADRE VARCHAR2(5), COD_MDM_ROUTINE_ELEGER_PADRE VARCHAR2(30), DESC_MDM_ROUTINE_ELEGER0 VARCHAR2(330), DESC_MDM_ROUTINE_ELEGER1 VARCHAR2(330), DESC_MDM_ROUTINE_ELEGER2 VARCHAR2(330), DESC_MDM_ROUTINE_ELEGER3 VARCHAR2(330), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, ORDINAMENTO NUMBER(6, 0) DEFAULT 0) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-6', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 360, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-7::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-7' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE MDM_ROUTINE_GERARCHIA_ABBIM (COD_MDM_ROUTINE VARCHAR2(30) NOT NULL, COD_MDM_ROUTINE_GERARCHIA VARCHAR2(5) NOT NULL, COD_MDM_ROUTINE_ELEGER VARCHAR2(30) NOT NULL, PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, ORDINAMENTO NUMBER(6, 0) DEFAULT 0) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-7', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 362, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-8::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-8' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('CREATE TABLE MDM_ROUTINE_TABLE (OID_MDM_ROUTINE_TABLE VARCHAR2(36) NOT NULL, COD_MDM_ROUTINE VARCHAR2(30), COD_TAB_ANAGRAFICA VARCHAR2(30), COD_ANAGRAFICA_GERARCHIA VARCHAR2(2), COD_ANAGRAFICA_ELEGER VARCHAR2(30), TIPO_DELETE VARCHAR2(7) DEFAULT ''DEL-MDM'', FLAG_ESCLUDI NUMBER(5) DEFAULT 0, FLAG_NO_PROPAGA_FILTRO NUMBER(5) DEFAULT 0, FLAG_SUBTREE NUMBER(5) DEFAULT 0, FILTRO_SQL_EXPORT VARCHAR2(3500), FILTRO_SQL_IMPORT VARCHAR2(3500), PROVENIENZA VARCHAR2(80), USERUPD VARCHAR2(255), DATEUPD DATE, AZIONE CHAR(1) DEFAULT ''1'', ORDINAMENTO NUMBER(10, 0) DEFAULT 0) TABLESPACE &tbs_data');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-8', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 364, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-90::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-90' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO MDM_ROUTINE_GERARCHIA (COD_MDM_ROUTINE_GERARCHIA, COD_MDM_ROUTINE_ELEGER, TIPO_MDM_ROUTINE_ELEGER, COD_MDM_ROUTINE_GERAR_PADRE, COD_MDM_ROUTINE_ELEGER_PADRE, DESC_MDM_ROUTINE_ELEGER0, DESC_MDM_ROUTINE_ELEGER1, DESC_MDM_ROUTINE_ELEGER2, DESC_MDM_ROUTINE_ELEGER3, PROVENIENZA, USERUPD, DATEUPD, ORDINAMENTO) VALUES ('$', '$', 'R', NULL, NULL, 'Raggruppamento', 'Raggruppamento', 'Raggruppamento', 'Raggruppamento', NULL, NULL, NULL, 0);

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-90', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 366, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-104::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-104' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE ADD CONSTRAINT PK_MDM_ROUTINE PRIMARY KEY (COD_MDM_ROUTINE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-104', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 368, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-105::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-105' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_FIELD ADD CONSTRAINT PK_MDM_ROUTINE_FIELD PRIMARY KEY (OID_MDM_ROUTINE_FIELD) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-105', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 370, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-106::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-106' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_GERARCHIA ADD CONSTRAINT PK_MDM_ROUTINE_GERARCHIA PRIMARY KEY (COD_MDM_ROUTINE_GERARCHIA, COD_MDM_ROUTINE_ELEGER) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-106', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 372, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-107::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-107' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_GERARCHIA_ABBIM ADD CONSTRAINT PK_MDM_ROUTINE_GERARCHIA_ABBIM PRIMARY KEY (COD_MDM_ROUTINE, COD_MDM_ROUTINE_GERARCHIA, COD_MDM_ROUTINE_ELEGER) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-107', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 374, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-108::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-108' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_TABLE ADD CONSTRAINT PK_MDM_ROUTINE_TABLE PRIMARY KEY (OID_MDM_ROUTINE_TABLE) USING INDEX TABLESPACE &tbs_idx');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-108', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 376, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-187::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-187' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_FIELD ADD CONSTRAINT FK_MDM_ROUTINE_FIELD_001 FOREIGN KEY (OID_MDM_ROUTINE_TABLE) REFERENCES MDM_ROUTINE_TABLE (OID_MDM_ROUTINE_TABLE)');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-187', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 378, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-188::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-188' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_GERARCHIA_ABBIM ADD CONSTRAINT FK_MDM_ROUTINE_GER_ABBIM_001 FOREIGN KEY (COD_MDM_ROUTINE) REFERENCES MDM_ROUTINE (COD_MDM_ROUTINE)');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-188', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 380, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-189::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-189' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_GERARCHIA_ABBIM ADD CONSTRAINT FK_MDM_ROUTINE_GER_ABBIM_002 FOREIGN KEY (COD_MDM_ROUTINE_GERARCHIA, COD_MDM_ROUTINE_ELEGER) REFERENCES MDM_ROUTINE_GERARCHIA (COD_MDM_ROUTINE_GERARCHIA, COD_MDM_ROUTINE_ELEGER)');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-189', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 382, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/application_repository/install/tables/repository_create.xml::1445602669917-190::liquibase (generated)
declare
x number;

begin
select count(*) into x from databasechangelog where id = '1445602669917-190' and author = 'liquibase (generated)' and filename = 'liquibase/application_repository/install/tables/repository_create.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

execute immediate ('ALTER TABLE MDM_ROUTINE_TABLE ADD CONSTRAINT FK_MDM_ROUTINE_TABLE_001 FOREIGN KEY (COD_MDM_ROUTINE) REFERENCES MDM_ROUTINE (COD_MDM_ROUTINE)');

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('1445602669917-190', 'liquibase (generated)', 'liquibase/application_repository/install/tables/repository_create.xml', SYSTIMESTAMP, 384, NULL, 'sql, customChange', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase/framework/install.xml::v000::MajorVersion
declare
x number;

begin
select count(*) into x from databasechangelog where id = 'v000' and author = 'MajorVersion' and filename = 'liquibase/framework/install.xml' and exectype IN ('EXECUTED','RERAN','MARK_RAN');
if (x = 0) then
begin

INSERT INTO DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE) VALUES ('v000', 'MajorVersion', 'liquibase/framework/install.xml', SYSTIMESTAMP, 386, NULL, 'sql', '', 'EXECUTED', '()', NULL, '3.4.1');

end;
end if;
end;
/

COMMIT;
-- End Changeset;

-- Changeset liquibase::ic-e31707bc-3739-488f-a3e4-6bf18e7b045b::liquibase
INSERT INTO REP_AGGIORNAMENTO_DB (VERSIONE_DB, VERSIONE_AGGIORNAMENTO, DATA_AGGIORNAMENTO, NOTE, NUMERO_PATCH, DATA_PATCH, FLAG_AGGIORNAMENTO_IN_CORSO) VALUES ('v000', '0', SYSDATE, '{"version":"5.3.27.400.tgk","client":"script","status":"COMPLETED"}', 0, NULL, 0);

COMMIT;

