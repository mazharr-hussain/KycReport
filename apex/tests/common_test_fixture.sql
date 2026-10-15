-- COMMON test fixture (run as XXFUSION, after apex/tests/r86_test_apps.sql made the empty APEX test applications):
-- COMMON is tested on its own, without any business application. The tests of the earlier releases need one
-- registered application (its roles, an RFI category): the test application R86TEST (APEX application 860) is
-- registered through the onboarding routine and gets the RFI categories through the registration routine.
-- Re-runnable (both routines add only what is missing); its rows stay.
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
    commit;
    dbms_output.put_line('COMMON test fixture ready: R86TEST');
end;
/
