-- Release 86 test setup (run as XXCUS, the workspace owner, once): two empty APEX applications the onboarding test
-- (r86_registration_test.sql) registers - 860 "R86 Onboarding Test" (alias R86TEST) and 861 "R86 Delete Test" (alias
-- R86DEL), parsing schema XXCUS. Nothing happens for an application that exists already. They are kept.
set serveroutput on feedback off
declare
    l_ws  number;
    l_ver varchar2(100);
    procedure make(p_id in number, p_alias in varchar2, p_name in varchar2) is
        l_n number;
    begin
        select count(*) into l_n from apex_applications where application_id = p_id;
        if l_n > 0 then
            dbms_output.put_line('application ' || p_id || ' exists');
            return;
        end if;
        apex_application_install.set_workspace_id(l_ws);
        apex_application_install.set_application_id(p_id);
        apex_application_install.set_schema('XXCUS');
        apex_application_install.set_application_alias(p_alias);
        apex_application_install.set_application_name(p_name);
        apex_application_install.set_auto_install_sup_obj(false);
        wwv_flow_imp.import_begin(p_version_yyyy_mm_dd => '2024.11.30', p_release => l_ver,
                                  p_default_workspace_id => l_ws, p_default_application_id => p_id,
                                  p_default_id_offset => 0, p_default_owner => 'XXCUS');
        wwv_flow_imp.create_flow(p_id => p_id, p_owner => 'XXCUS', p_name => p_name, p_alias => p_alias,
                                 p_page_view_logging => 'YES', p_checksum_salt_last_reset => '20240101000000',
                                 p_flow_language => 'en', p_flow_language_derived_from => 'FLOW_PRIMARY_LANGUAGE',
                                 p_authentication_id => null, p_application_tab_set => 0, p_flow_version => 'R86',
                                 p_flow_status => 'AVAILABLE_W_EDIT_LINK', p_exact_substitutions_only => 'Y',
                                 p_browser_cache => 'N', p_browser_frame => 'D', p_rejoin_existing_sessions => 'N',
                                 p_csv_encoding => 'Y', p_auto_time_zone => 'N', p_file_prefix => null,
                                 p_substitution_string_01 => null, p_substitution_value_01 => null,
                                 p_last_updated_by => 'R86', p_last_upd_yyyymmddhh24miss => '20261014000000');
        wwv_flow_imp.import_end(p_auto_install_sup_obj => false);
        commit;
        dbms_output.put_line('application ' || p_id || ' made');
    end make;
begin
    apex_util.set_workspace('XXCUS');
    l_ws := apex_util.find_security_group_id('XXCUS');
    select version_no into l_ver from apex_release;
    make(860, 'R86TEST', 'R86 Onboarding Test');
    make(861, 'R86DEL', 'R86 Delete Test');
end;
/
