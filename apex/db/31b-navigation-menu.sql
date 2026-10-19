--------------------------------------------------------------------------------
-- 31b Navigation menu (release 104). COMMON only (XXFUSION), after 31.
--   The menu of every application is kept here (XXFND_APP_MENU_ENTRIES), as an EBS / Fusion menu: folders and the
--   pages they open, maintained on the Application Menu screen (pages 167 / 168, Applications privileges) and added
--   by each application's install (XXFND_APPLICATION_PKG.REGISTER_MENU_ENTRY).
--   - Entries: FOLDER (a parent of other entries) and ADMIN_PAGE (a page for the application's administrators)
--     besides COMMON_PAGE, APP_PAGE, MANAGED, SHARED_SETUP; made by
--     COMMON, the application (APP) or an administrator (ADMIN).
--   - XXFND_NAV_MENU_V (COMMON's own: it reads APEX metadata) through XXFND_NAV_PKG.NAV_MENU (granted to the
--     applications): the navigation menu of the running page, for the signed-in user (an APEX list: lvl, label,
--     target, is_current, image, ...; ordered by SORT_PATH). In an application: its own menu. In COMMON: COMMON's
--     menu (Home, My Tasks, modules), or - when a COMMON page is used from an application (G_WORK_APP) - that
--     application's menu, so the menu does not change. The navigation list "Navigation Menu" of COMMON reads it and
--     every application subscribes to that list.
--   - Who sees an entry: the same privileges as the pages (XXFND_APPLICATION_PKG.ENTRY_VISIBLE); a folder is shown
--     when one of its entries is shown, a hidden folder hides its entries.
-- Idempotent: constraints and rows are added only when missing; the view is replaced.
--------------------------------------------------------------------------------
begin
    xxfnd_error_pkg.register_message('XXFND_MENU_PARENT',
        'Menu entry {1}: the parent must be a folder of the same application (not the entry itself or one inside it).',
        -20198);
    xxfnd_error_pkg.register_message('XXFND_MENU_DELETE',
        'Menu entry {1} belongs to COMMON or the application: hide it instead of deleting it.', -20199);

    -- folders (no page) and entries an administrator adds
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK1');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK3');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK4');
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK5',
        q'~check (target_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'MANAGED', 'SHARED_SETUP', 'FOLDER'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK6',
        q'~check (made_by in ('COMMON', 'APP', 'ADMIN'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK7',
        q'~check (target_type in ('MANAGED', 'SHARED_SETUP', 'FOLDER') or page_id is not null)~');
    execute immediate q'~comment on column xxfnd_app_menu_entries.target_type is 'COMMON_PAGE: a COMMON page; APP_PAGE: a page of the application; MANAGED: a common function the application manages (COMMON page 99 for the application); SHARED_SETUP: COMMON Administration (page 100); release 104 - ADMIN_PAGE: a page of the application for its administrators; FOLDER: a parent of other entries.'~';
    execute immediate q'~comment on column xxfnd_app_menu_entries.made_by is 'COMMON (onboarding), APP (the application''s install) or ADMIN (release 104: added on the Application Menu screen; only these are deleted, the others are hidden).'~';

    -- the Application Menu screen belongs to the feature Applications (View to see, Manage to change)
    for p in (select 167 page_id from dual union all select 168 from dual) loop
        merge into xxfnd_feature_pages d
        using (select 'COMMON' app_alias, p.page_id page_id from dual) s
           on (d.app_alias = s.app_alias and d.page_id = s.page_id)
         when not matched then insert (app_alias, page_id, feature_code) values ('COMMON', p.page_id, 'APPLICATIONS');
    end loop;
    commit;
end;
/

create or replace view xxfnd_nav_menu_v as
with ctx as (
    -- the running page; the menu shown: the working application (COMMON page used from an application), else the
    -- running application
    select upper(v('APP_ALIAS'))                              as cur_alias,
           to_number(v('APP_ID'))                             as cur_app_id,
           to_number(v('APP_PAGE_ID'))                        as cur_page,
           upper(coalesce(v('G_WORK_APP'), v('APP_ALIAS')))   as menu_alias,
           v('P100_MODULE')                                   as cur_module
      from dual),
cur as (
    select max(fp.feature_code) as feature_code
      from xxfnd_feature_pages fp, ctx
     where upper(fp.app_alias) = ctx.cur_alias and fp.page_id = ctx.cur_page),
-- COMMON's own menu (release 78 / 82): Home, My Tasks, the modules (XXFND_MODULES_V) and their components
feat as (
    select m.feature_group, m.feature_code, m.feature_name, m.icon_css, m.display_sequence, t.page_id
      from xxfnd_admin_menu_v m
      cross join ctx
      cross apply (select min(fp.page_id) keep (dense_rank first order by
                              case when fp.page_id = m.home_page_id then 0 else 1 end,
                              fp.tab_sequence nulls last, fp.page_id) as page_id
                     from xxfnd_feature_pages fp
                     join apex_application_pages ap
                       on ap.application_id = ctx.cur_app_id and ap.page_id = fp.page_id
                    where fp.app_alias = 'COMMON' and fp.feature_code = m.feature_code) t
     where ctx.menu_alias = 'COMMON' and t.page_id is not null),
