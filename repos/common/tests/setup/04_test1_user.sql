-- COMMON test fixture, part 2 (pipeline 6.2 runs it after 03_common_test_fixture.sql) - the local user TEST1 for the
-- Schema: ADMIN
-- security screens' tests. Run as ADMIN in COMMON's schema: creating an APEX account outside a browser needs APEX
-- admin rights (like the test users of step 6.1, db/admin/test-users.sql); the user is made through COMMON's routine
-- in an APEX session of the tests' administrator ADMIN. Re-runnable; its rows stay.
alter session set current_schema = XXFUSION;
set serveroutput on feedback off
declare
    l_n number;
begin
    select count(*) into l_n from xxfnd_users where user_name = 'TEST1';
    if l_n = 0 then
        apex_util.set_workspace('XXCUS');
        apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');
        l_n := xxfnd_user_pkg.create_local_user('TEST1', 'Test User 1', 'test1@example.com', 'KycTest#2026');
        apex_session.delete_session;
        commit;
    end if;
    dbms_output.put_line('COMMON test user ready: TEST1');
end;
/
