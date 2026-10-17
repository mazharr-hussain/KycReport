-- KYC release 91 (run as XXCUS): unused items removed, KYC parameters as application settings.
--   - page 214 (beneficial owner) is gone and is not registered for Cases on a new database
--   - XXCMP_APPROVAL_PATHS is retired (nothing reads it; its rows stay)
--   - the KYC parameters are application settings; PARAMETER reads the setting, then the old lookup, then the default
--   - the unused LOVs, the Workflow - Administer authorization, two build options, three page groups and
--     XXCMP_PARTY_PKG.REVIEW_REGISTRY_CHECK are gone; no invalid object
-- The test sets REVIEW_LEAD_DAYS for one check and puts the setting back as it was.
set serveroutput on size unlimited feedback off
declare
    l_app   number;
    l_old   varchar2(4000);
    l_n     number;

    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
    function cnt(p_sql varchar2) return number is
        l number;
    begin
        execute immediate p_sql into l;
        return l;
    end;
begin
    select max(application_id) into l_app from apex_applications where upper(alias) = 'KYC';

    ok('page 214 is removed',
       cnt('select count(*) from apex_application_pages where application_id = ' || l_app || ' and page_id = 214') = 0);
    ok('no other KYC page links to page 214',
       cnt(q'[select count(*) from apex_application_page_buttons where application_id = ]' || l_app
           || q'[ and button_action_code = 'REDIRECT_PAGE' and redirect_url like '%:214:%']') = 0);
    ok('XXCMP_APPROVAL_PATHS is marked retired',
       cnt(q'[select count(*) from user_tab_comments where table_name = 'XXCMP_APPROVAL_PATHS' and comments like 'Retired%']') = 1);
    ok('nothing in the KYC schema reads XXCMP_APPROVAL_PATHS',
       cnt(q'[select count(*) from user_dependencies where referenced_name = 'XXCMP_APPROVAL_PATHS' and name <> 'XXCMP_APPROVAL_PATHS_WHO']') = 0);

    ok('the 3 KYC parameters are application settings',
       cnt('select count(*) from apex_application_settings where application_id = ' || l_app
           || q'[ and name in ('CASE_SLA_DAYS','PEP_REVIEW_MONTHS','REVIEW_LEAD_DAYS')]') = 3);
    select count(*) into l_n from xxfnd_lookup_values
     where lookup_type = 'KYC_PARAMETER' and lookup_code = 'REVIEW_LEAD_DAYS' and enabled_flag = 'Y';
    ok('an empty setting gives the old lookup value or the default (30)',
       xxcmp_case_pkg.parameter('REVIEW_LEAD_DAYS', 30) > 0 and (l_n > 0 or xxcmp_case_pkg.parameter('REVIEW_LEAD_DAYS', 30) = 30));
    apex_session.create_session(l_app, 1, 'OFFICER1');
    l_old := apex_app_setting.get_value('REVIEW_LEAD_DAYS');
    apex_app_setting.set_value('REVIEW_LEAD_DAYS', '45');
    ok('a set application setting wins', xxcmp_case_pkg.parameter('REVIEW_LEAD_DAYS', 30) = 45);
    ok('the watchlist uses the setting',
       cnt(q'[select count(*) from xxcmp_watchlist_v where review_status = 'DUE' and days_to_review > 45]') = 0);
    apex_app_setting.set_value('REVIEW_LEAD_DAYS', l_old);
    commit;
    apex_session.delete_session;
    ok('the 18 unused LOVs are removed',
       cnt('select count(*) from apex_application_lovs where application_id = ' || l_app
           || q'[ and list_of_values_name in ('YES_NO','PARTY_TYPE','CONTACT_TYPE','DATA_PROVENANCE','UBO_STATUS',
                 'UPLOAD_STATUS','DOC_CHECK_STATUS','NOTIFICATION_STATUS','RFI_RECIPIENT_TYPE','RFI_STATUS',
                 'INTEGRATION_PURPOSE','TRANSMISSION_STATUS','LANGUAGE','PARTIES','ROLES','NOTIFICATION TEMPLATES',
                 'QUESTIONNAIRES','INTEGRATION PURPOSES')]') = 0);
    ok('the Workflow - Administer authorization is removed',
       cnt('select count(*) from apex_application_authorization where application_id = ' || l_app
           || q'[ and authorization_scheme_name = 'Workflow - Administer']') = 0);
    ok('the Commented Out and Theme Style build options are removed',
       cnt('select count(*) from apex_application_build_options where application_id = ' || l_app
           || q'[ and build_option_name in ('Commented Out','Feature - Theme Style Selection')]') = 0);
    ok('the empty page groups are removed',
       cnt('select count(*) from apex_application_page_groups where application_id = ' || l_app
           || q'[ and page_group_name in ('Requests for Information','Workflow','Attachments')]') = 0);
    ok('REVIEW_REGISTRY_CHECK is removed from the party package',
       cnt(q'[select count(*) from user_procedures where object_name = 'XXCMP_PARTY_PKG'
               and procedure_name = 'REVIEW_REGISTRY_CHECK']') = 0);
    ok('no invalid object in the KYC schema',
       cnt(q'[select count(*) from user_objects where status <> 'VALID' and object_name not like 'BIN$%']') = 0);
exception
    when others then
        dbms_output.put_line('FAIL unexpected: ' || sqlerrm || ' ' || dbms_utility.format_error_backtrace);
        rollback;
end;
/
