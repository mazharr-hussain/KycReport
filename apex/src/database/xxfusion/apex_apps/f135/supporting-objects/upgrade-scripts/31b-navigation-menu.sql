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
    -- running application (release 105: COMMON's own menu is kept in the registry too)
    select upper(v('APP_ALIAS'))                              as cur_alias,
           to_number(v('APP_PAGE_ID'))                        as cur_page,
           upper(coalesce(v('G_WORK_APP'), v('APP_ALIAS')))   as menu_alias
      from dual
     where nvl(upper(v('APP_USER')), 'NOBODY') <> 'NOBODY'),
cur as (
    select max(fp.feature_code) as feature_code
      from xxfnd_feature_pages fp, ctx
     where upper(fp.app_alias) = ctx.cur_alias and fp.page_id = ctx.cur_page),
app_entries as (
    select e.application_code, e.entry_code, e.parent_code, e.target_type, e.page_id, e.icon_css,
           e.display_sequence, e.menu_code,
           -- release 105: the user menu is labelled with the user's name
           case when e.target_type = 'USER_MENU' then v('APP_USER') else e.label end as label,
           xxfnd_application_pkg.entry_visible(e.application_code, e.target_type, e.page_id, e.feature_code,
                                               e.enabled_flag) as visible,
           xxfnd_application_pkg.menu_url(e.application_code, e.target_type, e.page_id, e.feature_code) as target,
           (select max(fp.feature_code) from xxfnd_feature_pages fp
             where upper(fp.app_alias) = ctx.menu_alias and fp.page_id = e.page_id) as page_feature,
           ctx.cur_alias, ctx.cur_page, ctx.menu_alias
      from xxfnd_app_menu_entries e
      join xxfnd_applications a on a.application_code = e.application_code
      cross join ctx
     where upper(a.apex_app_alias) = ctx.menu_alias),
-- the entries the user sees, top down: a hidden entry hides what is inside it
app_tree as (
    select x.*, level as lvl,
           sys_connect_by_path(to_char(x.display_sequence, 'fm0000000') || x.label, '/') as sort_path,
           sys_connect_by_path(x.entry_code, '/') || '/' as code_path
      from app_entries x
     start with x.parent_code is null and x.visible = 'Y'
   connect by prior x.entry_code = x.parent_code and x.visible = 'Y')
select t.menu_code, t.lvl, t.label, t.target,
       case when t.target_type in ('APP_PAGE', 'ADMIN_PAGE') and t.cur_alias = t.menu_alias
                 and (t.page_id = t.cur_page
                      or (t.page_feature is not null and t.page_feature = (select feature_code from cur)))
            then 'YES'
            when t.target_type = 'COMMON_PAGE' and t.cur_alias = 'COMMON' and t.page_id = t.cur_page then 'YES'
            else 'NO' end as is_current,
       t.icon_css as image,
       cast(null as varchar2(100)) as image_attribute,
       cast(null as varchar2(100)) as image_alt,
       -- the navigation bar's badge (the user's unread notifications) and the user menu's class
       case when t.page_id = 43 and (t.target_type = 'COMMON_PAGE' or t.menu_alias = 'COMMON')
            then v('NOTIFY_COUNT') end as a01,
       case when t.target_type = 'USER_MENU' then 'has-username' end as a02,
       t.sort_path
  from app_tree t
 where t.target_type not in ('FOLDER', 'USER_MENU')
    or exists (select 1 from app_tree c
                where instr(c.code_path, t.code_path) = 1 and c.target_type not in ('FOLDER', 'USER_MENU'));

comment on table xxfnd_nav_menu_v is 'Release 104 / 105: the navigation of the running page for the signed-in user (an APEX list per MENU_CODE: SIDE, TOP_BAR, ADMIN; ordered by SORT_PATH): the menus of the application kept in COMMON (XXFND_APP_MENU_ENTRIES, shown by privileges); in COMMON those of COMMON or of the application the page is used from (G_WORK_APP).';

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
        a01             varchar2(4000),
        a02             varchar2(4000),
        sort_path       varchar2(4000));
    type t_nav_rows is table of t_nav_row;
    -- Release 104: the navigation menu of the running page for the signed-in user (XXFND_NAV_MENU_V), for an APEX
    -- list: select lvl, label, target, is_current, image, image_attribute, image_alt
    --         from table(xxfnd_nav_pkg.nav_menu) order by sort_path
    -- Release 105: P_MENU_CODE SIDE (navigation menu), TOP_BAR (navigation bar; A01 = badge, A02 = class) or ADMIN.
    function nav_menu(p_menu_code in varchar2 default 'SIDE') return t_nav_rows pipelined;
end xxfnd_nav_pkg;
/

create or replace package body xxfnd_nav_pkg as
    function nav_menu(p_menu_code in varchar2 default 'SIDE') return t_nav_rows pipelined is
        l_row t_nav_row;
    begin
        for r in (select lvl, label, target, is_current, image, image_attribute, image_alt, a01, a02, sort_path
                    from xxfnd_nav_menu_v where menu_code = upper(nvl(p_menu_code, 'SIDE'))) loop
            l_row.lvl             := r.lvl;
            l_row.label           := r.label;
            l_row.target          := r.target;
            l_row.is_current      := r.is_current;
            l_row.image           := r.image;
            l_row.image_attribute := r.image_attribute;
            l_row.image_alt       := r.image_alt;
            l_row.a01             := r.a01;
            l_row.a02             := r.a02;
            l_row.sort_path       := r.sort_path;
            pipe row (l_row);
        end loop;
        return;
    end nav_menu;
end xxfnd_nav_pkg;
/
