-- AUDIT BASES ORACLE
-- Compatible Oracle 10g to 19c
-- (c) 2005, Frank Soyer <frank.soyer@gmail.com>

-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- The GNU General Public License is available at:
-- http://www.gnu.org/copyleft/gpl.html

-- *********************************************** SCRIPT **************************************************

define script_version = 3.4

-- *************************************** Initialize SQLPlus variables
set pages 999
set lines 200
set echo off
set termout off
set trims on
set showmode off
set verify off
set feed off
set serveroutput on size 1000000
set head off
-- "&" is used for HTML formatting. We need to change it for Oracle "DEFINE" special character
set define "~"

-- On force quelques formats
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ", ";
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
ALTER SESSION SET NLS_DATE_LANGUAGE = 'FRENCH';

-- ************************************** CONSTANTS
-- param 1 = tablespace for audit table, param 2 = audit table name
-- Force a default value if no cmd line parameter
column 1 new_value 1 noprint
select '' "1" from dual where rownum = 0;
define tbstools = ~1 TOOLS
-- Force default value if no cmd line parameter
column 2 new_value 2 noprint
select '' "2" from dual where rownum = 0;
define tblhist = ~2 HISTAUDIT
define logfile = ORACLE
define envfile = env

-- *************************************** Creation de fonctions
-- Fonction CouleurLimite renvoie :
-- ROUGE (si valeur en dehors de limite +/- plage en fonction de "superieur" (voir "VERT", calcul inverse)),
-- ORANGE (si valeur a l'interieur de la plage (limite +/- plage),
-- VERT (si valeur superieure à (limite + plage) ET "superieur" <= 0, valeur inferieure si "superieur" > 0)
-- soit :
--               < | limite - plage | valeur limite | limite + plage | >
-- si "superieur" <= 0 :
-- < ALERT (ROUGE) |                 WARNING (ORANGE)                | OK (VERT) >
-- si "superieur" > 0 :
-- < OK (VERT)     |                 WARNING (ORANGE)                | ALERT (ROUGE) >

CREATE OR REPLACE FUNCTION CouleurLimite (valeurAtester number, limite number, plage number, superieur int)
RETURN varchar2
IS
signe number;
BEGIN
if superieur <= 0 then -- on teste si la valeur tombe EN-DESSOUS de limite+/-plage (DOIT etre superieure)
   if valeurAtester < limite then --  deja inferieure a limite, mais est-on encore dans limite-plage ?
      select SIGN(valeurAtester-(limite-(plage))) into signe from dual;
      if signe < 0 then -- la valeur a tester est inferieure a limite-plage : ALERT
	 return '#FF0000'; --ROUGE
      else -- la valeur a tester est entre limite-plage et limite : WARN
	 return '#FF9900'; --ORANGE
      end if;
   else --  superieure a limite, mais est-on deja dans la limite+plage ?
      select SIGN(valeurAtester-(limite+(plage))) into signe from dual;
      if signe > 0 then -- la valeur a tester est superieure a limite+plage : OK
	 return '#33FF33';--VERT
      else -- la valeur a tester est deja tombee dans limite+plage : WARN
	 return '#FF9900';--ORANGE
      end if;
   end if;
else -- on teste si la valeur DEPASSE limite+/-plage (DOIT etre inferieure)
   if valeurAtester >= limite then -- on est deja au-dessus de la limite, est-on encore dans limite+plage ?
      select SIGN(valeurAtester-(limite+(plage))) into signe from dual;
      if signe > 0 then -- on a depasse limite+plage : ALERT
	 return '#FF0000'; --ROUGE
      else -- on est encore dans la plage : WARN
	 return '#FF9900'; --ORANGE
      end if;
   else -- on est encore en-dessous de limite, mais est-on deja dans la plage ?
      select SIGN(valeurAtester-(limite-(plage))) into signe from dual;
      if signe < 0 then -- on est encore en-dessous : OK
	 return '#33FF33';--VERT
      else -- on est deja dans la plage : WARN
	 return '#FF9900';--ORANGE
      end if;
   end if;
end if;
END;
/

-- *************************************** Variables and constants
-- BEWARE : NO SPACES IN LISTS, OR THE VARIABLE WILL BE TRUNCED !
define sysusers = ('SYS','SYSTEM','CTXSYS','DBSNMP','OUTLN','ORDSYS','ORDPLUGINS','MDSYS','DMSYS','WMSYS','WKSYS','OLAPSYS','SYSMAN','XDB','EXFSYS','TSMSYS','MGMT_VIEW','ORACLE_OCM','DIP','SI_INFORMTN_SCHEMA','ANONYMOUS')
define exusers = ('SCOTT','HR','OE','PM','QS','QS_ADM','QS_CBADM','QS_CS','QS_ES','QS_OS','QS_WS','SH','PERFAUDIT')
-- Icons (base64)
variable tips varchar2(2000);
execute :tips := 'iVBORw0KGgoAAAANSUhEUgAAABMAAAATCAYAAAByUDbMAAAABmJLR0QAAAAAAAD5Q7t/AAAACXBIWXMAAAsQAAALEAGtI711AAAACXZwQWcAAAATAAAAEwDxf4yuAAACDElEQVQ4y62ULXDbQBBGnzsFK2YxHzyoMJk50NBhCWugYcpCA0PDEmjosphF0DBmEqvgwSs7MS1TgSz5v9OZdmd2NKNZvfv20+4Nmqbhf8XXcy9L5xpfFpTlGlfmaPiFxCNsMiZJppgkJbF2cPzd4FjZZrNpPpZPRHySJoIxYIzgveIc5KWCXHNz/8xkMhlchGWrH81qMWd+L6SpgOxVKug281xZZcrtw4LZ7FsP7Ntcr7MmW855fhoyHIFE0WEPEVDXiMJ4LJgY3t7mxLFtOoVfOo9Wi+88zOUENDCuT4kiEBABM4LZVHhfPFI61/QwV6yxxmOtnIB8qPvsgCIgkXCdQFwXuGJDDyvyjOvxoUcdaD86IEJfm15BkX/sYL4ssFa4FCY+8k+3T4F4CN7tKQsakMusy6Gtf1qFHSyWGA26OxFovD1RZOKIxtsDdaogw3gHM0nKT7edo7o+C+xAWtfbOiUoeA/GTnawdDyjKLbKjoAHXdV1P7woEJTSQTq+2cFsOsV5Q+mUqgKtQEN9AtUKqqqFhKoFhSjFpnvKEmsHtw+vLJeKd4oGbYEVhHwEQPgctb5uQZWHrIC7+Uu/9Gd3czZtB7L7/Z3ZYa+1bAO3j4e7efbWeF88EtcF6VW7NhJBFVqzu9bu5i9/vjW6KJ1rXLGhyD/w5YaggVhiTDIhHd9g08nf3Wf/Er8BAI4wKLDf6EwAAAAfelRYdENyZWF0aW9uIFRpbWUAAHjaMzDTNzLUNzABAAb7AYwMyT+gAAAALnpUWHRTb2Z0d2FyZQAAeNrzTUwuys9NTclMVHDLLEotzy/KLlbwjVAwMjAwAQCWLgl6ZrFa0gAAAABJRU5ErkJggg=='

variable info varchar2(2000);
execute :info := 'R0lGODlhFAAUAOfAAD+JSDyVQEqTTFqTZkedQ0eeQ1CjRVKlRmScdWaccGibdVepRmSlUVqqSV2pUlytSG6jfXWjf2OxTGayS2SzSW+ueXGxVmqzWXGyb2y3TW22Vm64TnC6TXC7T3y2YX+2bXq2fna+UHu5c323gom2b3e/Unm+W3q+X328cHnBUYS8Y3rBUZ+uooe5fIO8gn3EUoHAb4W+f4DDYYPBbn/FU6OyqITBcX/GUYDGU4LEYZK+coHHVILIU4jCgI7DZYfEcZK/i6q2pYvDgae3qZXCdIPLUqi3rIrHaofJYo/EfYvHco7FgZDDkIrKXojMVYjNVYnNVZHIgpTGkZXGkYzPVqe/r7O9qZjIko/RV6DJd7O/rJrKk5vPYJzKlZTSYJPUV5PVVpPVV5/KpLLDsqPJppPWVp/MmpXWWLPEsrnDraHMpKLNo6LNpKTOpaXPpbfItp3ZYqrOs6fRornKtqnQsZ3dWq/Qr5/eWqrYeaLdZarbZLDSr6/Ss6/SubDSuMHMxcXLxbHTtaPhWsbMxbLVrLLUtsLOxbLVtrPVtqved7nXoLXWvrnVvbnXu7ranM3Rx8nUt8rSysvSyb3cn8/TyMvWuK/mbL3dna7rW8bfy9zX3sjgzd3Z4cnhzcnhzt3a4d7a4bvzYOLe47/3X+Tg5dbqw+fi5dDvq+Tk5Ojj5+Xl5cb8Y+bm5unl6Nnr3url6tvr4Orp6+7p7O7q7ezr7ezs7O7t7u7u7ubx6Ojy6vDw8PHx8fH38/f29/f5+Pr7+////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////yH+EUNyZWF0ZWQgd2l0aCBHSU1QACH5BAEKAP8ALAAAAAAUABQAAAj+AP8JHEiwoMGDCBMKlPWnShVDsxQK1FUDQR9XsBZBMLIroSkFcTZ54pUrUyc/EVodrDWATiA+uIABY4So0KEEtwyyqCBGzZpGwHyRcdOGzYghvQimAgCCiRQzcvbY6bLlyhQXAl4RBBQAQ4wehH7JBBJliRARBSIRHEPAAQoYM5LIbKHkh40LB94QRGOggYYTMo7I/IAkh4kJD+YQHLRAwoYSNJrI9PBkx4oOFCQRFMUgQwgcULzIVBGGCo8UFkgVDMLhhZMvcGT6uHOGyg0ttgqqIlEES55TMktZqlOGCKuDmnSASaTI0aVJeARlAZUQlRUumEKtGqUnDSqJtDgNPYJUidKnWBLTq1cYEAA7'

column bname new_value dbname noprint
column hname new_value hstname noprint
select name as bname from v$database;
select host_name as hname from v$instance;

column bloc new_value dbloc noprint
select value as bloc from v$parameter
	where name = 'db_block_size';

column bdate new_value dateaudit noprint
select to_char(to_date(sysdate),'ddmmyy') as bdate from dual;

set termout on
prompt ******** AUDIT ~dbname (~hstname) ***********************
set termout off

spool ~logfile._~dbname._~hstname._~dateaudit..html

-- *************************************** Headers
prompt <!DOCTYPE public "-//w3c//dtd html 4.01 strict//en" "http://www.w3.org/TR/html4/strict.dtd">
prompt <html>
prompt <head>
prompt <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
prompt <meta name="description" content="Audit Oracle HTML">
prompt <title>Audit ~dbname (~hstname)</title>
prompt </head>
prompt <BODY BGCOLOR="#003366">
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center> 
prompt <font color=WHITE size=+2><b>Audit ~dbname (~hstname)
select ' du ',to_char(to_date(sysdate),'DD-MON-YYYY',N'NLS_DATE_LANGUAGE = AMERICAN'),'</b>' as DATE_AUDIT from dual;
prompt <font size=1>(v~script_version)</font>
prompt </font></td></tr></table>
prompt <br>

-- *************************************** Section informations
prompt <hr>
prompt <div align=center><b><font color="WHITE">SECTION INFORMATIONS</font></b></div>
prompt <hr>

-- *************************************** audit historic
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Historique d&#39;audits</b></font></td></tr>
-- Creation table HISTAUDIT si necessaire
prompt <tr><td width=20%><b>Table historique</b></td>

-- force sqlplus to exit on error, tablespace TOOLS (or whatever is in variable "tbstools") is mandatory
WHENEVER sqlerror EXIT sql.sqlcode

DECLARE
   tabhist number;
   tabtools number;
   tabtab varchar2(255);
   colmodif number;
   colval number;
   collength number;
   tbs_tools_absent EXCEPTION;

BEGIN

   select count(table_name) into tabhist from dba_tables
    where table_name='~tblhist';
   select count(tablespace_name) into tabtools from dba_tablespaces
    where tablespace_name = '~tbstools';

   IF tabtools = 0 THEN
      dbms_output.put_line('<td bgcolor="#FF0000">Ajouter un tablespace <b>~tbstools</b> et y cr&eacute;er la table <b>~tblhist</b></br>');
      raise_application_error(-20001,'Tablespace ~tbstools does not exist. Please create it before continuing');
      dbms_output.put_line('</td></tr></table>');
   END IF;
   IF tabhist = 0 THEN
      dbms_output.put_line('<td bgcolor="#33FF33">Creation table ~tblhist tablespace ~tbstools...<br>');
      EXECUTE IMMEDIATE 'create table ~tblhist
                        (date_aud  date,
                         type_obj varchar2(5),
                         obj_name varchar2(255),
                         total number,
                         utilis number,
                         VALEUR varchar2(255))
                       TABLESPACE ~tbstools';
      EXECUTE IMMEDIATE 'create or replace public synonym ~tblhist for ~tblhist';
   ELSE
      select tablespace_name into tabtab from dba_tables where table_name='~tblhist';
      IF tabtab <> '~tbstools' THEN
         dbms_output.put_line('<td bgcolor="#FF0000">(table ~tblhist existante, tablespace '||tabtab||')<br/>');
         dbms_output.put_line('D&eacute;placer la table ~tblhist dans le tablespace <b>~tbstools</b> pr&eacute;conis&eacute;</b>.<br/><br/>');
         raise_application_error(-20002,'Table ~tblhist needs to be moved');
      END IF;

      select count(column_name) into colmodif from dba_tab_columns
       where table_name='~tblhist' AND column_name='MODIFIED';
      select count(column_name) into colval from dba_tab_columns
       where table_name='~tblhist' AND column_name='VALEUR';
      select char_length into collength from dba_tab_columns
       where table_name='~tblhist' and column_name='OBJ_NAME';
      IF colval>0 AND collength>=255 THEN
         dbms_output.put_line('<td bgcolor="#33FF33">Table ~tblhist existante ');
      ELSE
		  IF colval=0 THEN
		     IF colmodif>0 THEN
		        EXECUTE IMMEDIATE 'alter table ~tblhist drop column MODIFIED';
		     END IF;
		     EXECUTE IMMEDIATE 'alter table ~tblhist add VALEUR varchar2(255)';
		     dbms_output.put_line('<td bgcolor="#FF9900">Modification table ~tblhist (col VALEUR)');
		  END IF;
		  IF collength < 255 THEN
		     EXECUTE IMMEDIATE 'alter table ~tblhist modify OBJ_NAME varchar2(255)';
		     dbms_output.put_line('<td bgcolor="#FF9900">Modification table ~tblhist (col OBJ_NAME)');
		  END IF;
      END IF;
   END IF;
END;
/
-- now avoid sqlplus to exit
WHENEVER sqlerror CONTINUE;

prompt </td></tr>
prompt <tr><td width=20%><b>Pr&eacute;c&eacute;dent audit</b></td>
prompt <td bgcolor="LIGHTBLUE">

variable last_audit varchar2(100);
begin
      select decode(max(to_date(date_aud)),'','<font color="#FF0000"><b><i>Premier audit</i></b></font>',to_char(max(to_date(date_aud)),'DD-MON-YYYY',N'NLS_DATE_LANGUAGE = AMERICAN')) into :last_audit from ~tblhist
      where to_date(date_aud) < trunc(sysdate);
end;
/
print last_audit
prompt </td></tr></table><br>

-- *************************************** Hote
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>H&ocirc;te (informations OS)</b></font></td></tr>
prompt <tr><td bgcolor="WHITE"><b>Host</b></td><td bgcolor="WHITE"><b>OS</b></td><td bgcolor="WHITE"><b>CPUs</b></td><td bgcolor="WHITE"><b>Cores/CPU</b></td><td bgcolor="WHITE"><b>RAM</b></td>
prompt <tr><td bgcolor="LIGHTBLUE" width=20%>~hstname</td>
select '<td bgcolor="LIGHTBLUE" width=20%>',PLATFORM_NAME,'</td><td bgcolor="LIGHTBLUE" width=20%>',cpu.VALUE,'</td><td bgcolor="LIGHTBLUE" width=20%>',decode(core.VALUE,NULL,'-',core.VALUE), '</td><td bgcolor="LIGHTBLUE" width=20% align=right>', to_char(round(ram.VALUE/(1024*1024),2),'99G999G990D00'), ' Mo', '</td></tr>'
from v$database, v$osstat cpu
left outer join v$osstat core
on core.STAT_NAME = 'NUM_CPU_CORES'
left outer join v$osstat ram
on ram.STAT_NAME = 'PHYSICAL_MEMORY_BYTES'
where cpu.STAT_NAME = 'NUM_CPUS';

DECLARE cnt_host number := 0;
BEGIN
   select count(cpu.STAT_NAME) into cnt_host
   from v$database, v$osstat cpu
   left outer join v$osstat core
   on core.STAT_NAME = 'NUM_CPU_CORES'
   left outer join v$osstat ram
   on ram.STAT_NAME = 'PHYSICAL_MEMORY_BYTES'
   where cpu.STAT_NAME = 'NUM_CPUS';
   if cnt_host=0 then
      dbms_output.put_line('<td bgcolor="LIGHTGREY" colspan=4><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20>');
   end if;
end;
/
prompt </table>

prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>H&ocirc;te (statistiques Oracle)</b></font></td></tr>
prompt <tr><td bgcolor="WHITE"><b>Sockets (courants)</b></td><td bgcolor="WHITE"><b>CPUs logiques (courants) / Coeurs (courants)</b></td><td bgcolor="WHITE"><b>Sockets (highwater)</b></td><td bgcolor="WHITE"><b>CPUs logiques (highwater) / Cores (highwater)</b></td></tr>
select '<td bgcolor="LIGHTBLUE" align=center>', decode(CPU_SOCKET_COUNT_CURRENT,NULL,'-',CPU_SOCKET_COUNT_CURRENT), '</td><td bgcolor="LIGHTBLUE" align=center>', CPU_COUNT_CURRENT,' / ', decode(CPU_CORE_COUNT_CURRENT,NULL,'-',CPU_CORE_COUNT_CURRENT), '</td><td bgcolor="LIGHTBLUE" align=center>', decode(CPU_SOCKET_COUNT_HIGHWATER,NULL,'-',CPU_SOCKET_COUNT_HIGHWATER), '</td><td bgcolor="LIGHTBLUE" align=center>', CPU_COUNT_HIGHWATER, ' / ', decode(CPU_CORE_COUNT_HIGHWATER,NULL,'-',CPU_CORE_COUNT_HIGHWATER), '</td></tr>' from v$license;

prompt </table>
prompt <br>

-- *************************************** Usage hote
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Usage CPU (valeurs instantan&eacute;es)</b></font></td></tr>
prompt <tr><td bgcolor="WHITE" colspan=2><b>Statistique</b></td><td bgcolor="WHITE" colspan=2><b>Valeur</b></td>

-- http://www.oracle.com/technetwork/articles/schumacher-analysis-099313.html
select '<tr><td bgcolor="LIGHTBLUE" colspan=2>', metric_name, '</td><td bgcolor="LIGHTBLUE" align=right colspan=2>', round(value,2), '%</td></tr>'
from SYS.V_$SYSMETRIC
where METRIC_NAME IN ('Database CPU Time Ratio', 'Database Wait Time Ratio')
AND INTSIZE_CSEC = (select max(INTSIZE_CSEC) from SYS.V_$SYSMETRIC)
Order by 2 asc;
prompt </td></tr>

prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Usage CPU d&eacute;taill&eacute;</b></font></td></tr>
prompt <tr><td bgcolor="WHITE"><b>Statistique</b></td><td bgcolor="WHITE"><b>Minimum</b></td><td bgcolor="WHITE"><b>Maximum</b></td><td bgcolor="WHITE"><b>Moyenne</b></td>

select CASE METRIC_NAME
 WHEN 'SQL Service Response Time' then '<tr><td bgcolor="LIGHTBLUE">SQL Service Response Time (secs)</td>'
 WHEN 'Response Time Per Txn' then '<tr><td bgcolor="LIGHTBLUE">Response Time Per Txn (secs)</td>'
ELSE '<tr><td bgcolor="LIGHTBLUE">'||METRIC_NAME||'</td>'
END METRIC_NAME,
CASE METRIC_NAME
 WHEN 'SQL Service Response Time' then '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((MINVAL / 100),2),'999G990D00')||'</td>'
 WHEN 'Response Time Per Txn' then '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((MINVAL / 100),2),'999G990D00')||'</td>'
ELSE '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((MINVAL / 100),2),'999G990D00')||'</td>'
END MININUM,
CASE METRIC_NAME
 WHEN 'SQL Service Response Time' then '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((MAXVAL / 100),2),'999G990D00')||'</td>'
 WHEN 'Response Time Per Txn' then '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((MAXVAL / 100),2),'999G990D00')||'</td>'
ELSE '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((MAXVAL / 100),2),'999G990D00')||'</td>'
END MAXIMUM,
CASE METRIC_NAME
 WHEN 'SQL Service Response Time' then '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((AVERAGE / 100),2),'999G990D00')||'</td>'
 WHEN 'Response Time Per Txn' then '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((AVERAGE / 100),2),'999G990D00')||'</td>'
ELSE '<td bgcolor="LIGHTBLUE" align=right>'||to_char(ROUND((AVERAGE / 100),2),'999G990D00')||'</td></tr>'
END AVERAGE
 from SYS.V_$SYSMETRIC_SUMMARY 
 where METRIC_NAME in ('CPU Usage Per Sec',
 'CPU Usage Per Txn',
 'Database CPU Time Ratio',
 'Database Wait Time Ratio',
 'Executions Per Sec',
 'Executions Per Txn',
 'Response Time Per Txn',
 'SQL Service Response Time',
 'User Transaction Per Sec')
 ORDER BY 1;

prompt </td></tr>
prompt </table>
prompt <br>

-- *************************************** Versions
delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='VERS';
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Versions</b></font></td></tr>

-- Add <td> if no rows are returned (first audit)
select decode(count(valeur), 0, '<tr><td bgcolor="LIGHTBLUE" colspan=5>')
 from ~tblhist
 where obj_name like 'Oracle Database%';
-- else change bg color if version has changed
select decode(banner, valeur, '<tr><td bgcolor="LIGHTBLUE" colspan=5>','<tr><td bgcolor="#FF0000" colspan=5><b>Version modifi&eacute;e depuis le dernier audit</b><br><br>') from v$version,~tblhist where banner like 'Oracle Database%'
 and obj_name like 'Oracle Database%'
 and to_date(date_aud) = (select max(to_date(date_aud)) from ~tblhist where type_obj = 'VERS');

select banner,'<br>' from v$version;
prompt </td></tr>

-- *************************************** MISE A JOUR TABLE HISTORIQUE (VERSION)
insert into ~tblhist (
select sysdate, 'VERS', 'Oracle Database', 0, 0, banner
from v$version
  where banner like 'Oracle Database%');

-- *************************************** Patchs installés
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Patchs install&eacute;s</b></font></td></tr>
prompt <tr><td bgcolor="WHITE"><b>Date</b></td><td bgcolor="WHITE"><b>Action</b></td><td bgcolor="WHITE"><b>Version</b></td><td bgcolor="WHITE"><b>ID</b></td><td bgcolor="WHITE"><b>Description</b></td>

select '<tr><td bgcolor="LIGHTBLUE">',to_char(ACTION_TIME,'DD/MM/YYYY'), '</td><td bgcolor="LIGHTBLUE">', ACTION, '</td><td bgcolor="LIGHTBLUE">', VERSION, '</td><td bgcolor="LIGHTBLUE">', ID, '</td><td bgcolor="LIGHTBLUE">', COMMENTS,'</td></tr>'
   from sys.registry$history
   order by 1;

DECLARE cnt_patch number := 0;
BEGIN
   select count(ACTION_TIME) into cnt_patch from sys.registry$history;
   if cnt_patch=0 then
      dbms_output.put_line('<tr><td bgcolor="LIGHTGREY"><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor="LIGHTGREY"></td><td bgcolor="LIGHTGREY"></td><td bgcolor="LIGHTGREY"></td><td bgcolor="LIGHTGREY"></td></tr>');
   end if;
end;
/

-- *************************************** Options installées et utilisées
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Composants install&eacute;s</b></font></td></tr>
prompt <tr><td bgcolor="WHITE" align=center colspan=2><b>Composant</b></font></td><td bgcolor="WHITE" align=center><b>ID</b></font></td><td bgcolor="WHITE" align=center><b>Statut</b></font></td><td bgcolor="WHITE" align=center><b>Version</b></font></td></tr>

select '<tr><td bgcolor="LIGHTBLUE" colspan=2>',COMP_NAME,'</td><td bgcolor="LIGHTBLUE">', COMP_ID,'</td><td bgcolor="LIGHTBLUE">',STATUS,'</td><td bgcolor="LIGHTBLUE">',VERSION,'</td></tr>' from DBA_REGISTRY;

prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Options install&eacute;es</b></font></td></tr>

SELECT DISTINCT '<tr><td bgcolor="LIGHTBLUE" colspan=5>',PARAMETER,'</td>','</tr>' FROM V$OPTION where VALUE = 'TRUE' order by 1;

prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Fonctions principales</b></font></td></tr>
prompt <tr><td bgcolor="WHITE" align=center colspan=4><b>Fonction</b></font></td><td bgcolor="WHITE" align=center><b>activ&eacute;e oui/non (derni&egrave;re date d&#39;usage)</b></font></td></tr>

select '<tr><td bgcolor="LIGHTBLUE" colspan=4>',version || ' - ' || name,'</td><td bgcolor="LIGHTBLUE" align=right>',CURRENTLY_USED || ' (' || decode(last_usage_date,NULL,'NONE',to_char(last_usage_date)) || ')</td></tr>' from dba_feature_usage_statistics where (detected_usages > 0 or name = 'Automatic Workload Repository') order by version;

select '<tr><td bgcolor="LIGHTBLUE" colspan=4>','Control management pack (diagnostic pack, tuning pack)','</td><td bgcolor="LIGHTBLUE" align=right>', to_char(display_value) || '</td></tr>' from v$parameter
where name = 'control_management_pack_access';

prompt </table>
prompt <br>

-- *************************************** SPFILE ou init.ora ?
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="Si l'instance est lanc&eacute;e avec un fichier SPFILE le chemin de celui-ci est affich&eacute;. Dans le cas contraire on affiche seulement 'PFILE' car le chemin du fichier texte init.ora n'est pas disponible dans les tables syst&egrave;me."></td>

prompt <td align=center><font color="WHITE"><b>Initialisation : pfile (init.ora) ou spfile ?</b></font></td></tr></table></td></tr>
SELECT decode(value,'','<td bgcolor="ORANGE" width=15%>PFILE</td>','<td bgcolor="#33FF33" width=15%>SPFILE</td>'), decode(value,'','<td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td></tr>','<td>'||value||'</td></tr>') FROM v$parameter WHERE name like 'spfile' ;
-- TODO : "host echo $ORACLE_HOME;" affiche bien la variable dans sqlplus mais pas avec spool. 

prompt </table>
prompt <br>

-- *************************************** NLS_PARAMETERS
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Param&egrave;tres NLS Instance</b></font></td></tr>
prompt <tr><td width=50%><b>Param&egrave;tre</b></td><td width=50%><b>Valeur</b></td>
select '<tr><td bgcolor="LIGHTBLUE">',parameter,'</td>','<td bgcolor="LIGHTBLUE">',value,'</td>','</tr>' from v$nls_parameters;

prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Param&egrave;tres NLS database</b></font></td></tr>
prompt <tr><td width=50%><b>Param&egrave;tre</b></td><td width=50%><b>Valeur</b></td>
select '<tr><td bgcolor="LIGHTBLUE">',parameter,'</td>','<td bgcolor="LIGHTBLUE">',value,'</td>','</tr>' from nls_database_parameters;

prompt </td></tr></table>
prompt <br>

-- *************************************** AUTRES PARAMETRES D'INIT
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="Les principaux param&egrave;tres d&#39;initialisation sont indiqu&eacute;s dans les sections correspondant &agrave; leur champ d&#39;action. Ne sont list&eacute;s ici que les param&egrave;tres qui ne sont pas notifi&eacute;s ailleurs dans ce document."></td>
prompt <td bgcolor="#3399CC" align=center><font color="WHITE"><b>Autres param&egrave;tres d&#39;initialisation (instance)</b></font></td></tr></table></td></tr>
prompt <tr><td width=20%><b>Param&egrave;tre</b></td><td width=50%><b>Valeur</b></td>

column audcnt new_value vaudcnt noprint
select count(*) as audcnt from sys.aud$;
column audsze new_value vaudsze noprint
select decode(sign(bytes/1024/1024 - 1) , -1, '0'||replace(to_char(bytes/1024/1024),',','.'),replace(to_char(bytes/1024/1024),',','.')) as audsze from dba_segments
  where owner = 'SYS' and segment_type='TABLE' and segment_name='AUD$';

select '<tr><td bgcolor="LIGHTBLUE">',name,'</td>','<td bgcolor="LIGHTBLUE">',value,'</td>','</tr>' from v$parameter where name in
('control_files',
'open_cursors',
'processes',
'compatible',
'remote_login_passwordfile',
'session',
'utl_file_dir',
'undo_retention',
'sec_case_sensitive_logon',
'diagnostic_dest',
'db_cache_advice')
union
select '<tr><td bgcolor="LIGHTBLUE">', au.name, '</td>', '<td bgcolor="'|| decode(lower(au.value), 'none', '#33FF33', 'ORANGE') || '">', decode(lower(au.value), 'os', au.value||' ('||aup.value||')', 'xml', au.value||' ('||aup.value||')', 'xml, extended', au.value||' ('||aup.value||')', au.value) || ' (table AUD$ = ' || ~vaudcnt || ' rows, '|| trim(to_char(~vaudsze,'999G999G999G990D00')) ||' Mo)','</td>','</tr>' from v$parameter au, v$parameter aup where au.name='audit_trail' and aup.name='audit_file_dest';

-- *************************************** MISE A JOUR TABLE HISTORIQUE (PARAMETRES INIT)
delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='INIT';
insert into ~tblhist (
select sysdate, 'INIT', substr(name,1,30), 0, 0, value
from v$parameter
  where ISDEFAULT='FALSE'
  and name not like '%nls%');
-- NLS session parameters change in instance according to client config. We keep only database parameters.
insert into ~tblhist (
select sysdate, 'INIT', substr(parameter,1,30), 0, 0, value
from nls_database_parameters);

-- *************************************** Modifies lors du dernier audit ?
prompt <tr>
select decode(max(to_date(date_aud)),'','<td width=20%><b>Principaux param&egrave;tres</b></td>','<td width=20%><b>Param&egrave;tres modifi&eacute;s depuis le dernier audit</b></td>') from ~tblhist
  where to_date(date_aud) < trunc(sysdate);

DECLARE cnt_init number := 0;
BEGIN
  select count(H1.obj_name) into cnt_init from ~tblhist H1, ~tblhist H2
  where H1.obj_name = H2.obj_name
  and H1.type_obj = 'INIT'
  and H2.type_obj = 'INIT'
  and H1.valeur <> H2.valeur
  and trunc(to_date(H1.date_aud)) = trunc(sysdate)
  and to_date(H2.date_aud) = (select max(to_date(date_aud)) from ~tblhist
                           where to_date(date_aud) < trunc(sysdate));
-- test if a parameter was initialized (ie added in the non-default parameters)
  if cnt_init=0 then
     select count(H1.obj_name) into cnt_init from ~tblhist H1
     where H1.type_obj = 'INIT'
     and H1.obj_name not in
        (select H2.obj_name from ~tblhist H2
         where H2.type_obj = 'INIT'
         and to_date(H2.date_aud) = (select max(to_date(date_aud)) from ~tblhist
                             where to_date(date_aud) < trunc(sysdate)))
     and trunc(to_date(H1.date_aud)) = trunc(sysdate);
  end if;
-- test if a parameter was resetted (ie deleted from non-default parameters)
  if cnt_init=0 then
  select count(H2.obj_name) into cnt_init from ~tblhist H2
     where H2.type_obj = 'INIT'
     and to_date(H2.date_aud) = (select max(to_date(date_aud)) from ~tblhist
                                 where to_date(date_aud) < trunc(sysdate))
     and H2.obj_name not in
        (select H1.obj_name from ~tblhist H1
         where H1.type_obj = 'INIT'
         and trunc(to_date(H1.date_aud)) = trunc(sysdate));
  end if;
  if cnt_init=0 then
     dbms_output.put_line('<td bgcolor="#33FF33">AUCUN');
  else
     dbms_output.put_line('<td bgcolor="ORANGE">');
  end if;
end;
/

select H1.obj_name, ' (', H2.valeur, ' -> ', H1.valeur, ')<br>' -- parametres modifies
from ~tblhist H1, ~tblhist H2
  where H1.obj_name = H2.obj_name
  and H1.type_obj = 'INIT'
  and H2.type_obj = 'INIT'
  and H1.valeur <> H2.valeur
  and trunc(to_date(H1.date_aud)) = trunc(sysdate)
  and to_date(H2.date_aud) = (select max(to_date(date_aud)) from ~tblhist
                           where to_date(date_aud) < trunc(sysdate))
UNION
select H1.obj_name, ' (', '<b>New</b>', ' -> ', H1.valeur, ')<br>' -- nouveaux parametres
from ~tblhist H1
  where H1.type_obj = 'INIT'
  and H1.obj_name not in
      (select H2.obj_name from ~tblhist H2
       where H2.type_obj = 'INIT'
       and to_date(H2.date_aud) = (select max(to_date(date_aud)) from ~tblhist
                           where to_date(date_aud) < trunc(sysdate)))
  and trunc(to_date(H1.date_aud)) = trunc(sysdate)
UNION
select H1.obj_name, ' (', H1.valeur, ' -> ', '<b>Default</b>', ')<br>' -- parametres réinitialises au defaut
from (select * from ~tblhist H
      where H.type_obj = 'INIT'
       and to_date(H.date_aud) = (select max(to_date(date_aud)) from ~tblhist
                                  where to_date(date_aud) < trunc(sysdate))) H1
where H1.obj_name not in
(select H2.obj_name from ~tblhist H2
 where H2.type_obj = 'INIT'
 and trunc(to_date(H2.date_aud)) = trunc(sysdate))
order by 1;

prompt </td></tr></table>
prompt <br>

-- *************************************** NOMS
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Noms database et instance</b></font></td></tr>
select '<tr><td bgcolor="WHITE" width=20%>DB_NAME</td><td bgcolor="LIGHTBLUE">',name,'</td>','</tr>' from v$database;
select '<tr><td bgcolor="WHITE" width=20%>DB_UNIQUE_NAME</td><td bgcolor="LIGHTBLUE">',value,'</td>','</tr>' from v$parameter where name='db_unique_name';
select '<tr><td bgcolor="WHITE" width=20%>INSTANCE_NAME</td><td bgcolor="LIGHTBLUE">',instance_name,'</td>','</tr>' from v$instance;

prompt </table>
prompt <br>

-- *************************************** Informations Generales
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Informations g&eacute;n&eacute;rales</b></font></td></tr>
prompt <tr><td width=20%><b>Base cr&eacute;&eacute;e le</b></td>
prompt <td bgcolor="LIGHTBLUE">
select CREATED from v$database;
prompt </td></tr><tr>
prompt <td><b>Up depuis le</b> </td>
prompt <td bgcolor="LIGHTBLUE">
select STARTUP_TIME from v$instance;
prompt </td></tr><tr>
prompt <td><b>Taille de blocs</b></td>
prompt <td bgcolor="LIGHTBLUE">
prompt  ~dbloc octets
prompt </td></tr>
prompt <td><b>Type de processus SERVERS</b></td>
prompt <td bgcolor="LIGHTBLUE">
select decode(value, NULL, 'DEDICATED', 0, 'DEDICATED', 'SHARED:'||value) from v$parameter where name='shared_servers';
prompt </td></tr>
prompt <td><b>Recycle bin</b></td>
prompt <td bgcolor="LIGHTBLUE">
select value from v$parameter where name = 'recyclebin';
prompt </td></tr>
-- Archive log mode
prompt <tr><td width=20%><b>Archive log mode</b></td>
select decode(log_mode,'ARCHIVELOG','<td bgcolor="#33FF33">','<td bgcolor="#FF9900">'),log_mode,'<br>' from v$database;
prompt </td></tr>
prompt <tr><td width=20%><b>Archive log destination</b></td>

DECLARE
arch_mode number := 0;
cnt_dest number := 0;
BEGIN
   select decode(log_mode,'ARCHIVELOG',1,0) into arch_mode from v$database;
   select count(name) into cnt_dest from v$parameter
   where (name like 'log_archive_dest_%' or name = 'log_archive_dest') and name not like '%state%' and value is not NULL;
   if arch_mode=1 AND cnt_dest>0 then
      dbms_output.put_line('<td bgcolor="LIGHTBLUE">');
   end if;
   if arch_mode=1 AND cnt_dest=0 then
      dbms_output.put_line('<td bgcolor="ORANGE">Les ARCHIVE LOGS sont dans la flash_recovery_area ! A d&eacute;placer !');
   end if;
   if arch_mode=0 then
      dbms_output.put_line('<td bgcolor="LIGHTGREY">');
   end if;
end;
/
select distinct decode(d.log_mode,'ARCHIVELOG',p.name||' = '||p.value||'<br/>', '') from v$database d,v$parameter p where (p.name like 'log_archive_dest_%' or p.name = 'log_archive_dest') and p.name not like '%state%' and p.value is not NULL;
prompt </td></tr>

prompt <tr><td width=20%><b>Archive log format</b></td>
select decode(d.log_mode,'ARCHIVELOG','<td bgcolor="LIGHTBLUE">'||p.value||'<br/>', '<td bgcolor="LIGHTGREY">') from v$database d,v$parameter p where p.name like 'log_archive_format';
prompt </td></tr></table>
prompt <br>

DECLARE cnt_dest number := 0;
BEGIN
   select count(name) into cnt_dest from v$parameter
   where name like 'log_archive_format';
   if cnt_dest=0 then
      dbms_output.put_line('<td bgcolor="LIGHTGREY">');
   end if;
end;
/

-- *************************************** Flash recovery area
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="En cas de fort remplissage de la FRA, v&eacute;rifier le contenu par : SELECT * FROM V$RECOVERY_AREA_USAGE;">
prompt &nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Attention : supprimer sur disque les archives de la FRA ne suffit pas &agrave; r&eacute;cup&eacute;rer l'espace. La FRA est g&eacute;r&eacute;e logiquement. Il est n&eacute;cessaire d'ex&eacute;cuter ' CROSSCHECK ARCHIVELOG ALL; ' et ' DELETE EXPIRED ARCHIVELOG ALL; ' sous RMAN pour qu'Oracle lib&egrave;re l'espace."></td>
prompt <td bgcolor="#3399CC" align=center><font color="WHITE"><b>Informations Flash Recovery Area</b></font></td></tr></table></td></tr>
prompt <tr><td  bgcolor="WHITE" width=20%><b>Chemin</b></td><td><b>Espace totale</b></td></td><td><b>Espace utilis&eacute;</b></td></tr>

DECLARE
fra_cnt number := 0;
line varchar2(2000);
BEGIN
   select count(name) into fra_cnt from V$RECOVERY_FILE_DEST;
   if fra_cnt = 0 then
      dbms_output.put_line('<tr><td bgcolor="ORANGE" colspan=3 align=center>Flash recovery area d&eacute;sactiv&eacute;e');
   else
      SELECT '<tr><td bgcolor="LIGHTBLUE">'||name||'</td><td bgcolor="LIGHTBLUE" align=right>'||round(space_limit/1024/1024/1024,2)||' Go</td><td bgcolor="'||CouleurLimite(SPACE_USED,space_limit*0.80,space_limit*0.10,1)||'" align=right>'||round(SPACE_USED/1024/1024/1024,2)||'Go'
      into line
      FROM V$RECOVERY_FILE_DEST;
      dbms_output.put_line(line);
   end if;
end;
/
prompt </td></tr></table>
prompt <br>


-- *************************************** SECTION STOCKAGE
prompt <hr>
prompt <div align=center><b><font color="WHITE">SECTION STOCKAGE</font></b></div>
prompt <hr>

-- *************************************** MISE A JOUR TABLE HISTORIQUE (TABLESPACES ET SEGMENTS)
delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='TBS';
insert into ~tblhist (
select sysdate, 'TBS', t.tablespace_name, t.total, 
         decode(u.utilise,'',0,u.utilise), 0
from (select df.tablespace_name,
             round(sum(df.bytes)/(1024*1024),2) total
      from dba_data_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name
      and dt.contents not in ('UNDO')
      group by df.tablespace_name) t,
     (select tablespace_name,
             round(sum(blocks)*~dbloc/(1024*1024),2) utilise
      from dba_segments
      group by tablespace_name) u
where t.tablespace_name=u.tablespace_name(+)
UNION
select sysdate, 'TBS', tablespace_name, total, 
         0, 0
from (select df.tablespace_name,
             round(sum(df.bytes)/(1024*1024),2) total
      from dba_temp_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name
      and dt.contents in ('UNDO')
      group by df.tablespace_name)
UNION
select sysdate, 'TBS', tablespace_name, total, 
         0, 0
from (select tablespace_name,
             round(sum(bytes)/(1024*1024),2) total
      from dba_temp_files
      group by tablespace_name));

delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='FIL';
insert into ~tblhist (
select sysdate, 'FIL', file_name, 0, 0, 0
      from dba_data_files);
insert into ~tblhist (
select sysdate, 'FIL', file_name, 0, 0, 0
      from dba_temp_files);

delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='TAB';
insert into ~tblhist (
select sysdate, 'TAB', 'Total segments tables', total, 
         0, 0
from (select decode(round(sum(bytes)/(1024*1024),2),NULL,0,round(sum(bytes)/(1024*1024),2)) total
      from dba_segments
      where segment_type like 'TABLE%'
      and owner not in ~sysusers and owner not in ~exusers));
delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='IND';
insert into ~tblhist (
select sysdate, 'IND', 'Total segments indexes', total, 
         0, 0
from (select decode(round(sum(bytes)/(1024*1024),2),NULL,0,round(sum(bytes)/(1024*1024),2)) total
      from dba_segments
      where segment_type like 'INDEX%'
      and owner not in ~sysusers and owner not in ~exusers));
delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='AUT';
insert into ~tblhist (
select sysdate, 'AUT', 'Total segments autres', total, 
         0, 0
from (select decode(round(sum(bytes)/(1024*1024),2),NULL,0,round(sum(bytes)/(1024*1024),2)) total
      from dba_segments
      where segment_type not like 'TABLE%'
      and segment_type not like 'INDEX%'
      and owner not in ~sysusers and owner not in ~exusers));

-- *************************************** TABLESPACES
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>TABLESPACES</font></b></div>
prompt <hr>

-- *************************************** Liste datafiles

prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=6>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="Les nouveaux tablespaces et fichiers cr&eacute;&eacute;s depuis le dernier audit apparaissent en orange"></td>
prompt <td bgcolor="#3399CC" align=center><font color="WHITE"><b>Liste des datafiles par tablespace</b></font></td></tr></table></td></tr>
prompt <tr><td><b>Tablespace</b></td><td><b>Fichier</b></td><td><b>Taille (Mo)</b></td><td><b>Autoext.</b></td><td><b>Next</b></td><td><b>MaxSize</b></td></tr>

WITH list_tbs AS (
select distinct OBJ_NAME,TYPE_OBJ from ~tblhist
where type_obj in ('TBS','FIL')
and to_date(date_aud) like (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
                            where to_date(date_aud) < trunc(sysdate))
)
select '<tr>','<td bgcolor="'||CASE WHEN df.TABLESPACE_NAME NOT IN (select list_tbs.obj_name from list_tbs where list_tbs.type_obj='TBS') and dt.contents NOT IN ('UNDO') THEN 'ORANGE' ELSE 'LIGHTBLUE' END||'">'||CASE WHEN df.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_PERMANENT_TABLESPACE') THEN '<b>' END||df.TABLESPACE_NAME||CASE WHEN df.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_PERMANENT_TABLESPACE') THEN ' </b><i>(default tbs)</i>' END||'</td>' as tbs,
 '<td bgcolor="'||CASE WHEN df.FILE_NAME NOT IN (select list_tbs.obj_name from list_tbs where type_obj='FIL') THEN 'ORANGE' ELSE 'LIGHTBLUE' END||'">'||df.FILE_NAME||'</td>' as fname,
 '<td bgcolor="'||decode (CONTENTS,'UNDO','#33FF33',decode(autoextensible,'NO','#33FF33',CouleurLimite(sum(df.blocks)*~dbloc,(sum(df.maxbytes)-(sum(df.maxbytes)*0.20)),(sum(df.maxbytes)-(sum(df.maxbytes)*0.20))*0.10,1)))||'" align=right>'||decode(round(sum(df.bytes)/(1024*1024),2),NULL,to_char('0','S99G999G990D00'),to_char(round(sum(df.bytes)/(1024*1024),2),'99G999G990D00'))||'</td>' as taille,
 decode(autoextensible,'NO','<td bgcolor="#FF9900" align=right>OFF</td>','<td bgcolor="#33FF33" align=right>ON</td>') as autoext,
 '<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(sum(increment_by)*~dbloc/(1024*1024),2),'99G999G990')||'</td>' as nsize,
-- maxbytes always in bytes even if bigfile ?
 '<td bgcolor="LIGHTBLUE" align=right>'||to_char(decode(BIGFILE,'YES',round(sum(df.maxbytes)/(1024*1024),2),round(sum(df.maxbytes)/(1024*1024),2)),'99G999G990')||'</td>' as msize, '</tr>'
from DBA_DATA_FILES df, DBA_TABLESPACES dt
where df.tablespace_name=dt.tablespace_name(+)
group by df.tablespace_name, df.file_name, autoextensible, contents, bigfile
order by 2,3;
WITH list_tbs AS (
select distinct OBJ_NAME,TYPE_OBJ from ~tblhist
where type_obj in ('TBS','FIL')
and to_date(date_aud) like (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
                            where to_date(date_aud) < trunc(sysdate))
)
select '<tr>','<td bgcolor="'||CASE WHEN df.TABLESPACE_NAME NOT IN (select list_tbs.obj_name from list_tbs where list_tbs.type_obj='TBS') THEN 'ORANGE' ELSE 'LIGHTBLUE' END||'">'||CASE WHEN df.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_TEMP_TABLESPACE') THEN '<b>' END||df.TABLESPACE_NAME||CASE WHEN df.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_TEMP_TABLESPACE') THEN ' </b><i>(default tmp)</i>' END||'</td>' as tbs,
 '<td bgcolor="'||CASE WHEN FILE_NAME NOT IN (select list_tbs.obj_name from list_tbs where type_obj='FIL') THEN 'ORANGE' ELSE 'LIGHTBLUE' END||'">'||FILE_NAME||'</td>' as fname,
 '<td bgcolor="#33FF33" align=right>'||decode(round(sum(df.blocks)*~dbloc/(1024*1024),2),NULL,to_char('0','S99G999G990D00'),to_char(round(sum(df.blocks)*~dbloc/(1024*1024),2),'99G999G990D00'))||'</td>' as taille,
 decode(autoextensible,'NO','<td bgcolor="#FF9900" align=right>OFF</td>', '<td bgcolor="#33FF33" align=right>ON</td>')as autoext,
 '<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(sum(increment_by)*~dbloc/(1024*1024),2),'99G999G990')||'</td>' as nsize,
