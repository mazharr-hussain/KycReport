--------------------------------------------------------------------------------
-- Step 6.1b, run as ADMIN, validation database only (H1): gives the test users' APEX accounts this run's random
-- password, not changed at first sign-in and unlocked. db/admin/test-users.sql gives them a fixed password that is
-- in git; the validation application is reachable from the internet, so the pipeline never leaves that one in place.
-- (For live tests by a person: run db/admin/test-users.sql again - it sets the fixed password.)
-- Substitution variables: workspace, users (space separated), pw.
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
begin
    apex_util.set_workspace('&workspace');
    for u in (select column_value as user_name from table(apex_string.split(trim('&users'), ' '))
               where column_value is not null) loop
        if apex_util.get_user_id(u.user_name) is not null then
            apex_util.edit_user(p_user_id => apex_util.get_user_id(u.user_name), p_user_name => u.user_name,
                p_first_name => u.user_name, p_web_password => '&pw', p_new_password => '&pw',
                p_account_locked => 'N', p_failed_access_attempts => 0,
                p_change_password_on_first_use => 'N', p_first_password_use_occurred => 'Y');
        end if;
    end loop;
    commit;
    dbms_output.put_line('test users: password of this run set');
end;
/
