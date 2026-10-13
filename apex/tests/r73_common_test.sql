-- Release 73 checks (run as XXFUSION): setup types, workflow / e-mail switches, delegated administration, APEX IDs.
-- Changes are rolled back at the end.
set serveroutput on feedback off
declare
    l_n    number;
    l_v    varchar2(4000);
    l_user varchar2(255);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    -- setup types
    select count(*) into l_n from xxfnd_setup_types;
    check_(l_n >= 20, 'setup types seeded (' || l_n || ')');
    check_(xxfnd_application_pkg.app_allowed('VALUE_SETS', null) = 'Y', 'instance-only type: instance allowed');
    check_(xxfnd_application_pkg.app_allowed('VALUE_SETS', 'KYC') = 'N', 'instance-only type: application refused');
    check_(xxfnd_application_pkg.app_allowed('ROLES', null) = 'N', 'application-only type: instance refused');
    check_(xxfnd_application_pkg.app_allowed('ROLES', 'KYC') = 'Y', 'application-only type: KYC allowed');
    check_(xxfnd_application_pkg.app_allowed('LOOKUPS', 'COMMON') = 'N', 'COMMON is the instance, not an application');
    update xxfnd_setup_types set all_applications_flag = 'N' where setup_type_code = 'LOOKUPS';
    check_(xxfnd_application_pkg.app_allowed('LOOKUPS', 'KYC') = 'N', 'chosen applications only: KYC not listed -> refused');
    insert into xxfnd_setup_type_apps (setup_type_code, application_code) values ('LOOKUPS', 'KYC');
    check_(xxfnd_application_pkg.app_allowed('LOOKUPS', 'KYC') = 'Y', 'chosen applications only: KYC listed -> allowed');
    check_(xxfnd_application_pkg.page_type(102) = 'LOOKUPS', 'the form page knows its setup type');
    select count(*) into l_n from user_triggers where trigger_name like '%\_LV' escape '\' and status = 'ENABLED';
    check_(l_n >= 10, 'level triggers on the setup tables (' || l_n || ')');
    select count(*) into l_n from xxfnd_setup_rows_v where application_code = 'KYC';
    check_(l_n > 0, 'KYC setup rows in the overview view (' || l_n || ')');
    select count(*) into l_n from xxfnd_setup_tables_v where application_code = 'KYC';
    check_(l_n > 0, 'KYC tables listed for the setup forms (' || l_n || ')');
    select count(*) into l_n from xxfnd_lookup_types where application_code = 'COMMON';
    check_(l_n = 0, 'no lookup type left on COMMON (instance rows)');

    -- APEX IDs
    select count(*) into l_n from xxfnd_applications where apex_application_id is null
       and upper(apex_app_alias) in (select upper(alias) from apex_applications);
    check_(l_n = 0, 'every installed application has its APEX ID');

    -- workflow / e-mail switches
    select count(*) into l_n from xxfnd_workflow_processes where application_code = 'KYC';
    check_(l_n >= 2, 'KYC workflow processes registered (' || l_n || ')');
    check_(xxfnd_workflow_switch_pkg.workflow_enabled('KYC_CASE', 'KYC') = 'Y', 'workflow on by default');
    update xxfnd_workflow_processes set workflow_enabled_flag = 'N' where application_code = 'KYC' and process_code = 'KYC_CASE';
    check_(xxfnd_workflow_switch_pkg.workflow_enabled('KYC_CASE', 'KYC') = 'N', 'workflow switched off for the process');
    check_(xxfnd_workflow_switch_pkg.email_enabled('KYC_CASE', 'KYC') = 'Y', 'e-mail on: instance, application and process on');
    update xxfnd_workflow_processes set email_enabled_flag = 'N' where application_code = 'KYC' and process_code = 'KYC_CASE';
    check_(xxfnd_workflow_switch_pkg.email_enabled('KYC_CASE', 'KYC') = 'N', 'e-mail off for the process');
    check_(xxfnd_workflow_switch_pkg.email_enabled('KYC_REQUEST', 'KYC') = 'Y', 'another process keeps e-mail');
    update xxfnd_applications set email_enabled_flag = 'N' where application_code = 'KYC';
    check_(xxfnd_workflow_switch_pkg.email_enabled('KYC_REQUEST', 'KYC') = 'N', 'e-mail off for the application');
    update xxfnd_applications set email_enabled_flag = 'Y' where application_code = 'KYC';
    update xxfnd_applications set email_enabled_flag = 'N' where application_code = 'COMMON';
    check_(xxfnd_workflow_switch_pkg.email_enabled('KYC_REQUEST', 'KYC') = 'N', 'e-mail off for the instance');

    -- delegated administration
    select count(*) into l_n from user_tab_columns where table_name = 'XXFND_APPLICATION_FUNCTIONS' and column_name = 'ENABLED_FLAG';
    check_(l_n = 0, 'the "Available" switch is gone');
    select max(ur.user_name) into l_user
      from xxfnd_user_roles_v ur
      join xxfnd_role_privileges rp on rp.role_code = ur.role_code
      join xxfnd_privileges p on p.privilege_code = rp.privilege_code
     where ur.application_code = 'KYC' and ur.active_flag = 'Y' and p.feature_code = 'LOOKUPS';
    if l_user is null then
        dbms_output.put_line('SKIP no KYC user with a Lookups privilege');
    else
        check_(xxfnd_application_pkg.is_delegated('KYC', 'LOOKUPS', l_user) = 'N', 'not managed in KYC: ' || l_user || ' not delegated');
        update xxfnd_application_functions set managed_in_app_flag = 'Y' where application_code = 'KYC' and feature_code = 'LOOKUPS';
        check_(xxfnd_application_pkg.is_delegated('KYC', 'LOOKUPS', l_user) = 'Y', 'managed in KYC: ' || l_user || ' delegated');
        check_(xxfnd_application_pkg.delegated_any(l_user) = 'Y', l_user || ' may open COMMON delegated screens');
    end if;
    rollback;
end;
/
exit