-- maxbytes always in bytes even if bigfile ?
-- '<td bgcolor="LIGHTBLUE" align=right>'||to_char(decode(BIGFILE,'YES',round(sum(df.maxbytes)/(1024*1024),2),round(sum(df.maxbytes)/(1024*1024),2)),'99G999G990')||'</td>' as msize, '</tr>'
'<td bgcolor="LIGHTBLUE" align=right>'||to_char(decode(BIGFILE,'YES',round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2),round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2)),'99G999G990')||'</td>' as msize, '</tr>'
from DBA_TEMP_FILES df, DBA_TABLESPACES dt
where df.tablespace_name=dt.tablespace_name(+)
group by df.tablespace_name,df.file_name, autoextensible, bigfile
order by 2,3;

prompt </table><br>

-- *************************************** Volumétrie tablespaces
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=10>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="Les nouveaux tablespaces cr&eacute;&eacute;s depuis le dernier audit apparaissent en orange"></td>
prompt <td align=center><font color="WHITE"><b>Volum&eacute;trie actuelle + diff&eacute;rence de tailles depuis le dernier audit (
print last_audit
prompt )</b></font></td></tr></table></td></tr>

prompt <tr><td><b>Tablespace</b></td><td><b>Bigfile</b></td><td><b>Contenu</b></td><td><b>Statut</b></td><td width=13%><b>Taille max. totale (Mo) avec autoextend</b></td><td width=10%><b>Total actuel (Mo) sur disque</b></td><td width=10%><b>Utilis&eacute; (Mo)</b></td><td width=10%><b>Libre actuel/taille max. totale</b></td><td width=10%><b>Total sur disque depuis dernier audit (Mo)</b></td><td width=10%><b>Utilis&eacute; depuis dernier audit (Mo)</b></td></tr>

