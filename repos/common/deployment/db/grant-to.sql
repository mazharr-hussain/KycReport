--------------------------------------------------------------------------------
-- Upgrade test helper, run as a table owner (the application schema or its backup schema, by proxy): grants SELECT
-- on the owner's data tables to another schema, so the backup can copy them (6.0) and the restore / compare can read
-- the backup (7.3, 7.5). Validation database only. Substitution variable: grantee.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_grantee constant varchar2(128) := dbms_assert.simple_sql_name(upper('&grantee'));
    l_n       pls_integer := 0;
begin
    for t in (select table_name from user_tables
               where temporary = 'N' and nested = 'NO' and secondary = 'N' and external = 'NO'
                 and nvl(iot_type, 'IOT') = 'IOT' and dropped = 'NO'
                 and table_name not like 'BIN$%' and table_name not like 'SYS\_%' escape '\'
                 and table_name not like 'DR$%' and table_name not like 'MLOG$%' and table_name not like 'AQ$%') loop
        execute immediate 'grant select on "' || t.table_name || '" to ' || l_grantee;
        l_n := l_n + 1;
    end loop;
    dbms_output.put_line(user || ': select on ' || l_n || ' table(s) granted to ' || l_grantee);
end;
/
