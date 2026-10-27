
comment on table xxfnd_nav_menu_v is 'Release 104 / 105: the navigation of the running page for the signed-in user (an APEX list per MENU_CODE: SIDE, TOP_BAR, ADMIN; ordered by SORT_PATH): the menus of the application kept in COMMON (XXFND_APP_MENU_ENTRIES, shown by privileges); in COMMON those of COMMON or of the application the page is used from (G_WORK_APP).';

-- release 106: the links between pages in the APEX definitions of the workspace's applications (buttons, branches,
-- report column links, list entries) that name a page (f?p=APP:PAGE). Built from the dictionary columns this APEX
-- version has, so a column APEX renames is skipped instead of failing the install. TARGET_APP / TARGET_PAGE as written
-- (an alias, a number or a substitution such as the running application).
declare
    l_sql varchar2(32767);

    procedure part(p_view in varchar2, p_target in varchar2, p_page in varchar2, p_source in varchar2) is
        l_n pls_integer;
    begin
        select count(distinct column_name) into l_n from all_tab_columns
         where table_name = p_view
           and column_name in ('APPLICATION_ID', p_target, nvl(p_page, 'APPLICATION_ID'));
        if l_n = case when p_page is null then 2 else 3 end then
            l_sql := l_sql || case when l_sql is not null then ' union all ' end
                  || 'select application_id as from_application_id, '
                  || nvl(p_page, 'cast(null as number)') || ' as from_page_id, '
                  || p_source || ' as link_source, '
                  || 'regexp_substr(' || p_target || q'~, 'f\?p=([^:]*):([^:]*)', 1, 1, 'i', 1) as target_app, ~'
                  || 'regexp_substr(' || p_target || q'~, 'f\?p=([^:]*):([^:]*)', 1, 1, 'i', 2) as target_page ~'
                  || 'from ' || p_view || ' where ' || p_target || q'~ like '%f?p=%'~';
        end if;
    end part;
begin
    part('APEX_APPLICATION_PAGE_BUTTONS',  'REDIRECT_URL',    'PAGE_ID', q'~'Button'~');
    part('APEX_APPLICATION_PAGE_BRANCHES', 'BRANCH_ACTION',   'PAGE_ID', q'~'Branch'~');
    part('APEX_APPLICATION_PAGE_IR_COL',   'COLUMN_LINK',     'PAGE_ID', q'~'Report link'~');
    part('APEX_APPLICATION_PAGE_RPT_COLS', 'COLUMN_LINK_URL', 'PAGE_ID', q'~'Report link'~');
    part('APEX_APPLICATION_LIST_ENTRIES',  'ENTRY_TARGET',    null,      q'~'List'~');
    execute immediate 'create or replace view xxfnd_page_links_v as '
        || nvl(l_sql, 'select cast(null as number) as from_application_id, cast(null as number) as from_page_id, '
                      || 'cast(null as varchar2(30)) as link_source, cast(null as varchar2(255)) as target_app, '
                      || 'cast(null as varchar2(255)) as target_page from dual where 1 = 0');
    execute immediate q'~comment on table xxfnd_page_links_v is 'Release 106: the links to a page (f?p=APP:PAGE) in the APEX definitions of the applications: buttons, branches, report and list links. COMMON only (reads APEX metadata).'~';
end;
/
