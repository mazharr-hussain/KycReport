--------------------------------------------------------------------------------
-- Step 4.1 (full fresh install), run as ADMIN, validation database only: removes the APEX accounts of the test users.
-- Clearing the schema removes COMMON's user rows, but an APEX account lives in the workspace and survives it - the
-- test users would then be made again over an existing account (ORA-00001 on WWV_FLOW_FND_USER_UQ1). The names come
-- from db/admin/test-users.sql and the tests (db/run.sh). Substitution variables: workspace, users (space separated).
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
begin
    apex_util.set_workspace('&workspace');
    for u in (select column_value as user_name from table(apex_string.split(trim('&users'), ' '))
               where column_value is not null) loop
        if apex_util.get_user_id(u.user_name) is not null then
            apex_util.remove_user(p_user_name => u.user_name);
            dbms_output.put_line('removed APEX account ' || u.user_name);
        end if;
    end loop;
    commit;
end;
/