common_nodes as (
    select 'HOME' as id, cast(null as varchar2(100)) as parent_id, 'Home' as label,
           apex_page.get_url(p_page => 1) as target, 'fa-home' as image, 0 as seq,
           case when ctx.cur_page = 1 then 'YES' else 'NO' end as is_current
      from ctx
     where ctx.menu_alias = 'COMMON'
    union all
    select 'MY_TASKS', null, 'My Tasks', apex_page.get_url(p_page => 40), 'fa-inbox', 1,
           case when ctx.cur_page = 40 then 'YES' else 'NO' end
      from ctx
     where ctx.menu_alias = 'COMMON' and xxfnd_privilege_pkg.has_privilege_yn('MY_TASKS', 'VIEW') = 'Y'
    union all
    select 'M_' || md.module_code, null, md.module_name,
           apex_page.get_url(p_page => 100, p_items => 'P100_MODULE', p_values => md.module_code, p_clear_cache => '100'),
           md.icon_css, md.display_sequence,
           case when ctx.cur_page = 100 and ctx.cur_module = md.module_code then 'YES' else 'NO' end
      from xxfnd_modules_v md, ctx
     where ctx.menu_alias = 'COMMON'
    union all
    select 'F_' || f.feature_code, 'M_' || f.feature_group, f.feature_name, apex_page.get_url(p_page => f.page_id),
           f.icon_css, f.display_sequence,
           case when f.feature_code = (select feature_code from cur) then 'YES' else 'NO' end
      from feat f),
-- release 104: an application's menu (XXFND_APP_MENU_ENTRIES)
app_entries as (
    select e.application_code, e.entry_code, e.parent_code, e.label, e.target_type, e.page_id, e.icon_css,
           e.display_sequence,
           xxfnd_application_pkg.entry_visible(e.application_code, e.target_type, e.page_id, e.feature_code,
                                               e.enabled_flag) as visible,
           xxfnd_application_pkg.menu_url(e.application_code, e.target_type, e.page_id, e.feature_code) as target,
           (select max(fp.feature_code) from xxfnd_feature_pages fp
             where upper(fp.app_alias) = ctx.menu_alias and fp.page_id = e.page_id) as page_feature,
           ctx.cur_alias, ctx.cur_page, ctx.menu_alias
      from xxfnd_app_menu_entries e
      join xxfnd_applications a on a.application_code = e.application_code
      cross join ctx
     where upper(a.apex_app_alias) = ctx.menu_alias
       and ctx.menu_alias <> 'COMMON'),
-- the entries the user sees, top down: a hidden entry hides what is inside it
app_tree as (
    select x.*, level as lvl,
           sys_connect_by_path(to_char(x.display_sequence, 'fm0000000') || x.label, '/') as sort_path,
           sys_connect_by_path(x.entry_code, '/') || '/' as code_path
      from app_entries x
     start with x.parent_code is null and x.visible = 'Y'
   connect by prior x.entry_code = x.parent_code and x.visible = 'Y')
select level as lvl, n.label, n.target, n.is_current, n.image,
       cast(null as varchar2(100)) as image_attribute, cast(null as varchar2(100)) as image_alt,
       sys_connect_by_path(to_char(nvl(n.seq, 0), 'fm0000000') || n.label, '/') as sort_path
  from common_nodes n
 start with n.parent_id is null
connect by prior n.id = n.parent_id
union all
select t.lvl, t.label, t.target,
       case when t.target_type in ('APP_PAGE', 'ADMIN_PAGE') and t.cur_alias = t.menu_alias
                 and (t.page_id = t.cur_page
                      or (t.page_feature is not null and t.page_feature = (select feature_code from cur)))
            then 'YES'
            when t.target_type = 'COMMON_PAGE' and t.cur_alias = 'COMMON' and t.page_id = t.cur_page then 'YES'
            else 'NO' end,
       t.icon_css, null, null, t.sort_path
  from app_tree t
 where t.target_type <> 'FOLDER'
    or exists (select 1 from app_tree c where instr(c.code_path, t.code_path) = 1 and c.target_type <> 'FOLDER');

comment on table xxfnd_nav_menu_v is 'Release 104: the navigation menu of the running page for the signed-in user (an APEX list ordered by SORT_PATH): the application''s menu (XXFND_APP_MENU_ENTRIES, shown by privileges), in COMMON COMMON''s menu or that of the application the page is used from (G_WORK_APP).';

-- the menu for the navigation lists of every application: the view reads APEX's metadata (not grantable on), the
-- applications run this function (EXECUTE)
create or replace package xxfnd_nav_pkg authid definer as
    type t_nav_row is record (
        lvl             number,
        label           varchar2(4000),
        target          varchar2(4000),
        is_current      varchar2(3),
        image           varchar2(255),
        image_attribute varchar2(255),
        image_alt       varchar2(255),
        sort_path       varchar2(4000));
    type t_nav_rows is table of t_nav_row;
    -- Release 104: the navigation menu of the running page for the signed-in user (XXFND_NAV_MENU_V), for an APEX
    -- list: select lvl, label, target, is_current, image, image_attribute, image_alt
    --         from table(xxfnd_nav_pkg.nav_menu) order by sort_path
    function nav_menu return t_nav_rows pipelined;
end xxfnd_nav_pkg;
/

create or replace package body xxfnd_nav_pkg as
    function nav_menu return t_nav_rows pipelined is
        l_row t_nav_row;
    begin
        for r in (select lvl, label, target, is_current, image, image_attribute, image_alt, sort_path
                    from xxfnd_nav_menu_v) loop
            l_row.lvl             := r.lvl;
            l_row.label           := r.label;
            l_row.target          := r.target;
            l_row.is_current      := r.is_current;
            l_row.image           := r.image;
            l_row.image_attribute := r.image_attribute;
            l_row.image_alt       := r.image_alt;
            l_row.sort_path       := r.sort_path;
            pipe row (l_row);
        end loop;
        return;
    end nav_menu;
end xxfnd_nav_pkg;
/
