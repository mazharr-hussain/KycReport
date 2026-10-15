-- Release 86 part C checks (run as XXFUSION after the COMMON import): application management as a guided journey -
-- page 165 Application Journey (create and edit), page 166 Application (review), the journey sections defined once on
-- the Global Page (page 0) for both, page 161 retired, the privileges of pages 165 / 166 (feature APPLICATIONS).
-- Reads only (no test rows); the browser test r88_journey_ui.py registers, edits, disables and deletes an application.
set serveroutput on feedback off
declare
    l_n    number;
    l_app  number;
    l_text varchar2(4000);
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    apex_util.set_workspace('XXCUS');
    select max(apex_application_id) into l_app from xxfnd_applications where application_code = 'COMMON';

    ---------------------------------------------------------------- pages and their privileges
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from apex_application_pages where application_id = l_app and page_id in (165, 166);
    check_(l_n = 2, 'pages 165 Application Journey and 166 Application are in COMMON (' || l_n || ')');
    select count(*) into l_n from apex_application_pages where application_id = l_app and page_id = 161;
    check_(l_n = 0, 'page 161 (old Application form) is gone');
    select count(*) into l_n from apex_application_bc_entries where application_id = l_app and defined_for_page = 161;
    check_(l_n = 0, 'no breadcrumb entry for page 161');
    select count(*) into l_n from apex_application_bc_entries where application_id = l_app and defined_for_page in (165, 166);
    check_(l_n = 2, 'breadcrumb entries for 165 and 166 (' || l_n || ')');
    select count(*) into l_n from apex_application_page_regions
     where application_id = l_app and dbms_lob.instr(region_source, 'p_page => 161') > 0;
    check_(l_n = 0, 'no region links to page 161 (' || l_n || ')');
    select count(*) into l_n from apex_application_page_buttons
     where application_id = l_app and redirect_url like '%161%' and page_id <> 161;
    check_(l_n = 0, 'no button opens page 161 (' || l_n || ')');
    select count(*) into l_n from xxfnd_feature_pages
     where app_alias = 'COMMON' and feature_code = 'APPLICATIONS' and page_id in (165, 166);
    check_(l_n = 2, 'pages 165 and 166 belong to the feature APPLICATIONS (' || l_n || ')');
    select count(*) into l_n from xxfnd_privileges
     where feature_code = 'APPLICATIONS' and action_code in ('VIEW', 'CREATE', 'MANAGE');
    check_(l_n = 3, 'APPLICATIONS has View, Create and Manage (' || l_n || ')');
    select count(*) into l_n from apex_application_pages
     where application_id = l_app and page_id in (165, 166) and authorization_scheme = 'Page - View'
       and page_access_protection like 'Arguments Must Have Checksum%';
    check_(l_n = 2, '165 and 166: Page - View and arguments with checksum (' || l_n || ')');
    select count(*) into l_n from apex_application_page_buttons
     where application_id = l_app and page_id = 165 and button_name = 'CREATE' and authorization_scheme = 'Page - Create';
    check_(l_n = 1, 'Register needs Create');
    select count(*) into l_n from apex_application_page_buttons
     where application_id = l_app and ((page_id = 165 and button_name = 'SAVE')
                                       or (page_id = 166 and button_name in ('EDIT', 'DISABLE', 'ENABLE', 'DELETE')))
       and authorization_scheme = 'Page - Manage';
    check_(l_n = 5, 'Save, Edit, Disable, Enable and Delete need Manage (' || l_n || ')');

    ---------------------------------------------------------------- the sections: once, on the Global Page
    select count(*), count(distinct static_id) into l_n, l_app
      from apex_application_page_regions
     where application_id = (select max(apex_application_id) from xxfnd_applications where application_code = 'COMMON')
       and page_id = 0
       and static_id in ('jrn-application', 'jrn-roles', 'jrn-users', 'jrn-functions', 'jrn-setup-types',
                         'jrn-processes', 'jrn-notifications', 'jrn-storage', 'jrn-integrations');
    check_(l_n = 9 and l_app = 9, 'the nine journey sections are on the Global Page, once each (' || l_n || ')');
    select max(apex_application_id) into l_app from xxfnd_applications where application_code = 'COMMON';
    select count(*) into l_n from apex_application_page_regions
     where application_id = l_app and page_id in (165, 166) and static_id like 'jrn-%'
       and static_id in ('jrn-application', 'jrn-roles', 'jrn-users', 'jrn-functions', 'jrn-setup-types',
                         'jrn-processes', 'jrn-notifications', 'jrn-storage', 'jrn-integrations');
    check_(l_n = 0, 'no page repeats a section (' || l_n || ')');
    select count(*) into l_n from apex_application_page_regions
     where application_id = l_app and page_id = 0 and static_id like 'jrn-%' and static_id <> 'jrn-servers'
       and static_id <> 'jrn-context'
       and (condition_expression1 not like '%166%' or condition_expression1 not like '%165%');
    check_(l_n = 0, 'every section shows on 166 and on its step of 165 (' || l_n || ')');
    select count(*) into l_n from apex_application_lists where application_id = l_app and list_name = 'Application Journey';
    check_(l_n = 1, 'one list for the Wizard Progress (165) and the section menu (166)');
    select count(*) into l_n from apex_application_processes where application_id = l_app and process_name = 'JOURNEY_ACTIONS';
    check_(l_n = 1, 'one application process for the section actions');

    ---------------------------------------------------------------- no DML in the pages
    select count(*) into l_n from apex_application_page_regions
     where application_id = l_app and page_id in (0, 165, 166)
       and (source_type in ('Form', 'Interactive Grid') or source_type like '%Tabular%');
    check_(l_n = 0, 'no form or grid region on 165 / 166 / the sections (' || l_n || ')');
    select count(*) into l_n from apex_application_page_proc
     where application_id = l_app and page_id in (165, 166)
       and (process_type like '%Row Processing%' or process_type like '%Automatic Row%' or process_type like '%Interactive Grid%');
    check_(l_n = 0, 'no automatic row processing on 165 / 166 (' || l_n || ')');
    select count(*) into l_n from apex_application_page_proc
     where application_id = l_app and page_id in (165, 166)
       and regexp_like(process_source, '(^|\W)(insert|update|delete|merge)\s', 'i');
    check_(l_n = 0, 'no insert / update / delete / merge in the processes of 165 / 166 (' || l_n || ')');
    select count(*) into l_n from apex_application_processes
     where application_id = l_app and process_name = 'JOURNEY_ACTIONS'
       and regexp_like(process, '(^|\W)(insert|update|delete|merge)\s', 'i');
    check_(l_n = 0, 'no DML in JOURNEY_ACTIONS');

    ---------------------------------------------------------------- the routines the pages call (parts A and B)
    select count(*) into l_n from user_procedures
     where (object_name = 'XXFND_APPLICATION_PKG'
            and procedure_name in ('SAVE_APPLICATION', 'ONBOARD', 'SET_ENABLED', 'DELETE_BLOCKER', 'DELETE_APPLICATION', 'SAVE_FUNCTIONS'))
        or (object_name = 'XXFND_WORKFLOW_PKG' and procedure_name = 'SET_PROCESS_ENABLED')
        or (object_name = 'XXFND_NOTIFY_PKG' and procedure_name = 'SET_RULE_ENABLED');
    check_(l_n = 8, 'the eight routines of part A exist (' || l_n || ')');
    select count(*) into l_n from user_views where view_name in ('XXFND_SERVERS_V', 'XXFND_APP_STORAGE_V');
    check_(l_n = 2, 'the views of part B exist (' || l_n || ')');
    begin
        execute immediate 'begin :t := xxfnd_application_pkg.delete_blocker(''R86TEST''); end;' using out l_text;
        check_(l_text is not null, 'an enabled application with data cannot be deleted: ' || l_text);
    exception
        when others then
            check_(false, 'delete_blocker: ' || sqlerrm);
    end;
end;
/
