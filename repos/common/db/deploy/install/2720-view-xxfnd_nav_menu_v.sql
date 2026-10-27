
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
