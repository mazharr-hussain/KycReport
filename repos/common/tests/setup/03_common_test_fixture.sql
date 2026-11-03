-- COMMON test fixture (pipeline 6.2 runs it first, as XXFUSION, after 01_r86_test_apps.sql made the empty APEX test
-- applications). COMMON is tested on its own, without any business application (I-059, #217):
--   - the test application R86TEST (APEX application 860), registered through the onboarding routine
--   - the tests' administrator ADMIN: the APEX session user of the tests that need one (users, data security, menu,
--     workflow); Common Administrator and Super Administrator, given through COMMON's routine (BOOTSTRAP_ADMIN) like
--     the test user TALL_ACCESS of db/admin/test-users.sql
--   - the local user TEST1 for the security screens' tests
--   - tables R89_* left in XXFUSION by an earlier run of the R89 setup as the wrong schema are dropped (they belong
--     to the test application's schema XXCUS, 02_r89_data_model_apps.sql)
-- Re-runnable (only what is missing is added); its rows stay.
set serveroutput on feedback off
declare
    l_app number;
begin
    for t in (select table_name from user_tables where table_name in ('R89_CHILD', 'R89_PARENT') order by table_name) loop
        execute immediate 'drop table ' || dbms_assert.simple_sql_name(t.table_name) || ' purge';
        dbms_output.put_line('dropped ' || t.table_name || ' (belongs to XXCUS)');
    end loop;
    select max(application_id) into l_app from apex_applications where application_id = 860;
    if l_app is null then
        raise_application_error(-20000, 'APEX application 860 is missing: tests/setup/01_r86_test_apps.sql did not run.');
    end if;
    xxfnd_application_pkg.onboard(p_apex_application_id => 860, p_application_code => 'R86TEST',
                                  p_description => 'COMMON test application (release 86 tests).');
    -- only where no application has RFI categories yet (an upgraded database keeps its own)
    select count(*) into l_app from xxfnd_lookup_types where lookup_type = 'RFI_CATEGORY';
    if l_app = 0 then
        xxfnd_lookup_pkg.register_lookup_type('R86TEST', 'RFI_CATEGORY', 'RFI Categories');
        xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'RFI_CATEGORY', 'CLARIFICATION', 'Clarification', 10);
        xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'RFI_CATEGORY', 'OTHER', 'Other', 20);
    end if;
    -- the tests' administrator
    xxfnd_user_pkg.bootstrap_admin('ADMIN', 'Test Administrator', 'admin@example.com', 'COMMON_ADMIN');
    xxfnd_user_pkg.bootstrap_admin('ADMIN', 'Test Administrator', 'admin@example.com', 'SUPER_ADMIN');
    commit;
    -- a plain local user for the security screens' tests (TEST1), made by the administrator; its APEX account may
    -- exist from an earlier database
    select count(*) into l_app from xxfnd_users where user_name = 'TEST1';
    if l_app = 0 then
        apex_util.set_workspace('XXCUS');
        apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');
        select count(*) into l_app from apex_workspace_apex_users where user_name = 'TEST1';
        if l_app = 0 then
            l_app := xxfnd_user_pkg.create_local_user('TEST1', 'Test User 1', 'test1@example.com', 'KycTest#2026');
        else
            insert into xxfnd_users (user_name, user_type, full_name, email_address)
            values ('TEST1', 'LOCAL', 'Test User 1', 'test1@example.com');
        end if;
        apex_session.delete_session;
    end if;
    commit;
    dbms_output.put_line('COMMON test fixture ready: R86TEST, ADMIN, TEST1');
end;
/