-- TABLESPACES DATAS
WITH list_tbs AS (
select distinct OBJ_NAME from ~tblhist where type_obj='TBS' and to_date(date_aud) like (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
      where to_date(date_aud) < trunc(sysdate))
)
select '<tr>','<td bgcolor="'||CASE WHEN t.TABLESPACE_NAME NOT IN (select list_tbs.obj_name from list_tbs) THEN 'ORANGE' ELSE 'LIGHTBLUE' END||'">',CASE WHEN t.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_PERMANENT_TABLESPACE') THEN '<b>' END,t.tablespace_name,CASE WHEN t.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_PERMANENT_TABLESPACE') THEN ' </b><i>(default tbs)</i>' END,'</td>', '<td bgcolor="',decode(BIGFILE,'YES','BLUE','LIGHTBLUE'),'" align=center>', '<font color="',decode (BIGFILE,'YES','WHITE','BLACK'),'">', maxt.bigfile,'</font></td>', '<td bgcolor="LIGHTBLUE">',maxt.contents,'</td>', decode(maxt.status,'ONLINE','<td bgcolor="LIGHTBLUE">','<td bgcolor="#FF0000">'),maxt.status,'</td>',
--       '<td bgcolor="LIGHTBLUE" align=right>',decode(t.autoextensible,'NO',decode(t.total,'',to_char(round(l.libre,0),'99G999G990D00'),to_char(t.total,'99G999G990D00')),decode(maxt.maxtotal,'',to_char(round(l.libre,0),'99G999G990D00'),to_char(maxt.maxtotal,'99G999G990D00'))),'</td>' TOTAL,
       '<td bgcolor="LIGHTBLUE" align=right>',to_char(maxt.maxtotal,'99G999G990D00'),'</td>' TOTAL,
       '<td bgcolor="LIGHTBLUE" align=right>',decode(t.total,'',to_char(round(l.libre,0),'99G999G990D00'),to_char(t.total,'99G999G990D00')),'</td>' TOTAL_CURRENT,
       '<td bgcolor="LIGHTBLUE" align=right>',decode(u.utilise,'','0,00',to_char(u.utilise,'99G999G990D00')),'</td>' UTILISE,
--       '<td bgcolor="',decode(t.autoextensible,'NO',decode(u.utilise,'', '#33FF33',CouleurLimite(u.utilise,t.total-(t.total*0.20),t.total*0.10,1)),decode(u.utilise,'', '#33FF33', CouleurLimite(u.utilise,maxt.maxtotal-(maxt.maxtotal*0.20),maxt.maxtotal*0.10,1))),'" align=right>',decode(t.autoextensible,'NO',to_char(l.libre,'99G999G990D00'),to_char(maxt.maxtotal-(decode(u.utilise,'',0,u.utilise)),'99G999G990D00')),'</td>' LIBRE,
       '<td bgcolor="',decode(u.utilise,'', '#33FF33', CouleurLimite(u.utilise,maxt.maxtotal-(maxt.maxtotal*0.20),maxt.maxtotal*0.10,1)),'" align=right>',to_char(maxt.maxtotal-(decode(u.utilise,'',0,u.utilise)),'99G999G990D00'),'</td>' LIBRE,
decode(SIGN(a.total-h.total),
      -1,'<td bgcolor="#33FF33" align=right>'||to_char(a.total-h.total,'S99G999G990D00')||'</td>',
       0,'<td bgcolor="LIGHTBLUE" align=right >'||to_char(a.total-h.total,'99G999G990D00')||'</td>',
       1,'<td bgcolor="ORANGE" align=right>'||to_char(a.total-h.total,'S99G999G990D00')||'</td>',
       NULL,'<td bgcolor="LIGHTGREY" align=right >Premier audit</td>'),
decode(SIGN(a.utilis-h.utilis),
      -1,'<td bgcolor="#33FF33" align=right >'||to_char(a.utilis-h.utilis,'S99G999G990D00')||'</td>',
       0,'<td bgcolor="LIGHTBLUE" align=right>'||to_char(a.utilis-h.utilis,'99G999G990D00')||'</td>',
       1,'<td bgcolor="ORANGE" align=right>'||to_char(a.utilis-h.utilis,'S99G999G990D00')||'</td>',
       NULL,'<td bgcolor="LIGHTGREY" align=right>Premier audit</td>'),'</tr>'
from (select tablespace_name,
             round(sum(bytes)/(1024*1024),2) total
      from dba_data_files
      group by tablespace_name) t,
-- dba_free_space ne s'occupe pas de l'autoextent, il ne calcule que par rapport à la place occupée actuellement sur disque
-- pour calculer plutôt par rapport au max autoextent, on affiche le résultat de (maxt - utilise)
     (select df.tablespace_name, dt.contents, dt.status,
             bigfile,
--             decode(BIGFILE,'YES',round(sum(df.maxbytes)/(1024*1024*1024),2),round(sum(df.maxbytes)/(1024*1024),2)) maxtotal
            decode(BIGFILE,'YES',round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2),round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2)) maxtotal
      from dba_data_files df, dba_tablespaces dt
      where df.tablespace_name=dt.tablespace_name(+)
      group by df.tablespace_name, dt.contents, dt.status, BIGFILE) maxt,
     (select tablespace_name,
             round(sum(blocks)*~dbloc/(1024*1024),2) utilise
      from dba_segments
      group by tablespace_name) u,
     (select tablespace_name,
             round(sum(blocks)*~dbloc/(1024*1024),2) libre
      from dba_free_space
      group by tablespace_name) l,
      (select * from ~tblhist
         where trunc(to_date(date_aud))=trunc(sysdate)
         and type_obj='TBS') a,
      (select * from ~tblhist
         where to_date(date_aud) like
        (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
            where to_date(date_aud) like (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
      where to_date(date_aud) < trunc(sysdate))
            and type_obj='TBS')
         and type_obj='TBS') h
