-- Releases 87 / 88 checks, part 1 of 3 (run as XXFUSION): the application menu, delegated links, REGISTER_RULE,
-- the UNREGISTER_* routines, the grants (no write access), RFI documents and deadlines, the self-onboarding switch.
-- Needs the APEX applications 860 (R86TEST) and 861 (R86DEL) of apex/tests/r86_test_apps.sql (run once as XXCUS).
-- Part 2 (r87_app_test.sql, as XXCUS) is the application's side; part 3 (r87_delete_test.sql, as XXFUSION) deletes
-- R86DEL with the setup it registered. Its rows stay (the user keeps test data): R86TEST and its R87_* rows.
set serveroutput on feedback off
declare
    l_n     number;
    l_txt   varchar2(4000);
    l_ts    timestamp with time zone;
    l_rfi   number;
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
    procedure expect_error(p_code in number, p_text in varchar2, p_block in varchar2) is
    begin
        execute immediate p_block;
        check_(false, p_text || ' (no error)');
    exception
        when others then
            check_(sqlcode = p_code, p_text || ' (' || sqlcode || case when sqlcode <> p_code then ' ' || sqlerrm end || ')');
    end expect_error;
begin
    apex_util.set_workspace('XXCUS');
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    xxfnd_application_pkg.onboard(860, 'R86TEST', 'Release 86 onboarding test', 'Y', 'ADMIN');
    commit;

    ---------------------------------------------------------------- 87: the application menu
    select count(*) into l_n from xxfnd_app_menu_entries
     where application_code = 'R86TEST' and entry_code in ('MY_TASKS', 'NOTIFICATIONS', 'SHARED_SETUP', 'GIVE_FEEDBACK')
       and made_by = 'COMMON';
    check_(l_n = 4, 'onboarding makes the default menu entries (' || l_n || ')');
    select count(*) into l_n from xxfnd_app_menu_entries where application_code = 'R86TEST' and target_type = 'MANAGED';
    check_(l_n > 0, 'one entry per common function (' || l_n || ')');
    select count(*) into l_n from xxfnd_app_menu_entries where application_code = 'COMMON';
    check_(l_n = 0, 'COMMON itself gets no menu entries');
    xxfnd_application_pkg.save_menu_entry('R86TEST', 'MY_TASKS', 'My Work', 5, 'fa-inbox', 'Y');
    xxfnd_application_pkg.ensure_menu('R86TEST');
    commit;
    select max(label) into l_txt from xxfnd_app_menu_entries where application_code = 'R86TEST' and entry_code = 'MY_TASKS';
    check_(l_txt = 'My Work', 'a re-run keeps the label IT changed');
    xxfnd_application_pkg.save_menu_entry('R86TEST', 'MY_TASKS', 'My Tasks', 10, 'fa-inbox', 'Y');
    expect_error(-20195, 'a page entry without a page is refused',
                 q'~begin xxfnd_application_pkg.register_menu_entry('R86TEST', 'R87_BAD', 'Bad', 'APP_PAGE', null); end;~');
    xxfnd_application_pkg.register_menu_entry('R86TEST', 'R87_HOME', 'Home', 'APP_PAGE', 1);
    commit;
    select count(*) into l_n from xxfnd_app_menu_entries where application_code = 'R86TEST' and entry_code = 'R87_HOME' and made_by = 'APP';
    check_(l_n = 1, 'the application adds its own entry');
    l_txt := xxfnd_application_pkg.menu_url('R86TEST', 'COMMON_PAGE', 40, null);
    check_(lower(l_txt) like '%common%' and (l_txt like '%40%' or lower(l_txt) like '%my-tasks%'), 'a COMMON page entry links to COMMON (' || l_txt || ')');
    l_txt := xxfnd_application_pkg.menu_url('R86TEST', 'MANAGED', null, 'LOOKUPS');
    check_(l_txt like '%99%' and l_txt like '%R86TEST%', 'a managed function links to COMMON page 99 for the application (' || l_txt || ')');
    select count(*) into l_n from user_views where view_name = 'XXFND_APP_MENU_V';
    check_(l_n = 1, 'the menu view exists');

    ---------------------------------------------------------------- 87 C4: delegated links go to page 99
    l_txt := xxfnd_application_pkg.delegated_url('LOOKUPS');
    check_(l_txt is null or l_txt like '%99%', 'DELEGATED_URL points to COMMON page 99 (' || nvl(l_txt, 'null') || ')');

    ---------------------------------------------------------------- 87 C11 / 88 C10: grants
    select count(*) into l_n from user_tab_privs_made where grantee = 'XXCUS' and privilege in ('INSERT', 'UPDATE', 'DELETE');
    check_(l_n = 0, 'no INSERT / UPDATE / DELETE granted to an application schema (' || l_n || ')');
    select count(*) into l_n from user_tab_privs_made where grantee = 'XXCUS' and privilege = 'SELECT' and table_name = 'XXFND_LOOKUP_TYPES';
    check_(l_n = 1, 'SELECT stays');
    select count(*) into l_n from user_tab_privs_made where grantee = 'XXCUS' and privilege = 'REFERENCES' and table_name = 'XXFND_ROLES';
    check_(l_n = 1, 'REFERENCES stays (the applications'' foreign keys)');
    select count(*) into l_n from user_tab_privs_made where grantee = 'XXCUS' and privilege = 'EXECUTE' and table_name = 'XXFND_ONBOARD_PKG';
    check_(l_n = 1, 'every schema of the workspace may onboard itself');

    ---------------------------------------------------------------- 88 C10: several approval rules per type
    xxfnd_approval_rule_pkg.register_type('R87_TYPE', 'R86TEST', 'R87 approval type');
    xxfnd_approval_rule_pkg.register_rule('R86TEST', 'R87_TYPE', 'Low', apex_t_varchar2('Check=REQUESTER'), null, 10);
    xxfnd_approval_rule_pkg.register_rule('R86TEST', 'R87_TYPE', 'High', apex_t_varchar2('Check=ROLE=R86TEST_ADMIN'), null, 20);
    xxfnd_approval_rule_pkg.register_rule('R86TEST', 'R87_TYPE', 'High', apex_t_varchar2('Other=REQUESTER'), null, 30);
    commit;
    select count(*) into l_n from xxfnd_approval_rules where approval_type_code = 'R87_TYPE';
    check_(l_n = 2, 'REGISTER_RULE adds each named rule once (' || l_n || ')');
    select max(priority) into l_n from xxfnd_approval_rules where approval_type_code = 'R87_TYPE' and rule_name = 'High';
    check_(l_n = 20, 'a registered rule is kept as it is');
    expect_error(-20186, 'a rule for another application''s type is refused',
                 q'~begin xxfnd_approval_rule_pkg.register_rule('COMMON', 'R87_TYPE', 'X'); end;~');

    ---------------------------------------------------------------- 88 C8 / C9: unregistering
    xxfnd_lookup_pkg.register_lookup_type('R86TEST', 'R87_LT', 'R87 lookup');
    xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'R87_LT', 'A', 'A');
    xxfnd_lookup_pkg.register_lookup_value('R86TEST', 'R87_LT', 'B', 'B');
    commit;
    xxfnd_lookup_pkg.unregister_lookup_value('R86TEST', 'R87_LT', 'A');
    select count(*) into l_n from xxfnd_lookup_values where lookup_type = 'R87_LT';
    check_(l_n = 1, 'UNREGISTER_LOOKUP_VALUE removes one value');
    expect_error(-20187, 'an unknown row is refused',
                 q'~begin xxfnd_lookup_pkg.unregister_lookup_value('R86TEST', 'R87_LT', 'ZZ'); end;~');
    select min(lookup_type) into l_txt from xxfnd_lookup_types where application_code is null;
    expect_error(-20186, 'COMMON''s (shared) row is refused (' || l_txt || ')',
                 'begin xxfnd_lookup_pkg.unregister_lookup_type(''R86TEST'', ''' || l_txt || '''); end;');
    xxfnd_lookup_pkg.unregister_lookup_type('R86TEST', 'R87_LT');
    commit;
    select count(*) into l_n from xxfnd_lookup_types where lookup_type = 'R87_LT';
    check_(l_n = 0, 'UNREGISTER_LOOKUP_TYPE removes the type with its values');
    xxfnd_approval_rule_pkg.unregister_rule('R86TEST', 'R87_TYPE', 'Low');
    select count(*) into l_n from xxfnd_approval_rules where approval_type_code = 'R87_TYPE';
    check_(l_n = 1, 'UNREGISTER_RULE removes one rule');
    xxfnd_approval_rule_pkg.register_rule('R86TEST', 'R87_TYPE', 'Low', apex_t_varchar2('Check=REQUESTER'), null, 10);
    xxfnd_application_pkg.unregister_menu_entry('R86TEST', 'R87_HOME');
    select count(*) into l_n from xxfnd_app_menu_entries where application_code = 'R86TEST' and entry_code = 'R87_HOME';
    check_(l_n = 0, 'UNREGISTER_MENU_ENTRY removes the application''s entry');
    expect_error(-20186, 'COMMON''s menu entries are switched off, not removed',
                 q'~begin xxfnd_application_pkg.unregister_menu_entry('R86TEST', 'MY_TASKS'); end;~');
    xxfnd_application_pkg.register_menu_entry('R86TEST', 'R87_HOME', 'Home', 'APP_PAGE', 1);
    commit;

    ---------------------------------------------------------------- 88 C5: RFI documents and deadlines
    select count(*) into l_n from xxfnd_attachment_blocks where function_code = 'COMMON_RFI' and region_static_id = 'documents';
    check_(l_n = 1, 'page 143 keeps the documents of the RFI');
    select count(*) into l_n from xxfnd_task_settings where task_definition in ('RFI_RESPONSE', 'RFI_REVIEW');
    check_(l_n = 2, 'the RFI tasks have their task settings');
    select max(rfi_id) into l_rfi from xxfnd_rfis where due_date is not null;
    if l_rfi is not null then
        l_ts := xxfnd_rfi_pkg.task_due_date(l_rfi, 'RFI_RESPONSE');
        select count(*) into l_n from xxfnd_rfis where rfi_id = l_rfi and trunc(due_date) = trunc(cast(l_ts as date));
        check_(l_n = 1, 'the answer is due on the RFI''s due date');
    end if;
    check_(xxfnd_rfi_pkg.task_due_date(-1, 'RFI_REVIEW') is null, 'no due days set: no due date');

    ---------------------------------------------------------------- 87: the self-onboarding switch
    select count(*) into l_n from apex_application_settings s
     where s.application_id = (select apex_application_id from xxfnd_applications where application_code = 'COMMON')
       and s.name = 'ONBOARD_SELF_ALLOWED';
    check_(l_n = 1, 'COMMON has the setting ONBOARD_SELF_ALLOWED');
    commit;
end;
/
