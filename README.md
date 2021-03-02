# auditOracleHTML
Script for generating an Oracle (10g+) audit report of performances in HTML
----------------------------------
Freely inspired from internet tips, informations, shares, scripts.

This script has been evolving since I checked Oracle databases. As a good geek, I spent a lot of time to instruct the machine to do what I repetitively manually did since the beginning.
It is/will be probably not/never finished.

All ideas, contributions, propositions, fixes, updates, are welcome.

It is provided as is, use it at your own risks - but I use it since years on production databases without issues. I've never identified any overload when using it in production.

For a wider understanding, I'll translate parts from french to english, step by step. Help will be welcome. Note that a TODO task consist in creating a (or using an existing) system to propose different languages for titles and texts.

----------------------------------
# USAGE
* IMPORTANT : this script must be executed under sqlplus, as SYSTEM
  If SYSTEM access is not permitted, it needs to be executed by a user with at least this privileges (execute this as SYS) :
```
    CREATE USER MyAuditUser IDENTIFIED BY "password";
    ALTER USER MyAuditUser DEFAULT TABLESPACE TOOLS;
    ALTER USER MyAuditUser QUOTA UNLIMITED ON TOOLS;
    GRANT CONNECT, SELECT ANY DICTIONARY, CREATE ANY DIRECTORY TO MyAuditUser;
    GRANT EXECUTE ON sys.dbms_system TO MyAuditUser;
```
* The script produces an HTML file called "ORACLE_<SID>_<hostname>_<date>.html

* IMPORTANT : it's better (in fact, actually mandatory) if an extra tablespace (called "TOOLS" by default) exists in the database for a table of audit history. If not, the table can be created in tablespace SYSTEM (but the user must have write right).
If you want to change this tablespace name, you must change the "tbstools" constante at the beginning of the script.

* TNS :
```
 sqlplus -S system/manager@ORCL @/script_directory/audit_oracle_html.sql
```
* Easyconnect :
```
 sqlplus -S system/manager@//server_oracle:1521/ORCL @/script_directory/audit_oracle_html.sql
```
"-S" = silently

* Example, under linux, with variables et Easyconnect :
```
 SQLP=/usr/lib/oracle/xe/app/oracle/product/10.2.0/client/scripts/sqlplus.sh
 AUDIT_SCRIPT=/scripts/Audit_Oracle/audit_complet_html
 CONNEXION='//server_oracle:1521/ORCL'
 $SQLP system/manager@$CONNEXION @$AUDIT_SCRIPT
```

* Sample script sqlplus.sh adapted for linux (UTF8 et line breaks), needs the rlwrap tool
```
     #!/bin/bash
     export LD_LIBRARY_PATH=/<rép. Oracle Client>/OraHome_1
     export ORACLE_HOME=/<rép. Oracle Client>/OraHome_1
     export EDITOR=vi
     NLS_LANG=FRENCH_FRANCE.UTF8 rlwrap -m $ORACLE_HOME/bin/sqlplus $1 $2 $3 $4 $5
```

* Modifying history table name and its tablespace name
The audit history table name is set by default to HISTAUDIT. It is located by default in tablespace TOOLS.
The tablespace TOOLS is mandatory for creating the table, or the script stops with a proper error.
You can modify this default values on command line. Parameter 1 is the tablespace name, parameter 2 is the table name.
The table name is not necessary if you want to change only the tablespace name, but you MUST specify the tablespace name (param 1) if you want to change the table name (param 2).
Examples :
CREATE OR USE AN EXISTING TABLE HISTAUDIT IN AN EXISTING TABLESPACE TOOLS :
sqlplus -S system/manager@//server_oracle:1521/ORCL @/script_directory/audit_oracle_html.sql
CREATE OR USE AN EXISTING TABLE HISTAUDIT IN AN EXISTING TABLESPACE USERS :
sqlplus -S system/manager@//server_oracle:1521/ORCL @/script_directory/audit_oracle_html.sql USERS
CREATE OR USE AN EXISTING TABLE AUDITDATA IN AN EXISTING TABLESPACE TOOLS :
sqlplus -S system/manager@//server_oracle:1521/ORCL @/script_directory/audit_oracle_html.sql TOOLS AUDITDATA # "TOOLS" is required as param 1