where t.tablespace_name=u.tablespace_name(+)
and u.tablespace_name=l.tablespace_name(+)
and t.tablespace_name=maxt.tablespace_name(+)
and a.obj_name=h.obj_name(+)
and a.obj_name=t.tablespace_name
and maxt.contents not in ('UNDO')
order by t.tablespace_name;

-- TABLESPACE UNDO
select '<tr>','<td bgcolor="LIGHTBLUE">',t.tablespace_name,'</td>' Tablespace, '<td bgcolor="',decode(BIGFILE,'YES','#FF9900','LIGHTBLUE'),'" align=center>',maxt.bigfile,'</td>', '<td bgcolor="LIGHTBLUE">',maxt.contents,'</td>', decode(maxt.status,'ONLINE','<td bgcolor="LIGHTBLUE">',maxt.status,'</td>','<td bgcolor="#FF0000">',maxt.status,'</td>'),
       '<td bgcolor="LIGHTBLUE" align=right>',decode(t.autoextensible,'NO',decode(t.total,'',to_char(round(l.libre,0),'99G999G990D00'),to_char(t.total,'99G999G990D00')),decode(maxt.maxtotal,'',to_char(round(l.libre,0),'99G999G990D00'),to_char(maxt.maxtotal,'99G999G990D00'))),'</td>' TOTAL,
       '<td bgcolor="LIGHTBLUE" align=right>',decode(t.total,'',to_char(round(l.libre,0),'99G999G990D00'),to_char(t.total,'99G999G990D00')),'</td>' TOTAL_CURRENT,
       '<td bgcolor="LIGHTBLUE" align=right>',decode(u.utilise,'','0,00',to_char(u.utilise,'99G999G990D00')),'</td>' UTILISE,
       '<td bgcolor="LIGHTBLUE" align=right>',decode(t.autoextensible,'NO',to_char(l.libre,'99G999G990D00'),to_char(maxt.maxtotal-(decode(u.utilise,'',0,u.utilise)),'99G999G990D00')),'</td>' LIBRE,'<td bgcolor="LIGHTGREY" align=center><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor="LIGHTGREY" align=center></td></tr>'
from (select tablespace_name, autoextensible,
             round(sum(bytes)/(1024*1024),2) total
      from dba_data_files
      group by tablespace_name, autoextensible) t,
     (select df.tablespace_name, df.autoextensible, dt.contents, dt.status,
             bigfile,
             decode(BIGFILE,'YES',round(sum(df.maxbytes)/(1024*1024*1024),2),round(sum(df.maxbytes)/(1024*1024),2)) maxtotal
      from dba_data_files df, dba_tablespaces dt
      where df.tablespace_name=dt.tablespace_name(+)
      group by df.tablespace_name, df.autoextensible, dt.contents, dt.status, BIGFILE) maxt,
     (select tablespace_name,
             round(sum(blocks)*~dbloc/(1024*1024),2) utilise
      from dba_segments
      group by tablespace_name) u,
     (select tablespace_name,
             round(sum(blocks)*~dbloc/(1024*1024),2) libre
      from dba_free_space
      group by tablespace_name) l
where t.tablespace_name=u.tablespace_name(+)
and u.tablespace_name=l.tablespace_name(+)
and t.tablespace_name=maxt.tablespace_name(+)
and maxt.contents in ('UNDO');

-- TABLESPACE TEMP
select '<tr>','<td bgcolor="LIGHTBLUE">',CASE WHEN ty.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_TEMP_TABLESPACE') THEN '<b>' END,ty.tablespace_name,CASE WHEN ty.TABLESPACE_NAME IN (select DISTINCT PROPERTY_VALUE from DATABASE_PROPERTIES where PROPERTY_NAME = 'DEFAULT_TEMP_TABLESPACE') THEN ' </b><i>(default tmp)</i>' END,'</td>','<td bgcolor="',decode(ty.bigfile,'YES','BLUE"','LIGHTBLUE"'),' align=center>','<font color="',decode(ty.bigfile,'YES','WHITE">','BLACK">'),ty.bigfile,'</font></td>', '<td bgcolor="LIGHTBLUE">',ty.contents,'</td>', decode(ty.status,'ONLINE','<td bgcolor="LIGHTBLUE">',ty.status,'</td>','<td bgcolor="#FF0000">',ty.status,'</td>'),
         '<td bgcolor="LIGHTBLUE" align=right>',to_char(ty.maxtotal,'99G999G990D00'),'</td>' as maxtotal, 
         '<td bgcolor="LIGHTBLUE" align=right>',to_char(ty.total,'99G999G990D00'),'</td>' as total, 
         '<td bgcolor="LIGHTBLUE" align=right>0,00</td>' as utilise,
         '<td bgcolor="LIGHTBLUE" align=right>',to_char(ty.total,'99G999G990D00'),'</td>' as libre,'<td bgcolor="LIGHTGREY" align=center><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor="LIGHTGREY" align=center></td></tr>'
from (select df.tablespace_name, dt.contents, dt.status,dt.bigfile,
--             round(sum(bytes)/(1024*1024),2) total
      decode(dt.bigfile,'YES',
        round(sum(case when df.maxbytes=0 then (bytes/(1024*1024*1024)) else (df.maxbytes/(1024*1024*1024)) end),2),
        round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2)) maxtotal,
      decode(dt.bigfile,'YES',
        round(sum(bytes/(1024*1024*1024)),2),
        round(sum(bytes/(1024*1024)),2)) total
      from dba_temp_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name
      group by df.tablespace_name, dt.contents, dt.status,dt.bigfile) ty;

