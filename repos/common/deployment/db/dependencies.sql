--------------------------------------------------------------------------------
-- Step 4.4, run as the application schema (proxy) after the fresh deploy: writes the schema's own object
-- dependencies (USER_DEPENDENCIES, objects of this schema only) as CSV, for db/compare_dependencies.py.
-- Substitution variable: out (CSV file).
--------------------------------------------------------------------------------
set define on verify off feedback off heading on pagesize 0 termout off
set sqlformat csv
spool &out
select lower(d.name) as name, lower(d.type) as type, lower(d.referenced_name) as referenced_name,
       lower(d.referenced_type) as referenced_type
  from user_dependencies d
 where d.referenced_owner = user
   and d.name <> d.referenced_name
   and d.name not like 'BIN$%' and d.name not like 'SYS\_%' escape '\'
   and d.referenced_name not like 'ISEQ$$%' and d.referenced_name not like 'SYS\_%' escape '\'
 order by 1, 3;
spool off
set termout on
