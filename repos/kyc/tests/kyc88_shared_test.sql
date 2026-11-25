-- KYC release 88 (run as XXCUS, after the KYC import): KYC has no copy of a COMMON screen.
--   - pages 40, 41, 44, 45, 90, 91, 98, 172, 10020-10023, 10030-10033, 10050-10052 and task definition
--     CONFIG_CHANGE are gone; nothing in KYC links to them (list entries, breadcrumbs, buttons, branches)
--   - KYC 106 (I-100, #278) - the design since: page 100 is KYC's Administration page again (release 95); the side
--     menu and the navigation bar are COMMON's lists (subscriptions, release 104 / 105), built by XXFND_NAV_PKG from
--     COMMON's Application Menu (My Tasks, Give Feedback ... are entries there, not in KYC); Administration is the
--     subscribed list (KYC's own setup, the common functions IT lets KYC manage, COMMON's shared setup)
--   - the four administration lists are one, the Activity Reports list is gone
--   - COMMON's LOVs and authorizations are used as subscriptions (masters in COMMON); the flexfield messages and
--     xxfnd-dff.js stay in KYC (COMMON has no master; APEX_LANG.MESSAGE reads the running application)
--   - every remaining KYC page has an authorization scheme and belongs to a KYC feature (its privileges)
-- No test rows are written.
set serveroutput on size unlimited feedback off define off
declare
    c_removed constant varchar2(400) := '40,41,44,45,90,91,98,172,10020,10021,10022,10023,10030,10031,10032,10033,10050,10051,10052';
    -- the RFI pages 30-34 go in release 89 (not checked here)
    l_app   number;
    l_n     number;
    l_sql   clob;
    l_labels varchar2(4000);

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
    -- a link to a removed page of this application (f?p=&APP_ID.:<page>: or f?p=<id>:<page>:)
    function links_removed(p_text varchar2) return boolean is
    begin
        for p in (select column_value page_id from table(apex_string.split(c_removed, ','))) loop
            if regexp_like(p_text, 'f\?p=(&APP_ID\.|' || l_app || '|KYC):' || p.page_id || ':', 'i') then
                return true;
            end if;
        end loop;
        return false;
    end;
begin
    apex_util.set_workspace('XXCUS');
    select max(application_id) into l_app from apex_applications where upper(alias) = 'KYC';

    -- removed pages and task definition
    ok('none of the 19 removed pages is in KYC',
       cnt('select count(*) from apex_application_pages where application_id = ' || l_app
           || ' and page_id in (' || c_removed || ')') = 0);
    ok('the removed pages are all COMMON pages or COMMON replacements exist (COMMON 40, 47, 48, 100, 141, 144, 170, 171, 173, 10020, 10022)',
       cnt(q'[select count(*) from apex_application_pages p join apex_applications a on a.application_id = p.application_id
               where upper(a.alias) = 'COMMON' and p.page_id in (40, 47, 48, 100, 141, 144, 170, 171, 173, 10020, 10022)]') = 11);
    ok('KYC has no task definition CONFIG_CHANGE (COMMON''s workflow process approves configuration changes)',
       cnt('select count(*) from apex_appl_taskdefs where application_id = ' || l_app || q'[ and static_id = 'CONFIG_CHANGE']') = 0);

    -- nothing links to a removed page
    l_n := 0;
    for e in (select entry_target t from apex_application_list_entries where application_id = l_app) loop
        if links_removed(e.t) then l_n := l_n + 1; end if;
    end loop;
    ok('no list entry links to a removed page', l_n = 0);
    l_n := 0;
    for e in (select url t, defined_for_page from apex_application_bc_entries where application_id = l_app) loop
        if links_removed(e.t) or instr(',' || c_removed || ',', ',' || e.defined_for_page || ',') > 0 then l_n := l_n + 1; end if;
    end loop;
    ok('no breadcrumb entry is for or links to a removed page', l_n = 0);
    l_n := 0;
    for e in (select redirect_url t from apex_application_page_buttons where application_id = l_app
                 and page_id not between 30 and 34) loop
        if links_removed(e.t) then l_n := l_n + 1; end if;
    end loop;
    ok('no button links to a removed page', l_n = 0);
    l_n := 0;
    for e in (select branch_action t from apex_application_page_branches where application_id = l_app
                 and page_id not between 30 and 34) loop
        if links_removed(e.t) then l_n := l_n + 1; end if;
    end loop;
    ok('no branch goes to a removed page', l_n = 0);

    -- the menu and the navigation bar are COMMON's (KYC 106, I-100: subscriptions built by XXFND_NAV_PKG)
    ok('the side menu is COMMON''s menu (XXFND_NAV_PKG.NAV_MENU)',
       cnt('select count(*) from apex_application_lists where application_id = ' || l_app
           || q'[ and list_name = 'Navigation Menu' and lower(list_query) like '%xxfnd_nav_pkg.nav_menu%']') = 1);
    ok('the navigation bar is COMMON''s (XXFND_NAV_PKG.NAV_MENU(''TOP_BAR''): notifications, Give Feedback, user menu)',
       cnt('select count(*) from apex_application_lists where application_id = ' || l_app
           || q'[ and list_name = 'Navigation Bar' and lower(list_query) like '%xxfnd_nav_pkg.nav_menu(''top_bar'')%']') = 1);
    ok('page 100 (Administration) shows a list region (the Administration list)',
       cnt('select count(*) from apex_application_page_regions where application_id = ' || l_app
           || q'[ and page_id = 100 and lower(source_type) like '%list%']') >= 1);
    ok('the add-document buttons open COMMON''s Attachments page 47 for the KYC record (3)',
       cnt('select count(*) from apex_application_page_buttons where application_id = ' || l_app
           || q'[ and redirect_url like 'f?p=COMMON:47:%' and redirect_url like '%P47_APP_ALIAS%']') = 3);

    -- lists
    ok('one Administration list instead of four; no Activity Reports list',
       cnt('select count(*) from apex_application_lists where application_id = ' || l_app
           || q'[ and (list_name like 'Administration - %' or list_name = 'Activity Reports')]') = 0
       and cnt('select count(*) from apex_application_lists where application_id = ' || l_app
               || q'[ and list_name = 'Administration' and list_type = 'SQL Query']') = 1);

    -- COMMON's shared components used as subscriptions
    ok('the 6 COMMON LOVs are subscribed from COMMON (jurisdiction, approval status, employees, categories, entities, lookup types)',
       cnt('select count(*) from apex_application_lovs where application_id = ' || l_app || q'[ and is_subscribed = 'Yes'
             and list_of_values_name in (select list_of_values_name from apex_application_lovs c
                                         where c.application_id = (select application_id from apex_applications where upper(alias) = 'COMMON'))
             and static_id in ('lov-jurisdiction','lov-approval-status','lov-employees','lov-categories','lov-entities','lov-lookup-types')]') = 6);
    ok('the 5 COMMON authorizations are subscribed from COMMON (page view/create/manage/submit, admin area)',
       cnt('select count(*) from apex_application_authorization where application_id = ' || l_app || q'[ and is_subscribed = 'Yes'
             and static_id in ('page-view','page-create','page-manage','page-submit','admin-area')]') = 5);
    ok('the LOVs only the removed pages used are gone (document data type, task list and workflow console LOVs)',
       cnt('select count(*) from apex_application_lovs where application_id = ' || l_app
           || q'[ and (static_id = 'lov-doc-datatype' or static_id like 'unified-task-list%' or static_id like 'workflow-console%')]') = 0);
    ok('the 10 flexfield messages stay in KYC (APEX_LANG.MESSAGE reads the running application)',
       cnt('select count(*) from apex_application_translations where application_id = ' || l_app
           || q'[ and translatable_message like 'XXFND\_DFF\_%' escape '\']') = 10);
    ok('xxfnd-dff.js stays in KYC (COMMON has no copy)',
       cnt('select count(*) from apex_application_static_files where application_id = ' || l_app
           || q'[ and file_name = 'js/xxfnd-dff.js']') = 1);

    -- every remaining page keeps its privileges
    ok('every KYC page (but the global page, sign-in and the RFI pages of release 89) has an authorization scheme',
       cnt('select count(*) from apex_application_pages where application_id = ' || l_app
           || ' and page_id not in (0, 9999) and page_id not between 30 and 34 and authorization_scheme is null') = 0);
    execute immediate 'select listagg(p.page_id, '', '') within group (order by p.page_id) from apex_application_pages p'
        || ' where p.application_id = ' || l_app
        || q'[ and p.page_id not in (0, 9999) and p.page_id not between 30 and 34
              and not exists (select 1 from xxfnd_feature_pages f where upper(f.app_alias) = 'KYC' and f.page_id = p.page_id)]'
        into l_labels;
    ok('every KYC page (but 0, 9999 and the RFI pages of release 89) belongs to a KYC feature'
       || nvl2(l_labels, ' - not: ' || l_labels, null), l_labels is null);

    -- the Administration list: KYC's own setup and COMMON's shared setup for the administrator
    select list_query into l_sql from apex_application_lists where application_id = l_app and list_name = 'Administration';
    -- the KYC administrator (test user TKYC_ADMIN: SYSTEM_ADMIN, KYC_ADMIN - KYC 106, I-100)
    apex_session.create_session(l_app, 1, 'TKYC_ADMIN');
    l_sql := replace(replace(l_sql, ':APP_ALIAS', '''KYC'''), ':APP_PAGE_ID', '1');
    execute immediate 'select listagg(label, ''|'') within group (order by label) from (' || l_sql || ')' into l_labels;
    ok('the KYC administrator''s Administration menu: KYC Rules, Alert Rules and Shared Setup (' || l_labels || ')',
       instr(l_labels, 'KYC Rules') > 0 and instr(l_labels, 'Alert Rules') > 0 and instr(l_labels, 'Shared Setup') > 0);
    ok('every Administration entry has a link; Shared Setup opens COMMON',
       cnt('select count(*) from (' || l_sql || ') where target is null') = 0
       and cnt('select count(*) from (' || l_sql || q'[) where label = 'Shared Setup' and lower(target) like '%common%']') = 1);
    apex_session.delete_session;
    apex_session.create_session(l_app, 1, 'OFFICER1');
    execute immediate 'select count(*) from (' || l_sql || ')' into l_n;
    ok('a compliance officer (no setup privilege) has no Administration entries: ' || l_n, l_n = 0);
    apex_session.delete_session;
exception
    when others then
        dbms_output.put_line('FAIL unexpected: ' || sqlerrm || ' ' || dbms_utility.format_error_backtrace);
        rollback;
end;
/
exit
