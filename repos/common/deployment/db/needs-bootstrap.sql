--------------------------------------------------------------------------------
-- Step 5.2 check, run as the pipeline user: is the validation environment complete?
-- Prints "BOOTSTRAP OK" or one "BOOTSTRAP NEEDED: <reason>" line per missing piece; changes nothing.
-- (A failed login as the pipeline user also means bootstrap is needed - db/run.sh handles that.)
-- Substitution variables: app_schema, workspace.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    l_missing pls_integer := 0;
    l_n       pls_integer;
    procedure need(p_reason varchar2) is
    begin
        dbms_output.put_line('BOOTSTRAP NEEDED: ' || p_reason);
        l_missing := l_missing + 1;
    end need;
begin
    for u in (select column_value as username from table(sys.odcivarchar2list('&workspace', '&app_schema'))) loop
        select count(*) into l_n from all_users where username = u.username;
        if l_n = 0 then
            need('user ' || u.username || ' is missing');
        end if;
    end loop;
    select count(*) into l_n from session_roles where role = 'APEX_ADMINISTRATOR_ROLE';
    if l_n = 0 then
        need('the pipeline user has no APEX_ADMINISTRATOR_ROLE');
    end if;
    select count(*) into l_n from user_sys_privs where privilege in ('CREATE USER', 'ALTER USER', 'DROP USER');
    if l_n < 3 then
        need('the pipeline user is missing CREATE / ALTER / DROP USER');
    end if;
    select count(*) into l_n from apex_workspaces where workspace = '&workspace';
    if l_n = 0 then
        need('workspace &workspace is missing');
    end if;
    select count(*) into l_n from apex_workspace_schemas where workspace_name = '&workspace' and schema = '&app_schema';
    if l_n = 0 then
        need('schema &app_schema is not in workspace &workspace');
    end if;
    if l_missing = 0 then
        dbms_output.put_line('BOOTSTRAP OK');
    end if;
end;
/
