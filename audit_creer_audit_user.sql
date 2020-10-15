-- Execute this script as SYSTEM to create a dedicated audit user
-- Verify existence of tablespace TOOLS
set serveroutput on
set define off
WHENEVER sqlerror EXIT sql.sqlcode
DECLARE
   tabtools number;
BEGIN
   select count(tablespace_name) into tabtools from dba_tablespaces
    where tablespace_name = 'TOOLS';
   IF tabtools = 0 THEN
         dbms_output.put_line('Add a tablespace TOOLS to create the table histaudit');
         raise_application_error(-20001,'Tablespace TOOLS does not exist');
   END IF;
END;
/
set define "&"

-- Create schema PERFAUDIT
DECLARE
   userhist number;
BEGIN
   select count(username) into userhist from dba_users where username='PERFAUDIT';
   IF userhist = 0 THEN
		EXECUTE IMMEDIATE 'CREATE USER PERFAUDIT identified by perfaudit_password default tablespace TOOLS';
		EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO PERFAUDIT';
		EXECUTE IMMEDIATE 'GRANT SELECT ANY DICTIONARY TO PERFAUDIT';
		EXECUTE IMMEDIATE 'GRANT EXECUTE ON SYS.UTL_FILE TO PERFAUDIT';
		EXECUTE IMMEDIATE 'GRANT CREATE ANY DIRECTORY, DROP ANY DIRECTORY TO PERFAUDIT';
		EXECUTE IMMEDIATE 'GRANT CREATE PUBLIC SYNONYM, DROP PUBLIC SYNONYM TO PERFAUDIT';
   END IF;
END;
/

-- Move table HISTAUDIT in schema PERFAUDIT if it exists
DECLARE
   tabhist number;
   userhist varchar2(255);
BEGIN
   select count(table_name) into tabhist from dba_tables
    where table_name='HISTAUDIT';
   IF tabhist > 0 THEN
      select owner into userhist from dba_tables where table_name='HISTAUDIT';
      IF userhist <> 'PERFAUDIT' THEN
--         CREATE table perfaudit.histaudit as select * from system.histaudit;
         EXECUTE IMMEDIATE 'create table perfaudit.histaudit as select * from '|| userhist ||'.histaudit';
         EXECUTE IMMEDIATE 'DROP table '|| userhist ||'.histaudit';
      END IF;
   END IF;
END;
/

EXIT
