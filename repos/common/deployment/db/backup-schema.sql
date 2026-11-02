--------------------------------------------------------------------------------
-- Step 5.3, run as the pipeline user: the backup schema of the upgrade test (validation database only).
--   5.3.1 drop it if it exists   5.3.2 create it (no password: reachable only by proxy)   5.3.3 grant what it needs
-- Step 7.7 runs the same script with drop_only = Y: the backup schema is dropped and not created again.
-- Substitution variables: bkp_schema, ci_user, drop_only (Y/N).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_schema constant varchar2(128) := dbms_assert.simple_sql_name(upper('&bkp_schema'));
    l_n      pls_integer;
begin
    if l_schema not like '%\_BKP' escape '\' then
        raise_application_error(-20001, 'Refused: ' || l_schema || ' is not a backup schema (name must end with _BKP).');
    end if;
    select count(*) into l_n from all_users where username = l_schema;
    if l_n > 0 then
        execute immediate 'drop user ' || l_schema || ' cascade';
        dbms_output.put_line('dropped ' || l_schema);
    end if;
    if upper('&drop_only') = 'Y' then
        return;
    end if;
    execute immediate 'create user ' || l_schema || ' no authentication default tablespace data quota unlimited on data';
    execute immediate 'grant create session, create table to ' || l_schema;
    execute immediate 'alter user ' || l_schema || ' grant connect through '
        || dbms_assert.simple_sql_name(upper('&ci_user'));
    dbms_output.put_line('created ' || l_schema);
end;
/