-- TOTAUX
select  '<tr>','<td bgcolor="WHITE" colspan=4>TOTAL</td>',
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',to_char(decode(dmty.total,'',0,dmty.total)+decode(dmtn.total,'',0,dmtn.total)+(tmty.total+tmtn.total),'99G999G990D00'),'</b></font></td>' as maxtotal, 
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',to_char(dt.total+tty.total+ttn.total,'99G999G990D00'),'</b></font></td>' as total, 
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',to_char(du.utilise+tu.utilise,'99G999G990D00'),'</b></font></td>' as utilise,
--        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',to_char(dl.libre+tl.libre,'99G999G990D00'),'</b></font></td>' as libre
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',to_char(decode(dmty.total,'',0,dmty.total)+decode(dmtn.total,'',0,dmtn.total)+(tty.total+ttn.total)-(du.utilise+tu.utilise),'99G999G990D00'),'</b></font></td>' as libre
from
--(select round(sum(df.maxbytes)/(1024*1024*1024),2) total
(select round(sum(case when df.maxbytes=0 then (bytes/(1024*1024*1024)) else (df.maxbytes/(1024*1024*1024)) end),2) total
      from dba_data_files df, dba_tablespaces dt
      where df.tablespace_name=dt.tablespace_name(+)
      and BIGFILE='YES'
--      and dt.contents not in ('UNDO')
) dmty,
--     (select round(sum(df.maxbytes)/(1024*1024),2) total
(select round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2) total
      from dba_data_files df, dba_tablespaces dt
      where df.tablespace_name=dt.tablespace_name(+)
      and BIGFILE='NO'
--      and dt.contents not in ('UNDO')
) dmtn,
--     (select round(sum(bytes)/(1024*1024),2) total from dba_data_files where autoextensible='NO') nadt,
     (select round(sum(bytes)/(1024*1024),2) total from dba_data_files) dt,
--     (select round(sum(bytes)/(1024*1024),2) total from dba_temp_files) tt,
--     (select round(sum(case when maxbytes=0 then (bytes/(1024*1024)) else (maxbytes/(1024*1024)) end),2) total from dba_temp_files) tt,
(select NVL(round(sum(case when df.maxbytes=0 then (bytes/(1024*1024*1024)) else (df.maxbytes/(1024*1024*1024)) end),2),0) total
      from dba_temp_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name and dt.bigfile='YES') tmty,
(select NVL(round(sum(case when df.maxbytes=0 then (bytes/(1024*1024)) else (df.maxbytes/(1024*1024)) end),2),0) total
      from dba_temp_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name and dt.bigfile='NO') tmtn,
(select NVL(round(sum(bytes/(1024*1024*1024)),2),0) total
      from dba_temp_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name and dt.bigfile='YES') tty,
(select NVL(round(sum(bytes/(1024*1024)),2),0) total
      from dba_temp_files df, dba_tablespaces dt
      where df.tablespace_name = dt.tablespace_name and dt.bigfile='NO') ttn,
     (select round(sum(blocks)*~dbloc/(1024*1024),2) utilise from dba_segments) du,
     (select 0 utilise from dual) tu, -- considere que temp est toujours 100% libre
     (select round(sum(blocks)*~dbloc/(1024*1024),2) libre from dba_free_space) dl,
     (select round(sum(bytes)/(1024*1024),2) libre from dba_temp_files) tl;
     
select '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',to_char(round(sum(a.total-h.total)),'S99G999G990D00'),'</b></font></td>' as total, 
        '<td bgcolor="BLUE" align=right colspan=4><font color="WHITE"><b>',to_char(round(sum(a.utilis-h.utilis)),'S99G999G990D00'),'</b></font></td>' as utilise,'</tr>'
from (select * from ~tblhist
	where trunc(to_date(date_aud))=trunc(sysdate)
        and type_obj='TBS') a,
(select * from ~tblhist
	where to_date(date_aud) like
	(select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
                where to_date(date_aud) < trunc(sysdate)
                and type_obj='TBS')
	and type_obj='TBS') h
where a.obj_name=h.obj_name;

prompt </table><br>

-- TABLESPACE(S) SUPPRIME(S)

DECLARE
 tbsremoved_cnt number := 0;
 v_cur SYS_REFCURSOR;
 v_res varchar2(255);
 v_sql varchar2(2000);
BEGIN
   select count(OBJ_NAME) into tbsremoved_cnt from ~tblhist
     where type_obj='TBS' and to_date(date_aud) like (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist where to_date(date_aud) < trunc(sysdate))
     and OBJ_NAME not in (select tablespace_name from dba_tablespaces);
   if tbsremoved_cnt > 0 then
     v_sql := 'SELECT ''<tr><td bgcolor="ORANGE">''||OBJ_NAME||''</td></tr>''
      FROM ~tblhist
        where type_obj=''TBS'' and to_date(date_aud) like (select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist where to_date(date_aud) < trunc(sysdate))
      and OBJ_NAME not in (select tablespace_name from dba_tablespaces) ';
     dbms_output.put_line('<table border=1 width=100% bgcolor="WHITE"><tr><td bgcolor="#3399CC" align=center><font color="WHITE"><b>Tablespace(s) supprim&eacute;(s) depuis le dernier audit</b></font></td></tr>');
     open v_cur for v_sql;
     loop
       fetch v_cur into v_res;
       EXIT WHEN v_cur%NOTFOUND;
       dbms_output.put_line(v_res);
     end loop;
     dbms_output.put_line('</table><br>');
   end if;
END;
/

-- *************************************** SEGMENTS
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>SEGMENTS (Objets utilisateurs)</font></b></div>
prompt <hr>

-- *************************************** Volumétrie tables et indexes
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Volum&eacute;trie segments utilisateurs</b></font></td></tr>
prompt <tr><td><b>Type de segments</b></td><td><b>Total (Mo)</b></td><td><b>Diff&eacute;rence de taille depuis le dernier audit (
print last_audit
prompt )</b></td></tr>

select  '<tr>','<td bgcolor="LIGHTBLUE">TABLES</td>',
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',decode(a.total, NULL, '0,00', to_char(round(a.total,2),'99G999G990D00')),'</b></font></td>',
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',decode(a.total, NULL, to_char(round(-l.total,2),'S99G999G990D00'), to_char(round(a.total-l.total,2),'S99G999G990D00')),'</b></font></td>','</tr>'
from (select round(sum(bytes)/(1024*1024),2) as total from dba_segments
	where segment_type like 'TABLE%'
        and owner not in ~sysusers and owner not in ~exusers) a,
(select * from ~tblhist
	where to_date(date_aud) like
	(select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
                where to_date(date_aud) < trunc(sysdate)
                and type_obj='TAB')
	and type_obj='TAB') l;
select  '<tr>','<td bgcolor="LIGHTBLUE">INDEXES</td>',
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',decode(a.total, NULL, '0,00', to_char(round(a.total,2),'99G999G990D00')),'</b></font></td>', 
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',decode(a.total, NULL, to_char(round(-l.total,2),'S99G999G990D00'), to_char(round(a.total-l.total,2),'S99G999G990D00')),'</b></font></td>','</tr>'
from (select round(sum(bytes)/(1024*1024),2) as total from dba_segments
	where segment_type like 'INDEX%'
        and owner not in ~sysusers and owner not in ~exusers) a,
(select * from ~tblhist
	where to_date(date_aud) like
	(select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
                where to_date(date_aud) < trunc(sysdate)
                and type_obj='IND')
	and type_obj='IND') l;
select DISTINCT '<tr>','<td bgcolor="LIGHTBLUE">AUTRES (LOB SEGMENTS, LOB INDEXES, CLUSTERS,...)</td>',
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',decode(a.total, NULL, '0,00', to_char(round(a.total,2),'99G999G990D00')),'</b></font></td>', 
        '<td bgcolor="BLUE" align=right><font color="WHITE"><b>',decode(a.total, NULL, to_char(round(-l.total,2),'S99G999G990D00'), to_char(round(a.total-l.total,2),'S99G999G990D00')),'</b></font></td>','</tr>'
from (select round(sum(bytes)/(1024*1024),2) as total from dba_segments
	where segment_type not like 'TABLE%' and segment_type not like 'INDEX%'
        and owner not in ~sysusers and owner not in ~exusers) a,
(select * from ~tblhist
	where to_date(date_aud) like
	(select decode(max(to_date(date_aud)),NULL,trunc(sysdate),max(to_date(date_aud))) from ~tblhist
                where trunc(to_date(date_aud)) < trunc(sysdate)
                and type_obj='AUT')
	and type_obj='AUT') l;

prompt </table><br>

-- *************************************** REDO LOG FILES
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>REDO LOG FILES</font></b></div>
prompt <hr>
-- *************************************** Redo logs files
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Liste des fichiers redo logs</b></font></td></tr>
prompt <tr><td width=8%><b>Groupe</b></td><td width=25%><b>Fichier</b></td><td width=5%><b>Statut</b></td><td width=15%><b>Taille (Mo)</b></td></tr>
select '<tr>','<td bgcolor="LIGHTBLUE">', l.group#, '</td>', '<td bgcolor="LIGHTBLUE">', member, '</td>', '<td bgcolor="',decode(f.status, 'STALE', 'ORANGE">', 'INVALID', '#FF0000">', '#33FF33">OK'),f.status,'</td>','<td bgcolor="LIGHTBLUE" align=right>',to_char(round(bytes/(1024*1024),2),'99G999G990D00'),'</td>','</tr>' from v$log l,v$logfile f where l.group# = f.group# order by l.group#;

prompt </table><br>

-- *************************************** Statistiques switchs REDO LOG
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=3>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="ATTENTION : l&#39;historique des logs peut &ecirc;tre supprim&eacute; au fur et &agrave; mesure : ces statistiques risquent de ne pas &ecirc;tre viables."></td>
prompt <td align=center><font color="WHITE"><b>Statistiques switchs REDO LOGS</b></font></td></tr></table></td></tr>

prompt <tr><td width=15%><b>Statistique</b></td><td width=15%><b>Date</b></td><td width=15%><b>Valeur</b></td></tr>
prompt <tr><td bgcolor="LIGHTBLUE" valign=top>Nombre de switchs par jour (depuis 30 jours)</td>
prompt <td bgcolor="LIGHTBLUE" align=right>
select trunc(first_time),'<br/>' from v$loghist
where first_time > (sysdate-30)
group by trunc(first_time)
order by trunc(first_time);
prompt </td><td bgcolor="LIGHTBLUE" align=right>
select count(first_time),'<br/>' from v$loghist
where first_time > (sysdate-30)
group by trunc(first_time)
order by trunc(first_time);
prompt </td></tr>

-- *************************************** Stats switchs
select '<tr>','<td bgcolor="WHITE">Moyenne par jour :</td>', '<td bgcolor="BLUE" align=right colspan=2><font color="WHITE"><b>',round(avg(nbc),0),'</font></b></td>','</tr>'
from (select count(*) as nbc from v$loghist a, v$loghist b
      where a.first_change#=b.switch_change#
      and to_char(a.first_time,'dd/mm/yyyy')=to_char(b.first_time,'dd/mm/yyyy')
      group by to_char(a.first_time,'dd/mm/yyyy'));

-- *************************************** resume par mois (depuis 1 an)
prompt <tr><td bgcolor="LIGHTBLUE">Nombre de switchs par mois</td>
prompt <td bgcolor="LIGHTBLUE" align=right>
select to_char(to_date(first_time),'mm/yyyy'),'<br/>' from v$loghist
where first_time > (sysdate-365)
group by to_char(to_date(first_time),'mm/yyyy')
order by to_char(to_date(first_time),'mm/yyyy');
prompt <td bgcolor="LIGHTBLUE" align=right>
select count(*),'<br/>' from v$loghist
where first_time > (sysdate-365)
group by to_char(to_date(first_time),'mm/yyyy')
order by to_char(to_date(first_time),'mm/yyyy');
prompt </td></tr>

-- *************************************** temps minimum entre 2 switchs
select '<tr>','<td bgcolor="WHITE">Temps MIN. entre 2 switchs :</td>', '<td bgcolor="BLUE" align=right colspan=2><font color="WHITE">',to_char(min(a.first_time-b.first_time)*24*3600,'99999G990'),' secondes</td>','</tr>'
from v$loghist a, v$loghist b
where a.first_change#=b.switch_change#;

-- *************************************** temps maximum entre 2 switchs
select '<tr>','<td bgcolor="WHITE">Temps MAX. entre 2 switchs :</td>', '<td bgcolor="BLUE" align=right colspan=2><font color="WHITE">',to_char(max(a.first_time-b.first_time)*24*3600,'99999G990'),' secondes</td>','</tr>'
from v$loghist a, v$loghist b
where a.first_change#=b.switch_change#;

-- *************************************** temps moyen entre 2 switchs
select '<tr>','<td bgcolor="WHITE">Temps MOY. entre 2 switchs :</td>', '<td bgcolor="BLUE" align=right colspan=2><font color="WHITE">',to_char((sum(a.first_time-b.first_time)*24*3600)/count(a.first_time),'99999G990'),' secondes</td>','</tr>'
from v$loghist a, v$loghist b
where a.first_change#=b.switch_change#;

prompt </table><br>

-- *************************************** UNDO (deprecated)
-- prompt <hr>
-- prompt <div align=center><b><font color="WHITE" size=2>UNDO / ROLLBACK SEGMENTS</font></b></div>
-- prompt <hr>
-- *************************************** Rollback segments -- inutile depuis 10g gestion auto
--prompt <table border=1 width=100% bgcolor="WHITE">
--prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Rollback segments</b></font></td></tr>
--prompt <tr><td width=8%><b>Segment</b></td><td width=25%><b>Tablespace</b></td><td width=15%><b>Statut</b></td></tr>
--select '<tr>','<td bgcolor="LIGHTBLUE">',segment_name,'</td>', '<td bgcolor="LIGHTBLUE">',tablespace_name,'</td>','<td bgcolor="LIGHTBLUE">',status,'</td>','</tr>' from dba_rollback_segs;

--prompt </table><br>

-- *************************************** Stats rollback segs (deprecated)
--prompt <table border=1 width=100% bgcolor="WHITE">
--prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Statistiques rollback segments</b></font></td></tr>
--prompt <tr><td width=15%><b>Segment USN</b></td><td width=15%><b>Nom</b></td><td width=15%><b>Nombre SHRINKS</b></td><td width=15%><b>taille moyenne SHRINKS</b></td></tr>
--select '<tr>','<td bgcolor="LIGHTBLUE">',v$rollstat.usn,'</td>','<td bgcolor="LIGHTBLUE">',name,'</td>','<td bgcolor="LIGHTBLUE" align=right>',shrinks,'</td>','<td bgcolor="LIGHTBLUE" align=right>',aveshrink,'</td>','</tr>' from v$rollstat,v$rollname
--where v$rollstat.usn=v$rollname.usn;

--prompt </table><br>

-- *************************************** CONFLITS D'ACCES
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>STATISTIQUES D&#39;ACCES DISQUE</font></b></div>
prompt <hr>

-- *************************************** contentions de basculement
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=4>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="&#39;Checkpoint not complete&#39; : ce message apparait si le check point pr&eacute;c&eacute;dent n&#39;est pas fini lors d&#39;un CPKT ou d&#39;un switch (qui occasionne lui-m&ecirc;me un ckpt). Augmenter la taille des fichiers redo logs, ou leur nombre si &ccedil;a ne suffit pas.">
prompt &nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Info..." title="voir messages 'Checkpoint not complete' dans le fichier alert<SID>.log"></td>
prompt <td align=center><font color="WHITE"><b>Contentions de basculement redo logs</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Ev&egrave;nement</b></td><td width=15%><b>Wait (en secondes)</b></td><td width=15%><b>Etat</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',sid,'</td>','<td bgcolor="LIGHTBLUE">',event,'</td>','<td bgcolor="LIGHTBLUE">',seconds_in_wait,'</td>','<td bgcolor="LIGHTBLUE">',state,'</td>','</tr>'
from v$session_wait
where event like 'log%';

DECLARE cnt_event number := 0;
BEGIN
   select count(sid) into cnt_event from v$session_wait
   where event like 'log%';
   if cnt_event=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** Conflits d'acces disque
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Tips..." title="ATTENTION : ces valeurs sont cumul&eacute;es depuis le dernier d&eacute;marrage.">
prompt &nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Si data block > 0 (trop de blocs modifi&eacute;s dans le buffer cache) augmenter le nombre de processus DBWR. Si segment header ou free list > 0 (multiplier les freelists en re-cr&eacute;ant la table avec nouveau param&egrave;tre). Si un des param&egrave;tres UNDO est sup&eacute;rieur &agrave; 1% ou 2% besoin de plus de rollback segments."></td>
prompt <td align=center><font color="WHITE"><b>Conflits d&#39;acc&egrave;s disque</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>
prompt <tr><td width=15%><b>Classe</b></td><td width=15%><b>Nombre</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',class,'</td>','<td bgcolor="',CouleurLimite(count,10000000,9990000,1),'" align=right>',count,'</td>','</tr>' from v$waitstat;

prompt </table><br>

-- *************************************** FULL SCANS
-- if a read request causes a large multiblock read on disk, it can mean that it is doing a full scan read
-- so : if phyblkrd (blocks) is much greater than phyrds (read requests), this can be due to full scans
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="La d&eacute;tection des FULL SCANS est faite par le rapport entre les demandes de lecture et les chargements des donn&eacute;es du disque (les blocs). Un ratio > 50% signifie qu&#39;un petit nombre de demandes chargent un grand nombre de blocs, ce qui indique que les tables sont lus en entier trop fr&eacute;quemment."></td>

prompt <td align=center><font color="WHITE"><b>D&eacute;tection des FULL SCANs</b></font></td></tr></table></td></tr>
prompt <tr><td><b>Tablespace</b></td><td><b>Fichier</b></td><td><b>Read requests</b></td><td><b>Blocks read</b></td><td><b>ratio (% de full scans)</b></td></tr>

select
'<tr>','<td bgcolor="LIGHTBLUE">',f.tablespace_name,'</td>',
'<td bgcolor="LIGHTBLUE">',f.file_name,'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',v.phyrds,'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',v.phyblkrd,'</td>',
'<td bgcolor="',CouleurLimite(ROUND(100*(1-(v.phyrds/greatest(v.phyblkrd,1))),0),50,5,1),'" align=right>',ROUND(100*(1-(v.phyrds/greatest(v.phyblkrd,1))),0),'%</td>',
'</tr>'
from DBA_data_files f, DBA_tablespaces t, v$filestat v
where f.file_id=v.file#
and f.tablespace_name=t.tablespace_name
and f.tablespace_name not in ('SYSTEM','SYSAUX')
and t.contents <> 'UNDO'
ORDER BY f.tablespace_name,v.file#;

prompt </table><br>

--TIPS : Pour trouver les tables souvent lues s&eacute;quentiellement (connexion SYS obligatoire ?) :
--set head on
--set pages 0
--col object_name format a40
--col object_type format a15
--col owner format a15 
--SELECT o.object_name, o.object_type, o.owner
--FROM dba_objects o,x$bh x
--WHERE x.obj=o.object_id
--AND o.object_type='TABLE'
--AND sys.standard.bitand(x.flag,524288)>0
--AND o.owner<>'SYS'
--GROUP BY o.object_name,o.object_type,o.owner;

-- *************************************** Evenements systemes
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Ev&eacute;nements syst&egrave;me</b></font></td></tr>
prompt <tr><td><b>Evenement</b></td><td><b>Total waits</b></td><td><b>Timeout</b></td><td><b>Average time</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',event,'</td>','<td bgcolor="LIGHTBLUE" align=right>',total_waits,'</td>','<td bgcolor="',decode(total_timeouts,0,'LIGHTBLUE','ORANGE'),'" align=right>',total_timeouts,'</td>','<td bgcolor="LIGHTBLUE" align=right>',to_char(average_wait,'999999990D00'),'</td>','</tr>' from v$system_event
where event like 'log%' or event like 'db file%';

prompt </table><br>

-- *************************************** SECTION INSTANCE
prompt <hr>
prompt <div align=center><b><font color="WHITE">SECTION INSTANCE</font></b></div>
prompt <hr>
-- *************************************** Jobs scheduler

prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="les jobs 'GATHER_STATS_JOB' et 'MGMT_STATS_CONFIG_JOB' (10g), ou seulement 'MGMT_STATS_CONFIG_JOB' (11g) indiquent si les mises &agrave; jour des statistiques sont activ&eacute;es ('SCHEDULED')"></td>

-- Pourquoi certains jobs sont "SCHEDULED" mais sans dates de lancement ??

prompt <td align=center><font color="WHITE"><b>Liste des Jobs</b></font></td></tr></table></td></tr>
prompt <tr><td><b>Owner</b></td><td><b>Job</b></td><td><b>Premier lancement</b></td><td><b>Prochain lancement</b></td><td><b>Statut</b></td></tr>
      select  '<tr>','<td bgcolor="LIGHTBLUE" align=left>',OWNER,'</td>','<td bgcolor="LIGHTBLUE" align=left>',JOB_NAME,'</td>','<td bgcolor="LIGHTBLUE" align=left>',to_char(START_DATE,'DD-MM-YYYY HH:MI'),'</td>','<td bgcolor="LIGHTBLUE" align=left>',to_char(NEXT_RUN_DATE,'DD-MM-YYYY HH:MI'),'</td>','<td bgcolor="',decode(STATE, 'SCHEDULED', 'BLUE', 'SUCCEEDED', 'BLUE', 'ORANGE'),'" align=right><font color="WHITE"><b>',STATE,'</b></font></td>','</tr>'
       FROM DBA_SCHEDULER_JOBS;

prompt </table><br>
-- *************************************** Mise à jour automatique des statistiques
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Mise &agrave; jour automatique des statistiques</b></font></td></tr>
prompt <tr><td><b>JOB</b></td><td><b>Automatiques (O/N)</b></td></tr>

select  '<tr><td bgcolor="LIGHTBLUE" align=left>',JOB_NAME,'</td><td bgcolor="BLUE" align=right><font color="WHITE"><b>',STATE,'</b></font></td></tr>'
   FROM DBA_SCHEDULER_JOBS 
   WHERE JOB_NAME in ('GATHER_STATS_JOB','MGMT_STATS_CONFIG_JOB');

DECLARE
 v_cur SYS_REFCURSOR;
 v_res varchar2(255);
 v_sql varchar2(2000);
-- use of $IF $THEN $END for pl/sql conditional compilation
BEGIN
  $IF dbms_db_version.version >= 11 $THEN
--    v_sql := 'SELECT ''<tr><td bgcolor="LIGHTBLUE" colspan=4>''||client_name||''</td><td bgcolor="LIGHTBLUE">''||to_char(status)||''</td></tr>'' FROM dba_autotask_client';
    v_sql := 'select  ''<tr><td bgcolor="LIGHTBLUE" align=left>''|| client_name ||''</td><td bgcolor="BLUE" align=right><font color="WHITE"><b>''|| status || ''</b></font></td></tr>'' FROM dba_autotask_operation';
    open v_cur for v_sql;
    loop
      fetch v_cur into v_res;
      EXIT WHEN v_cur%NOTFOUND;
      dbms_output.put_line(v_res);
     end loop;
  $END
-- mandatory for 10g as the block $IF-$END disapears, it needs at least on line between BEGIN and END
  v_sql := '';
END;
/

prompt </table><br>

-- *************************************** POOLS MEMOIRE
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>SGA</font></b></div>
prompt <hr>

-- *************************************** Taille SGA

prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="le DB_CACHE d&eacute;orde car il n&#39;a pas assez de place. Ajuster les deux pools supplémentaires DB_KEEP_CACHE_SIZE et DB_RECYCLE_CACHE_SIZE"></td>

prompt <td align=center><font color="WHITE"><b>Taille totale SGA</b></font></td></tr></table></td></tr>
prompt <tr><td><b>SGA</b></td><td><b>valeur (Mo)</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">Total SGA instance</td>',
'<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(sum(s.bytes)/(1024*1024),2),'99G999G990D00')||'</td>','</tr>' 
from v$sgastat s where name != 'KGH: NO ACCESS'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">KGH NO ACCESS (Echange db_cache/SGA si mode ASMM)</td>',
'<td bgcolor="'||decode(to_char(round(sum(s.bytes)/(1024*1024),2),'99G999G990D00'),NULL,'#33FF33',CouleurLimite(round(sum(s.bytes)/(1024*1024),2),60,10,1))||'" align=right>'||decode(to_char(round(sum(s.bytes)/(1024*1024),2),'99G999G990D00'),NULL,to_char('0','99G999G990D00'),to_char(round(sum(s.bytes)/(1024*1024),2),'99G999G990D00'))||'</td>','</tr>' 
from v$sgastat s where name = 'KGH: NO ACCESS'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">sga_max_size SPFILE</td>',
decode(to_char(round(p.value/(1024*1024),2)),
'','<td bgcolor="LIGHTBLUE" align=right>Non initialis&eacute;</td>','<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>'),'</tr>' 
from v$spparameter p
where p.name = 'sga_max_size'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">sga_target SPFILE</td>',
decode(to_char(round(p.value/(1024*1024),2)),
'','<td bgcolor="LIGHTBLUE" align=right>Non initialis&eacute;</td>','<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>'),'</tr>' 
from v$spparameter p
where p.name = 'sga_target'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">memory_max_target SPFILE</td>',
decode(to_char(round(p.value/(1024*1024),2)),
'','<td bgcolor="LIGHTBLUE" align=right>Non initialis&eacute;</td>','<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>'),'</tr>' 
from v$spparameter p
where p.name = 'memory_max_target'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">memory_target SPFILE</td>',
decode(to_char(round(p.value/(1024*1024),2)),
'','<td bgcolor="LIGHTBLUE" align=right>Non initialis&eacute;</td>','<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>'),'</tr>' 
from v$spparameter p
where p.name = 'memory_target'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">sga_max_size INSTANCE (ou PFILE)</td>',
'<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>','</tr>' 
from v$parameter p
where p.name = 'sga_max_size'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">sga_target INSTANCE (ou PFILE)</td>',
'<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>','</tr>' 
from v$parameter p
where p.name = 'sga_target'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">memory_max_target INSTANCE (ou PFILE)</td>',
'<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>','</tr>' 
from v$parameter p
where p.name = 'memory_max_target'
UNION ALL
select '<tr>','<td bgcolor="LIGHTBLUE">memory_target INSTANCE (ou PFILE)</td>',
'<td bgcolor="LIGHTBLUE" align=right>'||to_char(round(p.value/(1024*1024),2),'99G999G990D00')||'</td>','</tr>' 
from v$parameter p
where p.name = 'memory_target'
UNION ALL
select '<tr>','<td bgcolor="WHITE">TOTAL</td>',
'<td bgcolor="BLUE" align=right><font color="WHITE"><b>'||to_char(round(sum(s.bytes)/(1024*1024),2),'99G999G990D00')||'</b></font></td>','</tr>' 
from v$sgastat s;

prompt </table><br>

-- *************************************** MISE A JOUR TABLE HISTORIQUE
delete from ~tblhist where trunc(to_date(date_aud))=trunc(sysdate) and type_obj='SGA';
insert into ~tblhist (
select sysdate,'SGA','sga_size (spfile/max_used)',total,valeur,0 from 
(select round(value/(1024*1024),2) total from v$parameter where name = 'sga_max_size') p,
(select round(sum(bytes)/(1024*1024),2) valeur from v$sgastat) s
);
insert into ~tblhist (
select sysdate, 'SGA', 'shared_pool (spfile/used)', t.Shared_pool_size, u.utilise, 0
from (select name, round(value/(1024*1024),2) Shared_pool_size
      from v$parameter where name='shared_pool_size') t,
     (select round(sum(bytes)/(1024*1024),2) Utilise
      from v$sgastat where pool='shared pool' and name <> 'free memory') u);
insert into ~tblhist (
select sysdate,'SGA','buffer_cache',round(value/(1024*1024),2), 0, 0 from v$sga
where name = 'Database Buffers');


-- *************************************** Diff memoire utilisee
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Diff&eacute;rence de tailles depuis le dernier audit (
print last_audit
prompt )</b></font></td></tr>
prompt <td><b>Espaces m&eacute;moire</b></td><td><b>SPFILE (Mo)</b></td><td><b>Utilis&eacute; (Mo)</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',a.obj_name,'</td>',
decode(SIGN(a.total-h.total),
      -1,'<td bgcolor="#33FF33" align=right>'||to_char(a.total-h.total,'S99G999G990D00')||'</td>',
       0,'<td bgcolor="LIGHTBLUE" align=right>'||to_char(a.total-h.total,'99G999G990D00')||'</td>',
       1,'<td bgcolor="ORANGE" align=right>'||to_char(a.total-h.total,'S99G999G990D00')||'</td>') TOTAL,
decode(SIGN(a.utilis-h.utilis),
      -1,'<td bgcolor="#33FF33" align=right>'||to_char(a.utilis-h.utilis,'S99G999G990D00')||'</td>',
       0,'<td bgcolor="LIGHTBLUE" align=right>'||to_char(a.utilis-h.utilis,'99G999G990D00')||'</td>',
       1,'<td bgcolor="ORANGE" align=right>'||to_char(a.utilis-h.utilis,'S99G999G990D00')||'</td>') UTILISE,'</tr>'
from
(select * from ~tblhist
	where trunc(to_date(date_aud))=trunc(sysdate)
and type_obj='SGA') a,
(select * from ~tblhist
	where to_date(date_aud) like
	(select max(to_date(date_aud)) from ~tblhist
                where to_date(date_aud) < trunc(sysdate)
                and type_obj='SGA')
	and type_obj='SGA') h
where a.obj_name=h.obj_name;

prompt </table><br>

-- *************************************** Pools memoire
-- memory_target = sga_target + max(pga_aggregate_target, maximum PGA allocated)
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Infos SGA</b></font></td></tr>
prompt <tr><td><b>Nom</b></td><td><b>Valeur (Mo)</b></td></tr>
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>vue V$SGAINFO (>=10g)</b></font></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',name,'</td>' NOM,'<td bgcolor="LIGHTBLUE" align=right>',to_char(round(bytes/(1024*1024),2),'99G999G990D00'),'</td>' total,'</tr>' from v$sgainfo;
-- Pour compatibilite avec 9i :
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>vue V$SGA (toutes versions)</b></font></td></tr>
select '<tr>','<td bgcolor="LIGHTBLUE">',name,'</td>' NOM,'<td bgcolor="LIGHTBLUE" align=right>',to_char(round(value/(1024*1024),2),'99G999G990D00'),'</td>' valeur,'</tr>' from v$sga;
prompt </table><br>

-- MEMORY_TARGET_ADVICE
-- tableau "advice" de prédiction des perfs selon tailles de cache
-- http://pages.di.unipi.it/ghelli/didattica/bdldoc/B19306_01/server.102/b14211/memory.htm#i29118
-- !! si DB_CACHE_ADVICE est ON

-- TODO : renommer les variables v_res* pour refléter ce qu'elles contiennent
--        détecter le *_SIZE_FACTOR=1 pour garder la valeur ESTD_DB_TIME. Ensuite, si un ESTD_DB_TIME est inférieur à celui-ci, changer le background en orange (en modifiant la couleur dans v_res1, v_res3, v_res5
--        Mettre la ligne SIZE_FACTOR=1 dans une autre couleur ? Bleu légèrement plus sombre ?

prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Memory target advice</b></font></td></tr>
prompt <tr><td><b>Memory size</b></td><td><b>Memory_target size factor</b></td><td><b>Estimated DB workload</b></td></tr>

DECLARE
 v_res1 varchar2(2000);
 v_res2 varchar2(2000);
 v_res3 varchar2(2000);
 v_res4 varchar2(2000);
 v_res5 varchar2(2000);
 v_res6 varchar2(2000);
 v_res7 varchar2(2000);

 cnt_line number := 0;
 db_advice number := 0;
 memory_target number := 0;
 v_cur SYS_REFCURSOR;
 v_sql varchar2(2000);
-- use $IF $THEN $END for pl/sql conditional compilation
BEGIN
  $IF dbms_db_version.version >= 11 $THEN
    select count(*) into cnt_line from v$memory_target_advice;
    select decode(value, 'ON', 1, 0) into db_advice from v$parameter where name='db_cache_advice';
    select value into memory_target from v$parameter where name='memory_target';
    if (memory_target > 0 and cnt_line=0) or db_advice=0 then
      select '<tr><td bgcolor="LIGHTGREY"><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor="LIGHTGREY"></td><td bgcolor="LIGHTGREY"></td></tr>' into v_res1 from dual;
      dbms_output.put_line(v_res1);
    else
      if memory_target=0 then -- if parameter MEMORY_TARGET is not initialized, display SGA stats instead
        v_sql := 'select ''<tr>''||''<td bgcolor="LIGHTBLUE">''||decode(SGA_SIZE_FACTOR,1,''<b>'',''''),SGA_SIZE,decode(SGA_SIZE_FACTOR,1,''</b>'','''')||''</td>''||''<td bgcolor="LIGHTBLUE" align=right>''||decode(SGA_SIZE_FACTOR,1,''<b>'',''''),to_char(SGA_SIZE_FACTOR,''990D00''),decode(SGA_SIZE_FACTOR,1,''</b>'','''')||''</td>''||''<td bgcolor="LIGHTBLUE" align=right>''||decode(SGA_SIZE_FACTOR,1,''<b>'',''''),ESTD_DB_TIME,''</td>''||decode(SGA_SIZE_FACTOR,1,''</b>'','''')||''</tr>'' from v$sga_target_advice ORDER BY 2';
      else
        v_sql := 'select ''<tr>''||''<td bgcolor="LIGHTBLUE">''||decode(MEMORY_SIZE_FACTOR,1,''<b>'',''''),MEMORY_SIZE,decode(MEMORY_SIZE_FACTOR,1,''</b>'','''')||''</td>''||''<td bgcolor="LIGHTBLUE" align=right>''||decode(MEMORY_SIZE_FACTOR,1,''<b>'',''''),to_char(MEMORY_SIZE_FACTOR,''990D00''),decode(MEMORY_SIZE_FACTOR,1,''</b>'','''')||''</td>''||''<td bgcolor="LIGHTBLUE" align=right>''||decode(MEMORY_SIZE_FACTOR,1,''<b>'',''''),ESTD_DB_TIME,''</td>''||decode(MEMORY_SIZE_FACTOR,1,''</b>'','''')||''</tr>'' from v$memory_target_advice ORDER BY 2';
      end if;
      open v_cur for v_sql;
      loop
        fetch v_cur into v_res1, v_res2, v_res3, v_res4, v_res5, v_res6, v_res7 ;
        EXIT WHEN v_cur%NOTFOUND;
        dbms_output.put_line(v_res1||v_res2||v_res3||v_res4||v_res5||v_res6||v_res7);
     end loop;
    end if;
  $ELSE
    select '<tr><td bgcolor="LIGHTGREY"><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor="LIGHTGREY"></td><td bgcolor="LIGHTGREY"></td></tr>' into v_res1 from dual;
    dbms_output.put_line(v_res1);
  $END
-- mandatory for 10g as the block $IF-$END disapears, it needs at least one line between BEGIN and END
  v_res1 := '';
END;
/

prompt </table><br>

-- *************************************** SHARED POOL
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>SHARED POOL</font></b></div>
prompt <hr>
-- *************************************** Shared pool
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Shared pool area</b></font></td></tr>
prompt <tr><td><b>Pool</b></td><td><b>Total (Mo)</b></td><td><b>Utilis&eacute; (Mo)</b></td><td><b>Libre (Mo)</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',t.name,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(t.total,'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(u.utilise,'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(l.libre,'99G999G990D00'),'</td>','</tr>'
from (select name, round(bytes/(1024*1024),2) Total
      from v$sgainfo where lower(name)='shared pool size') t,
     (select round(sum(bytes)/(1024*1024),2) Utilise
      from v$sgastat where pool='shared pool' and name <> 'free memory') u,
     (select round(sum(bytes)/(1024*1024),2) libre
      from v$sgastat where pool='shared pool' and name = 'free memory') l;

prompt </table><br>

-- *************************************** Dictionary cache
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=5>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="GETS column represents the total number of times a process or Oracle asked for the item named in the column PARAMETER. GETMISSES column represents the number of times a request for dictionary information couldn&#39;t find that information in the dictionary cache and instead had to go to the SYSTEM tablespace to retrieve the information. SCANS column is the number of scan requests. SCANMISSES column is the times a scan failed to find the data in the cache.">
prompt &nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Augmenter SHARED_POOL_SIZE si les ratios (Library ET Dictionary cache) sont inf&eacute;rieur &agrave; 85%."></td>
prompt <td align=center><font color="WHITE"><b>Dictionary cache</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>

prompt <tr><td width=15%><b>Gets</b></td><td width=15%><b>Get Misses</b></td><td width=15%><b>Scan</b></td><td width=15%><b>Scan Misses</b></td><td align=center><b>Ratio</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',sum(gets),'</td>','<td bgcolor="LIGHTBLUE">',sum(getmisses),'</td>','<td bgcolor="LIGHTBLUE">',sum(scans),'</td>','<td bgcolor="LIGHTBLUE">',sum(scanmisses),'</td>',
'<td bgcolor="',CouleurLimite(round((sum(gets)-sum(getmisses))/sum(gets),2)*100,85,5,0),'" align=right>',round((sum(gets)-sum(getmisses))/sum(gets),2)*100,' % </td>','</tr>'
from v$rowcache;

prompt </table><br>

-- *************************************** Library cache
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=4>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="Library Cache Misses indicate that the Shared Pool is not big enough to hold the shared SQL area for all concurrently open cursors. If you have no Library Cache misses (PINS = 0), you may get a small increase in performance by setting CURSOR_SPACE_FOR_TIME = TRUE which prevents ORACLE from deallocating a shared SQL area while an application cursor associated with it is open. For Multi-threaded server, add 1K to SHARED_POOL_SIZE per user.">
prompt &nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Info..." title="Augmenter SHARED_POOL_SIZE si les ratios (Library ET Dictionary cache) est inf&eacute;rieur &agrave; 85%"></td>
prompt <td align=center><font color="WHITE"><b>Library cache</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>
prompt <tr><td><b>Executions</b></td><td><b>Rechargements</b></td><td colspan=2><b>Ratio</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE" align=right>',sum(pins),'</td>' exec,
'<td bgcolor="LIGHTBLUE" align=right>',sum(reloads),'</td>' recharg,
'<td bgcolor="',CouleurLimite(round((sum(pins)-sum(reloads))/sum(pins),2)*100,85,5,0),'" align=right colspan=2>',round((sum(pins)-sum(reloads))/sum(pins),2)*100,' %</td>' ratio,'</tr>'
from v$librarycache;

-- *************************************** Stat library cache
prompt <tr><td bgcolor="#3399CC" colspan=4>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="GETHITS est le pourcentage de fois o&ugrave; un pointeur d&#39;objet a &eacute;t&eacute; requis et trouv&eacute; en mémoire. PINHITS est le pourcentage de fois o&ugrave; toutes les m&eacute;tadonn&eacute;es de d&eacute;finition de l&#39;objet ont &eacute;t&eacute; trouv&eacute;es en m&eacute;moire.">
prompt &nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Rapprocher ces statistiques des ratios dictionary et library cache.<br>Augmenter SHARED_POOL_SIZE si les ratios sont inf&eacute;rieur &agrave; 90%. BODY et INDEX ne sont pas significatifs et peuvent &ecirc;tre ignor&eacute;s."></td>
prompt <td align=center><font color="WHITE"><b>Statistiques library cache par types de requ&ecirc;tes</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>

prompt <tr><td colspan=2><b>Namespace</b></td><td><b>GetHits</b></td><td><b>PinHits</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE" colspan=2>',namespace,'</td>',
'<td bgcolor="',CouleurLimite(round(gethitratio,2)*100,70,10,0),'" align=right>',round(gethitratio,2)*100,' %</td>',
'<td bgcolor="',CouleurLimite(round(pinhitratio,2)*100,70,10,0),'" align=right>',round(pinhitratio,2)*100,' %</td>','</tr>'
from v$librarycache;

prompt </table><br>

-- *************************************** Requetes les plus gourmandes
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=9><font color="WHITE"><b>Requ&ecirc;tes les plus gourmandes en ressources (moyennes par ex&eacute;cution)</b></font></td></tr>
prompt <tr><td><b>Ex&eacute;cutions</b></td><td><b>Recalculs</b></td><td align=center><b>Ratio</br>r&eacute;-ex&eacute;cutions</b></td><td><b>Moy. tris</b></td><td><b>Moyenne lectures disque</b></td><td><b>Moyenne temps &eacute;coul&eacute; (&micro;sec)</b></td><td><b>Moyenne buffers</b></td><td><b>(Adresse v$sqlarea) Requ&ecirc;te SQL</b></td></tr>
SELECT '<tr>','<td bgcolor="LIGHTBLUE">',sqla.executions,'</td>',
'<td bgcolor="LIGHTBLUE">',sqla.parse_calls,'</td>',
'<td bgcolor="LIGHTBLUE">',to_char(round((sqla.parse_calls/sqla.executions)*100,2),'99G999G990D00'),'%','</td>',
'<td bgcolor="LIGHTBLUE">',round(sqla.sorts/sqla.executions,0),'</td>',
'<td bgcolor="LIGHTBLUE">',round(sqla.disk_reads/sqla.executions,0),'</td>',
'<td bgcolor="LIGHTBLUE"><b>',round(sqla.elapsed_time/sqla.executions,0),'</b></td>',
'<td bgcolor="LIGHTBLUE">',round(sqla.buffer_gets/sqla.executions,0),'</td>',
'<td bgcolor="LIGHTBLUE">','(<b>'||sqla.address||'</b>)',replace(replace(sqla.sql_text, '<', '&lt;'), '>', '&gt;') ,'</td>','</tr>'
FROM (select * from v$sqlarea where executions > 50
  AND elapsed_time > 1000
  AND COMMAND_TYPE in (2,3,6,7)
  AND BUFFER_GETS/NULLIF(executions,0) > 100
  ORDER BY round(elapsed_time/NULLIF(executions,0),0) DESC
) sqla
WHERE ROWNUM < 21;

DECLARE cnt_rq number := 0;
BEGIN
  select count(sqla.address) into cnt_rq 
FROM (select * from v$sqlarea where executions > 50
  AND elapsed_time > 1000
  AND COMMAND_TYPE in (2,3,6,7)
  AND BUFFER_GETS/NULLIF(executions,0) > 100
) sqla
WHERE rownum = 1;
   if cnt_rq=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td>');
      dbms_output.put_line('<td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** AUTRES POOLS
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>AUTRES POOLS</font></b></div>
prompt <hr>
-- *************************************** Large pool
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Large pool</b></font></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Total (Mo)</b></td><td width=15%><b>Utilise (Mo)</b></td><td width=15%><b>Libre (Mo)</b></td></tr>
select '<tr>','<td bgcolor="LIGHTBLUE">',t.name,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(t.total,NULL,0,t.total),'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(u.utilise,NULL,0,t.total),'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(l.libre,NULL,0,t.total),'99G999G990D00'),'</td>','</tr>'
from (select name, round(value/(1024*1024),2) total
      from v$parameter where name='large_pool_size') t,
     (select round(sum(bytes)/(1024*1024),2) utilise
      from v$sgastat where pool = 'large pool' and name <> 'free memory') u,
     (select round(sum(bytes)/(1024*1024),2) libre
      from v$sgastat where pool = 'large pool' and name = 'free memory') l;

prompt </table><br>

-- *************************************** Java pool
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Java pool</b></font></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Total (Mo)</b></td><td width=15%><b>Utilis&eacute; (Mo)</b></td><td width=15%><b>Libre (Mo)</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',substr(t.name,1,30),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(t.total,NULL,0,t.total),'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(u.utilise,NULL,0,t.total),'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(l.libre,NULL,0,t.total),'99G999G990D00'),'</td>','</tr>'
from (select name, round(value/(1024*1024),2) total
      from v$parameter where name='java_pool_size') t,
     (select round(sum(bytes)/(1024*1024),2) utilise
      from v$sgastat where pool = 'java pool' and name <> 'free memory') u,
     (select round(sum(bytes)/(1024*1024),2) libre
      from v$sgastat where pool = 'java pool' and name = 'free memory') l;

prompt </table><br>

-- *************************************** BUFFER CACHE
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>BUFFER CACHE</font></b></div>
prompt <hr>
-- *************************************** Buffer cache : Blocs lus E/S
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Si ce ratio est tr&egrave;s sup&eacute;rieur &agrave; 10, laisser tel quel (pas ajustable). Sinon ajuster _small_table_threshold (defaut 4) pour &ecirc;tre inf&eacute;rieur &agrave; 10."></td>
prompt <td align=center><font color="WHITE"><b>Buffer cache : Blocs lus E/S</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>

prompt <tr><td width=60%><b>Nom</b></td><td width=40%><b>Valeur</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">'||name||'</td>','<td bgcolor="LIGHTBLUE" align=right>'||value||'</td>','</tr>'
from v$sysstat
where name like 'table scan%'
UNION ALL
select '<tr>','<td bgcolor="WHITE" title="(scans blocks / (scans short tables + scans long tables))"> Ratio</td>', '<td bgcolor="'||CouleurLimite(round(t1.value/(t2.value+t3.value),2),15,1,1)||'" align=right>'||to_char(round(t1.value/(t2.value+t3.value),2),'99G990D00')||'</td>','</tr>' from v$sysstat t1, v$sysstat t2, v$sysstat t3
where t1.name like 'table scan blocks gotten%'
and t2.name like 'table scans (short tables)%'
and t3.name like 'table scans (long tables)%';
-- *************************************** Buffer cache : hit ratio
prompt <tr><td bgcolor="#3399CC" colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Augmenter DB_BLOCK_BUFFERS (ou DB_BLOCK_SIZE) pour que le ratio soit entre 70% et 80%. Au-dessus de 98% on peut gagner de la m&eacute;moire en r&eacute;duisant les buffers."></td>
prompt <td align=center><font color="WHITE"><b>Buffer cache : hit ratio</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Valeur</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">'||name||'</td>', '<td bgcolor="LIGHTBLUE" align=right>'||value||'</td>','</tr>' from v$sysstat
where name in ('db block gets from cache','consistent gets from cache','physical reads cache')
order by 1;
-- UNION ALL
select '<tr>','<td bgcolor="WHITE" title="ratio global pour tous les pools ((db blocks gets+consistent gets)-physical reads)/(db blocks gets+consistent gets)">Ratio <b>v$sysstat</b></td>','<td bgcolor="'||CouleurLimite(round(((t1.value+t2.value)-t3.value)/(t1.value+t2.value),2)*100,70,10,0)||'" align=right>'||round(((t1.value+t2.value)-t3.value)/(t1.value+t2.value),2)*100||' %</td>','</tr>'
from v$sysstat t1, v$sysstat t2, v$sysstat t3
where t1.name='db block gets from cache' and t2.name='consistent gets from cache' and t3.name='physical reads cache';

-- difference v$sysstat/v$buffer_pool_statistics : voir si 'physical reads direct' 'physical reads direct (lob)' à enlever à
-- 'physical reads' sur v$sysstat change qqchose ?

select '<tr>','<td bgcolor="LIGHTBLUE">db_block_gets (pool '||name||')</td>' as name, '<td bgcolor="LIGHTBLUE" align=right>'||db_block_gets||'</td>','</tr>' from  v$buffer_pool_statistics;
-- UNION
select '<tr>','<td bgcolor="LIGHTBLUE">consistent_gets (pool '||name||')</td>' as name, '<td bgcolor="LIGHTBLUE" align=right>'||consistent_gets||'</td>','</tr>' from  v$buffer_pool_statistics;
-- UNION
select '<tr>','<td bgcolor="LIGHTBLUE">physical_reads (pool '||name||')</td>' as name, '<td bgcolor="LIGHTBLUE" align=right>'||physical_reads||'</td>','</tr>' from  v$buffer_pool_statistics;
-- UNION ALL
select '<tr>','<td bgcolor="WHITE" title="Ratio par pool ((db blocks gets+consistent gets)-physical reads)/(db blocks gets+consistent gets)">Ratio <b>v$buffer_pool_statistics</b> (pool '||name||')</td>' as name,'<td bgcolor="'||CouleurLimite(round(((db_block_gets+consistent_gets)-physical_reads)/(db_block_gets+consistent_gets),2)*100,70,10,0)||'" align=right>'||round(((db_block_gets+consistent_gets)-physical_reads)/(db_block_gets+consistent_gets),2)*100||' %</td>','</tr>'
from v$buffer_pool_statistics;

prompt </table><br>

-- *************************************** Redo buffers ****************************
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>REDO BUFFERS</font></b></div>
prompt <hr>
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Redo buffers</b></font></td></tr>
prompt <tr><td width=15% colspan=2><b>Pool</b></td><td width=15%><b>Taille (Mo)</b></td></tr>
select '<tr>','<td bgcolor="LIGHTBLUE" colspan=2>',name,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(value/(1024*1024),2),'99G999G990D00'),'</td>','</tr>' from v$parameter
where name='log_buffer';

prompt </table><br>

-- *************************************** Stats redo logs (contentions)
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="Augmenter LOG_BUFFER pour que REDO LOG SPACE REQUESTS soit proche de 0. Si le ratio wastage/size est inf&eacute;rieur &agrave; 80%, il y a trop de perte de place dans les fichiers redo, ce qui indique une activit&eacute; trop forte du LGWR. V&eacute;rifier les checkpoints et/ou les switchs."></td>
prompt <td align=center><font color="WHITE"><b>Statistiques redo logs (contentions)</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Valeur</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">'||name||'</td>','<td bgcolor="'||decode(name,'redo log space requests',CouleurLimite(value,100000,1000,1),'redo log space wait time',CouleurLimite(value,100000,1000,1),'LIGHTBLUE')||'" align=right>'||value||'</td>','</tr>' from v$sysstat
where name like 'redo%'
UNION ALL
select '<tr>','<td bgcolor="WHITE">Ratio wastage/size</td>', '<td bgcolor="'||CouleurLimite(round(1-(t1.value/t2.value),2)*100,70,5,0)||'" align=right>'||round(1-(t1.value/t2.value),2)*100||' %</td>','</tr>'
from v$sysstat t1, v$sysstat t2
where t1.name like 'redo wastage'
and t2.name like 'redo size';

prompt </table><br>

-- *************************************** Stats latchs (contentions)
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" colspan=3>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print tips
prompt " width="20" height="20" alt="Tips..." title="si un des ratio excede 5%, les performances sont affect&eacute;es, diminuer LOG_SMALL_ENTRY_SIZE." width=15%></td>
prompt <td align=center><font color="WHITE"><b>Statistiques latchs (contentions)</b></font></td><td width=10%>&nbsp;</td></tr></table></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Ratio misses/gets</b></td><td width=25%><b>Ratio immediate misses/immediate gets</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',name,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(sum(misses)/(sum(gets)+0.00000000001)*100),'990D00'),' %</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(sum(immediate_misses)/(sum(immediate_misses+immediate_gets)+0.00000000001)*100),'990D00'),' %</td>','</tr>'
from   v$latch
where  name in ('redo allocation',  'redo copy')
group by name;

prompt </table><br>

-- *************************************** zone de tri
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>SORT AREA</font></b></div>
prompt <hr>
-- *************************************** Taille zone de tri
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Taille zone de tri</b></font></td></tr>
prompt <tr><td width=15%><b>Pool</b></td><td width=15%><b>Taille (Mo)</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',name,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(value/(1024*1024),2),'99G999G990D00'),'</td>','</tr>' from v$parameter
where name='sort_area_size';
-- *************************************** Statistiques zone de tri
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Statistiques zone de tri</b></font></td></tr>
prompt <tr><td width=15%><b>Nom</b></td><td width=15%><b>Valeur</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">'||name||'</td>', '<td bgcolor="LIGHTBLUE" align=right>'||value||'</td>','</tr>' from v$sysstat
where name like 'sort%'
UNION ALL
select '<tr>','<td bgcolor="WHITE">Ratio (1 - (sorts disk / sorts memory))</td>', '<td bgcolor="'||CouleurLimite(round(1-(t1.value/t2.value),2)*100,85,5,0)||'" align=right>'||round(1-(t1.value/t2.value),2)*100||' %</td>','</tr>' from v$sysstat t1, v$sysstat t2
where t1.name like 'sorts (disk)%'
and t2.name like 'sorts (memory)%';

prompt </table><br>

-- *************************************** PGA
prompt <hr>
prompt <div align=center><b><font color="WHITE" size=2>PGA</font></b></div>
prompt <hr>
-- *************************************** Statistiques PGA
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Cumuls PGA</b></font></td></tr>
prompt <tr><td width=15%><b>Actuel (Mo)</b></td><td width=15%><b>Max allou&eacute; (Mo)</b></td><td width=15%><b>PGA_AGGREGATE_TARGET (Mo)</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE" align=right>',to_char(round(sum(PGA_ALLOC_MEM)/1024/1024,2),'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(sum(PGA_MAX_MEM)/1024/1024,2),'99G999G990D00'),'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(to_number(value)/1024/1024,2),'99G999G990D00'),'</td>','</tr>'
from v$process,v$parameter
where name='pga_aggregate_target'
group by value;

-- *************************************** Detail UGA par utilisateur
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>D&eacute;tail UGA par utilisateur</b></font></td></tr>
prompt <tr><td width=15% colspan=2><b>Sch&eacute;ma</b></td><td width=15%><b>Nombre de sessions par sch&eacute;ma</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE" colspan=2>',username,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',count(*),'</td>','</tr>'
from v$statname n, v$sesstat t, v$session s
where s.sid=t.sid
and n.statistic#=t.statistic#
and s.type='USER'
and s.username is not null
and n.name='session pga memory'
group by username;

select '<tr><td width=15% colspan=2><b>Nombre d&#39;utilisateurs au moment de l&#39;audit</b></td>','<td bgcolor="BLUE" align=right><font color="WHITE">',count(*),'</td>','</tr>'
from v$statname n, v$sesstat t, v$session s
where s.sid=t.sid
and n.statistic#=t.statistic#
and s.type='USER'
and s.username is not null
and n.name='session pga memory';

select '<tr><td width=15% colspan=2><b>Nombre max. d&#39;utilisateurs simultan&eacute;s (highwater) / Nombre max. autoris&eacute;s</b></td>','<td bgcolor="BLUE" align=right><font color="WHITE"><b>',sessions_highwater,'/',decode(SESSIONS_MAX,0,'-',SESSIONS_MAX),'</b></td>','</tr>'
from v$license;

select '<tr><td width=15% colspan=2><b>Total UGA (Mo)</b></td>','<td bgcolor="BLUE" align=right><font color="WHITE">',to_char(round(sum(value)/(1024*1024),2),'99G999G990D00'),'</td>','</tr>'
from v$statname n, v$sesstat t
where n.statistic#=t.statistic#
and n.name='session uga memory';

select '<tr><td width=15% colspan=2><b>Total max UGA (Mo)</b></td>','<td bgcolor="BLUE" align=right><font color="WHITE">',to_char(round(sum(value)/(1024*1024),2),'99G999G990D00'),'</td>','</tr>'
from v$statname n, v$sesstat t
where n.statistic#=t.statistic#
and n.name='session uga memory max';

prompt </table><br>

-- *************************************** ALERT.LOG
prompt <hr>
prompt <div align=center><b><font color="WHITE">ALERT LOG</font></b></div>
prompt <hr>

-- *************************************** Read the alert.log file
prompt <!-- ALERT.LOG -->

define alert_length="2000"
column nlsdate new_value _nlsdate noprint;
column db      new_value _db    noprint;

select VALUE nlsdate from NLS_DATABASE_PARAMETERS where parameter = 'NLS_DATE_LANGUAGE';
select instance_name db from v$instance;

-- *************************************** create ou truncate final table "alert_log"
prompt <!-- Creation des tables -->
-- force sqlplus to exit on error

WHENEVER sqlerror EXIT sql.sqlcode
DECLARE
   table_exist number;
   tabtools number;
BEGIN
   select count(table_name) into table_exist from dba_tables
   where table_name='ALERT_LOG';
--   and owner = 'SYSTEM';
   IF table_exist = 0 THEN
      select count(tablespace_name) into tabtools from dba_tablespaces
      where tablespace_name='~tbstools';
      IF tabtools = 0 THEN
         dbms_output.put_line('<td bgcolor="#33FF33">Ajouter un tablespace <b>~tbstools</b> pour la table ALERT_LOG</br>');
         raise_application_error(-20003,'Tablespace ~tbstools does not exist');
      ELSE
         EXECUTE IMMEDIATE 'create table alert_log (
                             alert_date date,
                             alert_text varchar2(~~alert_length)
                         ) TABLESPACE ~tbstools';
      END IF;
      EXECUTE IMMEDIATE 'create index alert_log_idx on alert_log(alert_date)';
   ELSE
      EXECUTE IMMEDIATE 'truncate table alert_log';
   END IF;
