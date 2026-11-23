-- COMMON test fixture (run as XXFUSION, after apex/tests/r86_test_apps.sql made the empty APEX test applications):
-- COMMON is tested on its own, without any business application. The tests of the earlier releases need one
-- registered application (its roles, an RFI category): the test application R86TEST (APEX application 860) is
-- registered through the onboarding routine and gets the RFI categories through the registration routine.
-- Also the local user TEST1. Re-runnable (only what is missing is added); its rows stay.
set serveroutput on feedback off
declare
    l_app number;
begin
    select max(application_id) into l_app from apex_applications where application_id = 860;
    if l_app is null then
        raise_application_error(-20000, 'Run apex/tests/r86_test_apps.sql (as XXCUS) first: APEX application 860 is missing.');
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
    -- a plain local user for the security screens' tests (TEST1); its APEX account may exist from an earlier database
    select count(*) into l_app from xxfnd_users where user_name = 'TEST1';
    if l_app = 0 then
        select count(*) into l_app from apex_workspace_apex_users where user_name = 'TEST1';
        if l_app = 0 then
            apex_util.set_workspace('XXCUS');
            apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');
            l_app := xxfnd_user_pkg.create_local_user('TEST1', 'Test User 1', 'test1@example.com', 'KycTest#2026');
        else
            insert into xxfnd_users (user_name, user_type, full_name, email_address)
            values ('TEST1', 'LOCAL', 'Test User 1', 'test1@example.com');
        end if;
    end if;
    commit;
    dbms_output.put_line('COMMON test fixture ready: R86TEST, TEST1');
end;
/
