-- COMMON test fixture (pipeline 6.2 runs it first, as XXFUSION, after 01_r86_test_apps.sql made the empty APEX test
-- applications). COMMON is tested on its own, without any business application (I-059, #217):
--   - the test application R86TEST (APEX application 860), registered through the onboarding routine
--   - the tests' administrator ADMIN: the APEX session user of the tests that need one (users, data security, menu,
--     workflow); Common Administrator and Super Administrator, given through COMMON's routine (BOOTSTRAP_ADMIN) like
--     the test user TALL_ACCESS of db/admin/test-users.sql
--   - (the local user TEST1: 04_test1_user.sql, as ADMIN - APEX accounts outside a browser need APEX admin rights)
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
    -- a document entity and a text category of the test application for the attachment tests (r81): the tests do not
    -- depend on whatever setup earlier runs left (I-059)
    xxfnd_attach_pkg.register_entity('R86TEST', 'R86_DOC_TEST', 'R89_PARENT', 'PARENT_ID', 'R86 test documents');
    xxfnd_attach_pkg.register_category('R86TEST', 'R86_NOTE', 'R86 test note', p_default_datatype_code => 'SHORT_TEXT');
    -- the tests' administrator
    xxfnd_user_pkg.bootstrap_admin('ADMIN', 'Test Administrator', 'admin@example.com', 'COMMON_ADMIN');
    xxfnd_user_pkg.bootstrap_admin('ADMIN', 'Test Administrator', 'admin@example.com', 'SUPER_ADMIN');
    commit;
    commit;
    dbms_output.put_line('COMMON test fixture ready: R86TEST (with document entity R86_DOC_TEST, category R86_NOTE), ADMIN');
end;
/