----------------------
* Changelog :
* 2005 v.1.0 Creation du script, regroupement d'operations manuelles repetitives.
* Generation de rapports format TXT
* 12/2006 v1.1 Creation table HISTAUDIT et requetes associees pour comparaisons entre 2 audits
* 11/2008 v1.2 Separation en 2 fichiers 1=audit de perfs 2=environnement schemas
* 02/2009 v2.0 Modifications des requetes audits de perfs pour generer des fichiers HTML
* 02/2010 Affichage icones "info" et "tips" 
* 06/2010 Ajout scan de l'alert.log
* 08/2010 Passage section schemas en HTML
* 10/2010 Mise en paramètre des listes de USERS sysusers et exusers
* 11/2010 Ajout résultat NLS_PARAMETERS
* ... Petites modifs diverses non documentées pendant un certain temps ...
* 03/2013 v2.1 Ajout file efficiency
* 06/2013 file efficiency ne donne pas d'info pertinente. Remplace par detection des FULL SCANs
* 08/2013 Ajout vue V$SGAINFO plutôt que simplement V$SGA pour les bases >=10g
* 09/2013 Ajout moyenne temps entre 2 switchs redo logs. Le min et max ne donnent pas d'info pertinente.
* 06/2014 suppression stats UNDO (gestion automatique depuis 10g)
* 09/2014 v2.2 Regroupement tableaux volumetrie tablespaces et diff de tailles depuis dernier audit
* 12/2014 Prendre date du jour si premier audit (pas de date d'audit précédent) pour afficher les tableaux à zéro
* 12/2014 tablespace UNDO placé en fin de tableau volumétrie et suppression calcul diff taille depuis dernier audit
* 02/2015 ajout affichage dba_errors+dba_sources
* 04/2015 corr. bug histaudit type_obj='AUT' dupliqué si script lancé plusieurs fois.
* corr. bug "erreurs sur objet" limit champ dba_errors."text" à 240 car. pour concatenations.
* 07/2015 v3.0.1 affichage tablespace de la table HISTAUDIT (SYSTEM ou TOOLS)
* corr. bug div/0 si executions=0 dans v$sqlarea
* 08/2015 v3.0.2 affichage des valeurs de divers paramètres d'initialisation.
* corr. bug total segments (TABLE% et INDEX%). Incohérence entre les sommes conservées dans Histaudit et les tailles réelles.
* 09/2015 v3.0.3 ajout version et parametres d'init dans histaudit. Test si version ou paramètre a changé depuis dernier audit
* v3.0.4 corr bug affichage version; ajout liste des patchs appliqués
* 11/2015 v3.1 Nettoyage du code, suppression de lignes obsolètes, suppressions de concatenations par "||",
* correction bug "ORA-01489" dans l'affichage des objets en erreur.
* 11/2015 v3.1.1 Correction qques bugs d'affichage suite à suppression des "||"
* remplacement des "N/A" par bgcolor=LIGHTGREY + image blank
* 12/2015 v3.1.2 Amélioration affichage paramètres d'init modifiés : les nouveaux paramètre (non listés lors du précédent
* audit parce que valeur par défaut) n'étaient pas affichés.
* Correction bug affichage des champs vides LIGHTGREY
* 06/2016 v3.1.3 dans liste tablespaces colorisation nouveaux tablespaces créés entre deux audits
* 09/2016 v3.1.4 modification requête "requête les + gourmandes" : extraction des requête > 50 execution PUIS tri PUIS selection des 11 premières lignes (ROWNUM)
* 05/2017 v3.1.5 correction bug affichage pour nouveaux tablespaces créés (n'apparaissaient pas à cause erreur de jointure (+))
* 09/2017 v3.1.6 ajout stat buffer cache sur v$buffer_pool_statistics + affichage (calculs en "title")
* 10/2017 correction de quelques bugs d'affichage, notamment sur fichiers des tablespaces
* 11/2017 v3.1.7 total libre sur stats tablespaces calculé selon max total (=total avec les autoextent) plutôt que sur total actuel sur disque.
* 02/2018 v3.1.8 correction bug affichage stats tablespaces lorsqu'un tbs mélangeait fichier avec autoextend et fichiers sans autoextend
* 03/2018 v3.2 correction nouveau bug induit par patch 3.1.8, sur les totaux
* 05/2018 correction bug sur selection historique des fichiers de tablespaces (limité à date_aud - 1)
* 08/2018 ajout composants installés (DBA_REGISTRY)
* 08/2018 v3.3 utilisation de la compilation conditionnelle $IF $THEN $END pour augmenter la compatibilité 10g, 11g et >
* 09/2018 ajout des informations sur la Flash recovery area
* 2019-2020 some display and format improvements here and there.
* 10/2020 v3.4 script modification to be launched by a normal user instead of SYSTEM
* 11/2020 put tablespace name and table name in substitution variables for audit history table and tablespace
* 12/2020 added min/max/avg cpu usage
  replaced "&" as define character for whole script by "~", as "&" is used for HTML formatting
  some code cleaning
  added the ability to change the audit table name and its tablespace variable values on command line
  added some "title" info icons on calculated ratio columns
  display system environment variables
* 01/2021 v3.5 revision of the alert.log processing. Group same messages by day, and handle new date format for db version > 12.2
* 03/2021 v3.6 added soft and hard parse ratio for library cache from v$sysstat