END;
/

-- now avoid sqlplus to exit
WHENEVER sqlerror CONTINUE;

-- *****************************************  external table alert_log_disk (ak alert<SID>.log file)

var sbdump varchar2(255);
col sbdump new_value sbdump;
var sbsize  number;
col sbsize new_value sbsize;
DECLARE
   dir_exist number;
   bdump varchar2(255);
   v_sql varchar2(2000);
   file_exists BOOLEAN;
   file_length NUMBER;
   file_block_size BINARY_INTEGER;
BEGIN
   $IF dbms_db_version.version > 11 $THEN
      select VALUE into bdump from v$diag_info where NAME='Diag Trace';
   $ELSE
      select VALUE into bdump from v$parameter where name ='background_dump_dest';
   $END
   select count(DIRECTORY_NAME) into dir_exist from dba_directories
     where DIRECTORY_NAME='BDUMPPERF';
--    and owner in ('SYSTEM','SYS');
   IF dir_exist = 0 THEN
-- recreate a directory to bdump even if a system 'BDUMP' directory already exists, because if the script is
-- executed by a non-SYSTEM user, it as no privilege for using BDUMP.
     v_sql := 'create directory BDUMPPERF as ''' || bdump || '''';
     EXECUTE IMMEDIATE v_sql;
   END IF;
-- sbdump string used in prompts below
   IF substr(bdump,2,1) = ':' THEN
      :sbdump := bdump || '\'; -- Windows path'
   ELSE
      :sbdump := bdump || '/'; -- unix path
   END IF;
   UTL_FILE.FGETATTR('BDUMP', 'alert_~_db..log', file_exists, file_length, file_block_size);
   :sbsize := file_length;
--   dbms_output.put_line (bdump);
--   dbms_output.put_line ('alert_~_db..log');
--   dbms_output.put_line ('FILE'||file_length);
END;
/

prompt <!--
-- If not printed once here before, the global variables aren't recognized by prompt later... Why ??
print :sbdump
print :sbsize
prompt -->

prompt <!-- Creation alert_log_disk -->
DECLARE
   table_exist number;
   v_sql varchar2(2000);
BEGIN
   select count(table_name) into table_exist from dba_tables
   where table_name='ALERT_LOG_DISK';
--   and owner = 'SYSTEM';
   IF table_exist <> 0 THEN
      v_sql := 'drop table alert_log_disk';
      EXECUTE IMMEDIATE v_sql;
   END IF;

   EXECUTE IMMEDIATE 'create table alert_log_disk (text varchar2(~~alert_length))
                         organization external (
                            type oracle_loader
                            default directory BDUMPPERF
                            access parameters (
                               records delimited by newline nologfile nobadfile
                               fields terminated by "&" ltrim
                               )
                            location(''alert_~_db..log'')
                            )
                         reject limit unlimited';
END;
/

-- ************************************ update table alert_log from alert_log_disk
-- To be processed :
--  declare * ERREUR à la ligne 1 : ORA-01653: unable to extend table SYSTEM.ALERT_LOG by 128 in tablespace TOOLS ORA-06512: at line 83
prompt <!-- Remplissage alert_log -->
declare
  isdate         number := 0;
  start_updating number := 0;
  rows_total     number := 0;
  rows_inserted  number := 0;
  rows_identical number := 1;
  alert_date     date;
  last_alert_date date;
  max_date       date;
  alert_text     alert_log_disk.text%type;
  last_alert_text alert_log_disk.text%type;
  thisyear       char(4);

begin
-- find a starting date : last audit
  select max(to_date(date_aud)) into max_date from ~tblhist
                where to_date(date_aud) < trunc(sysdate);
  select count(*) into rows_total from alert_log_disk;

  if (max_date is null) then
-- First audit. Extract messages from 01/01 of the current year
    select extract(year from sysdate) into thisyear from dual;
    max_date := to_date(concat('01-01-',thisyear), 'dd-mm-yyyy');
  end if;
  
  for r in (
     select text from alert_log_disk
     where text not like '%offlining%' 
       and text not like 'ARC_:%' 
       and text not like '%Thread 1 advanced to log sequence%'
       and text not like '%Current log#%seq#%mem#%'
       and LOWER(text) not like 'alter system archive log%'
       and text not like '%Undo Segment%lined%'
       and text not like '%alter tablespace%back%'
       and text not like '%Log actively being archived by another process%'
       and text not like '%Committing creation of archivelog%'
       and text not like '%Private_strands%'
       and trim(text) not like '(~_db)'
       and text not like '%Created Undo Segment%'
       and text not like '%started with pid%'
       and text not like '%ORA-12012%'
       and text not like '%ORA-06512%'
       and text not like '%ORA-02097%'
       and text not like '%ORA-00439%'
       and text not like '%coalesce%'
       and text not like '%Beginning log switch checkpoint up to RBA%'
       and text not like '%Completed checkpoint up to RBA%'
       and text not like '%specifies an obsolete parameter%'
       and LOWER(text) not like '%begin backup%'
       and LOWER(text) not like '%end backup%'
       and LOWER(text) not like 'alter database backup controlfile%'
       and LOWER(text) not like '%starting%'
       and text not like '%autobackup%'
       and text not like '%handle%'
       and LOWER(text) not like '%created oracle managed file%'
       and text not like 'ORA-21780 encountered when generating server alert SMG-3503%'
       and text not like 'Completed:%'
       and text not like 'ORA-INFO::%'
  )
  loop

    isdate     := 0;
    alert_text := null;

-- From char. 21 to 24 this can be a year. If yes (and we keep only the current year) it is a date, if not, it's any kind of text.
    select count(*) into isdate  
      from dual
     where substr(r.text, 21) in
      (to_char(sysdate, 'YYYY'), to_char(sysdate-365, 'YYYY'))
       and r.text not like '%cycle_run_year%';
    if (isdate = 1) then
-- from month (begin at char. 5) - force NLS in AMERICAN to avoid conversion errors ? Are all alert.log in AMERICAN ?
-- If it's necessary to take the NLS of the database, use the variable "&_nlsdate" instead of "AMERICAN"
      select to_date(substr(r.text, 5),'Mon dd hh24:mi:ss rrrr','NLS_DATE_LANGUAGE = AMERICAN')
        into alert_date 
        from dual;

-- Keep only lines with a date >= max_date
      if (to_date(alert_date, 'dd-mm-yyyy') >= to_date(max_date, 'dd-mm-yyyy')) then
        start_updating := 1;
      end if;
    else
-- for multiline messages, suppress the part of the multiline we don't wat to display, so we'll can count identical messages generated by day.
      IF r.text not like 'Thread _ cannot allocate new log, sequence%' THEN
--   dbms_output.put_line(r.text||'</br>');
         alert_text := r.text;
      END IF;
    end if;

    IF (alert_text IS NOT NULL) AND (start_updating = 1) THEN
      IF (alert_text = last_alert_text) and (to_date(alert_date, 'dd-mm-yyyy') = to_date(last_alert_date, 'dd-mm-yyyy')) THEN
        rows_identical := rows_identical + 1;
      ELSE
        IF rows_identical > 1 THEN -- count how many identical messages a day
          INSERT INTO alert_log VALUES (last_alert_date, substr(last_alert_text, 1, ~~alert_length) || '<b> (message repeated ' || rows_identical || ' times this day</b>)');
          rows_identical := 1;
        ELSE
          INSERT INTO alert_log VALUES (last_alert_date, substr(last_alert_text, 1, ~~alert_length));
        END IF;
      END IF;
--      rows_inserted := rows_inserted + 1;
      commit;
      last_alert_text := alert_text;
      last_alert_date := alert_date;
    END IF;
  END loop;
  commit;
end;
/

-- TODO : détecter les messages en doublon et les compter
-- la méthode actuelle avec le "IF r.text not like.." ne fonctionne pas, car il faudrait que les messages d'un même jour soient consécutifs
-- or, d'autres messages peuvent s'intercaler, cassant le comptage, même si lesdits messages ne sont pas affichés ensuite.
-- utiliser un curseur après la boucle FOR qui remplit la table et avant l'affichage. Compter les occurences d'un même jour, puis si > 1 supprimer tout sauf 1 du même jour et mettre à jour cette ligne avec le comptage.
-- 1. curseur sur les jours uniques
-- 2. curseur imbriqué sur 1 jour en particulier, garder la date et texte de l'occurrence 1 pour plus tard, compter les occurences (par rapport à des texte prédéfinis comme chekpoint, etc.)
-- 3. supprimer les occurences de ce jour sauf la 1 (par rapport à date et heure)
-- 4. Mettre à jour la 1 avec le comptage
-- NOTE : CA NE RESOUD PAS LE PROBLEME ORA-01653 SI TROP DE MESSAGES !!

/*
table external alert_log_disk
curseur sur alert_log_disk
compter les lignes identiques un même jour
 1 jours uniques
 2 imbriqué sur jour, compter lignes identiques checkpoint, etc
PROBLEME ICI : LA DATE N'EST PAS SUR LA LIGNE ELLE-MEME ! Peut-on reconstruire une table de plus avec 2 col date+text (date ajoutée à chaque ligne de text), en évitant ORA-01653 ?

garder date 1ere occurence et date de fin
---> on ne peut pas modifier alert_log_disk car c'est le fichier ! => créer un 3eme table pour les garder ?
LE ROWID EXISTE AUSSI SUR L'EXTERNAL TABLE
on peut donc créer une table temporaire qui contient date + rowid

1ere passe pour repérer les lignes de date avec leur rowid, on garde dates unique + rowid
ensuite on peut selectionner les lignes entre rowid date 1 et rowid date 2 (en s'arrêtant au jour)
select rowid,text from alert_log_disk where rowid > '(AAFFFwAAAAAAAAAAAAsVAg' and rowid < '(AAFFFwAAAAAAAAAAAAsVaQ';

sur cette sélection, on compte les lignes identiques selon textes préétablis (checkpoint, tns...)
en gardant date début et date fin

remplir alert_log avec alert_log_disk ligne à ligne, sauf textes comptés ci-dessus
check date : si date différente de date - 1 (changement de jour), chercher date dans 3eme table et l'insérer, puis charger les autres lignes de cette date
*/

-- Exemple curseur :
/*
 declare
   total_val number(6);
   cursor c1 is
     SELECT monthly_income
     FROM employees
     WHERE name = name_in;

 BEGIN
   total_val := 0;
   FOR employee_rec in c1
   LOOP
      total_val := total_val + employee_rec.monthly_income;
   END LOOP;
   RETURN total_val;
 END;
*/

-- ************************************ Affichage des logs
prompt <!-- Affichage des logs -->
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="Messages d'erreurs depuis le dernier audit. Si des messages sont affich&eacute;s, voir le d&eacute;tail dans le fichier alert<SID>.log, ou la table ALERT_LOG (r&eacute;sum&eacute;), ou la table externe ALERT_LOG_DISK (qui contient tout l'alert.log). En gras sont indiqu&eacute les lignes regroupant plusieurs messages cons&eacute;cutifs un m&ecirc;me jour."></td>
prompt <td align=center><font color="WHITE"><b>~sbdump</b><b>alert_~_db..log (

select to_char(round(~sbsize/1024/1024,2),'99G999G990D00') from dual;
prompt Mb)</b></font></td></tr></table></td></tr>
prompt <tr><td width=20%><b>Date</b></td><td width=80%><b>Texte</b></td></tr>

-- http://www.adp-gmbh.ch/ora/admin/scripts/read_alert_log.html
-- http://www.adp-gmbh.ch/ora/admin/read_alert/index.html
-- http://www.dba-oracle.com/t_writing_alert_log_message.htm

select '<tr>','<td bgcolor="LIGHTBLUE">',CASE WHEN a.alert_text LIKE '%<b> (message repeated %' THEN '<b>'||to_char(a.alert_date,'DD/MM/RR HH24:MI')||'</b>' ELSE to_char(a.alert_date,'DD/MM/RR HH24:MI') END,'</td>', '<td bgcolor="LIGHTBLUE">',a.alert_text,'</td>','</tr>'
  from alert_log a
--       (select max(to_date(date_aud)) date_aud from ~tblhist
--                where to_date(date_aud) < trunc(sysdate)) d
 where (alert_text like '%ORA-%'
  or alert_text like '%TNS-%'
  or LOWER(alert_text) like '%checkpoint not complete%'
  or LOWER(alert_text) like '%create%' or LOWER(alert_text) like '%drop%' or LOWER(alert_text) like '%alter%'
  or LOWER(alert_text) like 'shutdown%' or LOWER(alert_text) like 'shutting down instance%')
--  and a.alert_date > d.date_aud
order by a.alert_date;

DECLARE cnt_obj number := 0;
BEGIN
   select count(a.alert_date) into cnt_obj
   from alert_log a
--        (select max(to_date(date_aud)) date_aud from ~tblhist
--               where to_date(date_aud) < trunc(sysdate)) d
   where (alert_text like '%ORA-%'
     or alert_text like '%TNS-%'
     or LOWER(alert_text) like '%checkpoint not complete%'
     or LOWER(alert_text) like '%create%' or LOWER(alert_text) like '%drop%' or LOWER(alert_text) like '%alter%'
     or LOWER(alert_text) like '%shutdown%' or LOWER(alert_text) like '%shutting down%')
;
--     and a.alert_date > d.date_aud;

   if cnt_obj=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** Cleaning of tables alert_log*
prompt <!-- Nettoyage tables alert_log* -->
DECLARE
   table_exist number;
BEGIN
   EXECUTE IMMEDIATE 'drop table alert_log';
   EXECUTE IMMEDIATE 'drop table alert_log_disk';
END;
/

-- ****************** SECTION SCHEMAS - INFORMATIONS GLOBALES *************************
prompt <hr>
prompt <div align=center><b><font color="WHITE">SECTION SCHEMAS</font></b></div>
prompt <hr>

-- *************************************** Objets invalides
prompt <!-- Objets invalides -->
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4><font color="WHITE"><b>Objets invalides</b></font></td></tr>
prompt <tr><td width=15%><b>Propri&eacute;taire</b></td><td width=15%><b>Objet</b></td><td width=15%><b>Type</b></td><td width=15%><b>Statut</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',OWNER,'</td>','<td bgcolor="LIGHTBLUE">',object_name,'</td>','<td bgcolor="LIGHTBLUE">',object_type,'</td>','<td bgcolor="LIGHTBLUE">',status,'</td>','</tr>' from dba_objects where status <> 'VALID' and object_name not like 'BIN$%';

DECLARE cnt_obj number := 0;
BEGIN
   select count(object_name) into cnt_obj from dba_objects
   where status <> 'VALID'
   and rownum = 1;
   if cnt_obj=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** Objets en erreur
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>Erreurs sur les objets utilisateurs (dba_errors)</b></font></td></tr>
prompt <tr><td><b>Objet, num&eacute;ro et texte de la ligne</b></td><td><b>Erreur</b></td></tr>

with err as (
   select distinct owner, name, type, line, position, sequence, substr(TRIM(text),0,240) as text
   from
      dba_errors
   where sequence=1
   and name not like 'BIN$%'
)
SELECT decode(n,-1,'<tr><td bgcolor="LIGHTBLUE">',''),text
  from (
      select sequence n, owner,name, type,line, (position-1)||'</td><td bgcolor="LIGHTBLUE">'||text||'</td></tr>' text -- Num erreur PL/SQL
        from err
      union all
      select distinct -1 n, owner, name, type, line, '<b>'||type||' '||owner||'.'||name||' line '||line||'</b><br/>' --Num ligne
        from err
      union all
      select 0 n, owner, name, type, line, '"'||substr(TRIM(text),0,240)||'" : pos. ' -- code PL/SQL
        from dba_source
      where (owner,name,type,line) in (select owner, name, type, line from err)
      order by owner,name, type,line, n
);

DECLARE cnt_err number := 0;
BEGIN
with err as (
   select distinct owner, name, type, line, position, sequence, substr(TRIM(text),0,240) as text
   from
      dba_errors
   where sequence=1
)
SELECT count(n) into cnt_err
  from (
      select sequence n, owner,name, type,line, (position-1)||'</td><td bgcolor="LIGHTBLUE">'||text||'</td></tr>' text -- Num erreur PL/SQL
        from err
      union all
      select distinct -1 n, owner, name, type, line, '<b>'||type||' '||owner||'.'||name||' line '||line||'</b><br/>' --Num ligne
        from err
      union all
      select 0 n, owner, name, type, line, '"'||substr(TRIM(text),0,240)||'"&nbsp;:&nbsp;' -- code PL/SQL
        from dba_source
      where (owner,name,type,line) in (select owner, name, type, line from err)
);
   if cnt_err=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY colspan=2><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** Indexes UNUSABLE
prompt <!-- Indexes unusable -->
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Indexes UNUSABLE</b></font></td></tr>
prompt <tr><td width=15%><b>Propri&eacute;taire</b></td><td width=15%><b>Index</b></td><td width=15%><b>Statut</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',OWNER,'</td>','<td bgcolor="LIGHTBLUE">',index_name,'</td>','<td bgcolor="LIGHTBLUE">',status,'</td>','</tr>' from dba_indexes where status not in ('VALID','N/A');

DECLARE cnt_obj number := 0;
BEGIN
   select count(index_name) into cnt_obj from dba_indexes
   where status not in ('VALID','N/A')
   and rownum = 1;
   if cnt_obj=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** Liste des segments de plus de 100M
prompt <!-- Segments de plus de 100M -->
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=4>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="L'espace utilis&eacute; correspond aux blocs allou&eacute;s au segment, qu'ils soient vides (pr&eacute;allocation de blocs ou suppressions de donn&eacute;es) ou remplis."></td>
prompt <td align=center><font color="WHITE"><b>Liste des segments de plus de 100Mo</b></font></td></tr></table></td></tr>
prompt <tr><td width=15%><b>Propri&eacute;taire</b></td><td width=15%><b>Segment</b></td><td width=15%><b>Type</b></td><td width=15%><b>Taille</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',owner,'</td>', '<td bgcolor="LIGHTBLUE">',segment_name,'</td>', '<td bgcolor="LIGHTBLUE">',segment_type,'</td>', '<td bgcolor="LIGHTBLUE" align=right>',to_char(round(bytes/(1024*1024),0),'99G999G990'),' Mo</td>','</tr>'
from dba_segments
where (segment_type like 'TABLE%' OR segment_type like 'INDEX%' OR segment_type like 'LOB%')
and bytes/1024/1024 >100 
and owner not in ~sysusers and owner not in ~exusers
order by bytes desc;

DECLARE cnt_obj number := 0;
BEGIN
   select count(segment_name) into cnt_obj from dba_segments
   where (segment_type like 'TABLE%' OR segment_type like 'INDEX%' OR segment_type like 'LOB%')
   and bytes/1024/1024 >100 
   and owner not in ~sysusers and owner not in ~exusers
   and rownum = 1;

   if cnt_obj=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- utilisateurs et tablespaces par defaut
-- **************************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>utilisateurs et tablespaces par d&eacute;faut</b></font></td></tr>
prompt <tr><td><b>Utilisateurs</b></td><td><b>Tablespace par d&eacute;faut</b></td><td><b>Tablespace temporaire</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',username,'</td>','<td bgcolor="LIGHTBLUE">',default_tablespace,'</td>', '<td bgcolor="LIGHTBLUE">',temporary_tablespace,'</td>','</tr>'
from dba_users
order by username;

prompt </table><br>


-- Liste des utilisateurs systemes non listes dans les variables sysusers et exusers
-- ********************************
prompt <table border=1 width=100% bgcolor="WHITE">

prompt <tr><td bgcolor="#3399CC" align=center colspan=2>
prompt <table border=0 width=100%><tr><td width=10%>&nbsp;&nbsp;<img src="data:image/gif;base64,
print info
prompt " width="20" height="20" alt="Info..." title="Les variables sysusers et exusers listent les utilisateurs syst&egrave;mes Oracle, afin de les &eacute;liminer des requ&ecirc;tes qui ne doivent prendre en compte que les sch&eacute;mas applicatifs. Ici sont list&eacute;s pour information les utilisateurs qui ne sont pas inclus dans ces variables, afin de rep&eacute;rer ceux qui devraient y &ecirc;tre ajout&eacute;s."></td>
prompt <td align=center><font color="WHITE"><b>Information : Liste des utilisateurs non syst&egrave;mes</b></font></td></tr></table></td></tr>
prompt <tr><td><b>Utilisateur</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',username,'</td>','</tr>'
from dba_users
where username not in ~sysusers and username not in ~exusers;

prompt </table><br>

-- *************************************** Utilisateurs ayant des objets dans le tablespace SYSTEM
prompt <!-- Segments utilisateurs dans le tablespace SYSTEM -->
-- Tables
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Utilisateurs ayant des objets dans le tablespace SYSTEM</b></font></td></tr>
prompt <tr><td width=15%><b>Propri&eacute;taire</b></td><td width=15%><b>Type</b></td><td width=15%><b>Segment</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',owner,'</td>', '<td bgcolor="LIGHTBLUE">Tables</td>','<td bgcolor="LIGHTBLUE">',count(*),'</td>','</tr>' TOTAL from dba_tables
	where tablespace_name = 'SYSTEM'
	and owner not in ~sysusers and owner not in ~exusers
	group by owner;
-- Indexes
select '<tr>','<td bgcolor="LIGHTBLUE">',owner,'</td>', '<td bgcolor="LIGHTBLUE">Indexes</td>','<td bgcolor="LIGHTBLUE">',count(*),'</td>','</tr>' TOTAL from dba_indexes
	where tablespace_name = 'SYSTEM'
	and owner not in ~sysusers and owner not in ~exusers
	group by owner;

DECLARE
    cnt_obj_t number := 0;
    cnt_obj_i number := 0;
BEGIN
   select count(*) into cnt_obj_t from dba_tables
	where tablespace_name = 'SYSTEM'
	and owner not in ~sysusers and owner not in ~exusers
        and rownum = 1;
   select count(*) into cnt_obj_i from dba_indexes
	where tablespace_name = 'SYSTEM'
	and owner not in ~sysusers and owner not in ~exusers
        and rownum = 1;
   if cnt_obj_t=0 and cnt_obj_i=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- *************************************** Tables et index dans le meme tablespace
prompt <!-- Tables et index dans le meme tablespace -->
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=3><font color="WHITE"><b>Indexes dans le m&ecirc;me tablespace que leur table</b></font></td></tr>
prompt <tr><td width=15%><b>Propri&eacute;taire</b></td><td width=15%><b>Tablespace</b></td><td width=15%><b>Nombre d&#39;objets</b></td></tr>

select '<tr>','<td bgcolor="LIGHTBLUE">',a.owner,'</td>', '<td bgcolor="LIGHTBLUE">',a.tablespace_name,'</td>', '<td bgcolor="LIGHTBLUE">',count(a.table_name),'</td>','</tr>'
from dba_tables a, dba_indexes b
where a.tablespace_name=b.tablespace_name
and a.table_name=b.table_name
and a.owner=b.owner
and a.owner not in ~sysusers and a.owner not in ~exusers
group by a.owner,a.tablespace_name
order by a.owner,a.tablespace_name;

DECLARE cnt_obj number := 0;
BEGIN
   select count(b.index_name) into cnt_obj from dba_tables a, dba_indexes b
      where a.tablespace_name=b.tablespace_name
      and a.table_name=b.table_name
      and a.owner=b.owner
      and a.owner not in ~sysusers and a.owner not in ~exusers
      and rownum = 1;
   if cnt_obj=0  then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- Roles par utilisateurs non systemes
-- ***********************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=2><font color="WHITE"><b>R&ocirc;les par utilisateur (non syst&egrave;mes)</b></font></td></tr>
prompt <tr><td><b>Utilisateurs</b></td><td><b>R&ocirc;les</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',username,'</td>', decode(granted_role,NULL,'<td bgcolor="LIGHTGREY"><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td>','<td bgcolor="LIGHTBLUE">'||granted_role||'</td>') grole,'</tr>'
from dba_users, dba_role_privs
where username not in ~sysusers and username not in ~exusers
and username=grantee(+)
order by username,grole;

prompt </table><br>

-- Liste des schemas vides (aucun objets)
-- *************************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center><font color="WHITE"><b>Liste des sch&eacute;mas vides (aucun objet)</b></font></td></tr>
prompt <tr><td><b>Sch&eacute;mas vides</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',username,'</td>','</tr>' from dba_users
where username not in (select owner from dba_segments)
and username not in ~sysusers and username not in ~exusers;

DECLARE cnt_sch number;
BEGIN
   select count(username) into cnt_sch from dba_users
   where username not in (select owner from dba_segments)
and username not in ~sysusers and username not in ~exusers;
   if cnt_sch=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td></tr>');
   end if;
end;
/

prompt </table><br>

-- Nombres d'objets par schemas (hors schemas systemes)
-- ***************************************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Nombre d&#39;objets par sch&eacute;ma (non syst&egrave;mes)</b></font></td></tr>
prompt <tr><td><b>Utilisateur</b></td><td><b>Total</b></td><td><b>Tables</b></td><td><b>Indexes</b></td><td><b>Autres</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',t.owner,'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(t.total,NULL,0,t.total),'99G999G990'),'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(a.tables,NULL,0,a.tables),'99G999G990'),'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(i.indexes,NULL,0,i.indexes),'99G999G990'),'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(o.autres,NULL,0,o.autres),'99G999G990'),'</td>','</tr>'
from  (select owner, count(*) total
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      group by owner) t,
     (select owner, count(*) tables
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      and segment_type='TABLE'
      group by owner) a,
     (select owner, count(*) indexes
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      and segment_type='INDEX'
      group by owner) i,
     (select owner, count(*) autres
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      and segment_type not in ('TABLE','INDEX')
      group by owner) o
where t.owner=a.owner(+) and t.owner=i.owner(+) and t.owner=o.owner(+);

prompt </table><br>

-- Taille utilisee par les schemas (hors schemas systemes)
-- *******************************************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Taille utilis&eacute;e par les sch&eacute;mas (non syst&egrave;mes)</b></font></td></tr>
prompt <tr><td><b>Utilisateur</b></td><td><b>Total (Mo)</b></td><td><b>Tables (Mo)</b></td><td><b>Indexes (Mo)</b></td><td><b>Autres (Mo)</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',t.owner,'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(t.total,NULL,0,t.total),'99G999G990D00'),'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(a.tables,NULL,0,a.tables),'99G999G990D00'),'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(i.indexes,NULL,0,i.indexes),'99G999G990D00'),'</td>',
'<td bgcolor="LIGHTBLUE" align=right>',to_char(decode(o.autres,NULL,0,o.autres),'99G999G990D00'),'</td>','</tr>'
from  (select owner, round(sum(bytes)/(1024*1024),2) total
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      group by owner) t,
     (select owner, round(sum(bytes)/(1024*1024),2) tables
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      and segment_type='TABLE'
      group by owner) a,
     (select owner, round(sum(bytes)/(1024*1024),2) indexes
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      and segment_type='INDEX'
      group by owner) i,
     (select owner, round(sum(bytes)/(1024*1024),2) autres
      from dba_segments
      where owner not in ~sysusers and owner not in ~exusers
      and segment_type not in ('TABLE','INDEX')
      group by owner) o
where t.owner=a.owner(+) and t.owner=i.owner(+) and t.owner=o.owner(+);

prompt </table><br>

-- Liste des liens de bases de donn&eacute;es
-- ***********************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Liste des liens de bases de donn&eacute;es</b></font></td></tr>
prompt <tr><td><b>Utilisateur</b></td><td><b>DB Link</b></td><td><b>Utilisateur distant</b></td><td><b>Serveur</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',owner,'</td>','<td bgcolor="LIGHTBLUE">',DB_LINK,'</td>','<td bgcolor="LIGHTBLUE">',USERNAME,'</td>',
       '<td bgcolor="LIGHTBLUE">',HOST,'</td>','</tr>'
from dba_db_links
order by OWNER,DB_LINK;

DECLARE cnt_dbl number;
BEGIN
   select count(owner) into cnt_dbl from dba_db_links;
   if cnt_dbl=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>

-- Liste des synonymes non systemes
-- ********************************
prompt <table border=1 width=100% bgcolor="WHITE">
prompt <tr><td bgcolor="#3399CC" align=center colspan=5><font color="WHITE"><b>Liste des synonymes (non syst&egrave;mes)</b></font></td></tr>
prompt <tr><td><b>Utilisateur</b></td><td><b>Synonyme</b></td><td><b>Propri&eacute;taire</b></td><td><b>Objet cible</b></td></tr>
prompt 

select '<tr>','<td bgcolor="LIGHTBLUE">',owner,'</td>', '<td bgcolor="LIGHTBLUE">',synonym_name,'</td>', '<td bgcolor="LIGHTBLUE">',table_owner,'</td>',
       '<td bgcolor="LIGHTBLUE">',table_name,'</td>','</tr>'
from dba_synonyms
where table_owner not in ~sysusers and table_owner not in ~exusers and ROWNUM <= 5000;

DECLARE cnt_syn number;
BEGIN
   select count(owner) into cnt_syn from dba_synonyms
where table_owner not in ~sysusers and table_owner not in ~exusers;
   if cnt_syn=0 then
      dbms_output.put_line('<tr><td bgcolor=LIGHTGREY><img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" width=20></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td><td bgcolor=LIGHTGREY></td></tr>');
   end if;
end;
/

prompt </table><br>
prompt </body>
prompt </html>

spool off
exit
