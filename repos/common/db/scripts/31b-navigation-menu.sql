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
--   Release 106: who uses a page (the Application Menu's page catalogue, XXFND_PAGE_CATALOGUE_V): the menus it is in,
--   the pages that link to it (XXFND_PAGE_LINKS_V, from the APEX definitions: buttons, branches, report and list
--   links) and the pages users really opened it from (XXFND_PAGE_OPENS, recorded by XXFND_NAV_PKG.RECORD_OPEN when a
--   COMMON page is opened from another application - this also catches links built in code).
-- Idempotent: constraints, tables and rows are added only when missing; the views are replaced.
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
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
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK6',
        q'~check (made_by in ('COMMON', 'APP', 'ADMIN'))~');
    -- release 106 fix: the entry types of release 105 directly (CK5 / CK7 of release 104 were re-added here on every
    -- run, and failed on a re-run once 31c had added the user menu entries); once release 106 has replaced them by
    -- CK11 / CK12 (31d: no MANAGED any more), nothing is added here
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK5');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK7');
    select count(*) into l_n from user_constraints
     where table_name = 'XXFND_APP_MENU_ENTRIES' and constraint_name = 'XXFND_APP_MENU_ENTRIES_CK11';
    if l_n = 0 then
        xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK8',
            q'~check (target_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'MANAGED', 'SHARED_SETUP', 'FOLDER', 'USER_MENU', 'SIGN_OUT', 'SEPARATOR'))~');
        xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK9',
            q'~check (target_type in ('MANAGED', 'SHARED_SETUP', 'FOLDER', 'USER_MENU', 'SIGN_OUT', 'SEPARATOR') or page_id is not null)~');
    end if;
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

-- release 106: the pages users opened a COMMON page from (another application's page), counted
begin
    if xxfnd_ddl_pkg.create_table('XXFND_PAGE_OPENS', q'~create table xxfnd_page_opens (
    from_app_alias         varchar2(255)  not null,
    from_page              varchar2(255)  not null,
    to_application_id      number         not null,
    to_page_id             number         not null,
    open_count             number         default 0 not null,
    first_opened_date      timestamp      not null,
    last_opened_date       timestamp      not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_page_opens_pk primary key (from_app_alias, from_page, to_application_id, to_page_id)
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_page_opens is 'Release 106: a COMMON page opened from a page of another application (the referrer), with how often and when; recorded by XXFND_NAV_PKG.RECORD_OPEN, shown as Opened From on the Application Menu page catalogue.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_page_opens.from_page is 'The page of the other application: its number or its alias, as in the URL.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_PAGE_OPENS');
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

-- release 106: every page of every registered application, one row per page (its owner application), with who uses
-- it: the menus it is in (its owner's, and for a COMMON page every application whose menu has it), the pages that link
-- to it (XXFND_PAGE_LINKS_V) and the pages users opened it from (XXFND_PAGE_OPENS). COMMON only (APEX metadata).
create or replace view xxfnd_page_catalogue_v as
with apps as (
    select x.application_code, x.application_name, a.application_id, upper(a.alias) as app_alias
      from xxfnd_applications x
      join apex_applications a on upper(a.alias) = upper(x.apex_app_alias)
     where a.workspace = (select max(c.workspace) from apex_applications c where upper(c.alias) = 'COMMON')),
pages as (
    select ap.application_code, ap.application_name, ap.application_id, ap.app_alias,
           p.page_id, p.page_name, upper(p.page_alias) as page_alias, p.page_mode
      from apps ap
      join apex_application_pages p on p.application_id = ap.application_id
     where p.page_id > 0),
links as (
    select l.from_application_id, l.from_page_id, l.link_source,
           case when l.target_app is null or substr(l.target_app, 1, 1) = chr(38) then l.from_application_id
                when regexp_like(l.target_app, '^[0-9]+$') then to_number(l.target_app)
                else (select max(ap.application_id) from apps ap where ap.app_alias = upper(l.target_app))
           end as target_application_id,
           upper(l.target_page) as target_page
      from xxfnd_page_links_v l)
select p.application_code,
       p.application_name,
       p.application_id,
       p.page_id,
       p.page_name,
       p.page_mode,
       fp.feature_code,
       f.feature_name,
       case when exists (select 1 from xxfnd_app_menu_entries e
                          where e.application_code = p.application_code and e.page_id = p.page_id
                            and (e.target_type in ('APP_PAGE', 'ADMIN_PAGE')
                                 or (e.target_type = 'COMMON_PAGE' and p.application_code = 'COMMON')))
            then 'Y' else 'N' end as in_own_menu,
       (select listagg(distinct e.application_code, ', ') within group (order by e.application_code)
          from xxfnd_app_menu_entries e
         where p.application_code = 'COMMON' and e.target_type = 'COMMON_PAGE' and e.page_id = p.page_id
           and e.application_code <> 'COMMON') as in_menus_of,
       (select listagg(distinct nvl(fa.application_code, to_char(lk.from_application_id))
                                || nvl2(lk.from_page_id, ' ' || lk.from_page_id, '') || ' (' || lk.link_source || ')',
                       ', ' on overflow truncate)
                   within group (order by nvl(fa.application_code, to_char(lk.from_application_id))
                                          || nvl2(lk.from_page_id, ' ' || lk.from_page_id, '') || ' (' || lk.link_source || ')')
          from links lk
          left join apps fa on fa.application_id = lk.from_application_id
         where lk.target_application_id = p.application_id
           and (lk.target_page = to_char(p.page_id) or lk.target_page = p.page_alias)
           and not (lk.from_application_id = p.application_id and nvl(lk.from_page_id, -1) = p.page_id)) as linked_from,
       (select listagg(o.from_app_alias || ' ' || o.from_page || ' (' || o.open_count || 'x, last '
                       || to_char(o.last_opened_date, 'DD-MON-YYYY') || ')', ', ' on overflow truncate)
                   within group (order by o.last_opened_date desc)
          from xxfnd_page_opens o
         where o.to_application_id = p.application_id and o.to_page_id = p.page_id) as opened_from,
       case when exists (select 1 from xxfnd_app_menu_entries e
                          where p.application_code = 'COMMON' and e.target_type = 'COMMON_PAGE'
                            and e.page_id = p.page_id and e.application_code <> 'COMMON')
              or exists (select 1 from links lk
                          where lk.target_application_id = p.application_id
                            and (lk.target_page = to_char(p.page_id) or lk.target_page = p.page_alias)
                            and lk.from_application_id <> p.application_id)
              or exists (select 1 from xxfnd_page_opens o
                          where o.to_application_id = p.application_id and o.to_page_id = p.page_id)
            then 'Y' else 'N' end as used_by_other_apps
  from pages p
  left join xxfnd_feature_pages fp on upper(fp.app_alias) = p.app_alias and fp.page_id = p.page_id
  left join xxfnd_features f on f.feature_code = fp.feature_code;

comment on table xxfnd_page_catalogue_v is 'Release 106: every page of every registered application (one row per page, its owner) with its privilege and who uses it - In Own Menu, In Menus Of (a COMMON page in other applications'' menus), Linked From (APEX definitions), Opened From (recorded). The catalogue of the Application Menu screen. COMMON only.';

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
    -- Release 106: a COMMON page was opened from another application's page (P_REFERRER: the browser's referrer URL,
    -- friendly /r/<workspace>/<app>/<page> or f?p=APP:PAGE): counted in XXFND_PAGE_OPENS (Opened From). Nothing for
    -- a page of the same application or an unknown referrer; never fails the page.
    procedure record_open(p_referrer in varchar2);
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

    procedure record_open(p_referrer in varchar2) is
        pragma autonomous_transaction;
        l_app  varchar2(255);
        l_page varchar2(255);
    begin
        if p_referrer is null then
            return;
        elsif regexp_like(p_referrer, '/r/[^/]+/[^/?#]+/[^/?#]+', 'i') then
            l_app  := upper(regexp_substr(p_referrer, '/r/[^/]+/([^/?#]+)/([^/?#]+)', 1, 1, 'i', 1));
            l_page := upper(regexp_substr(p_referrer, '/r/[^/]+/([^/?#]+)/([^/?#]+)', 1, 1, 'i', 2));
        else
            l_app  := upper(regexp_substr(p_referrer, 'f\?p=([^:&]+):([^:&]*)', 1, 1, 'i', 1));
            l_page := upper(regexp_substr(p_referrer, 'f\?p=([^:&]+):([^:&]*)', 1, 1, 'i', 2));
        end if;
        if l_app is null or l_page is null or l_app in (upper(v('APP_ALIAS')), v('APP_ID')) then
            return;
        end if;
        merge into xxfnd_page_opens t
        using (select substr(l_app, 1, 255) from_app_alias, substr(l_page, 1, 255) from_page,
                      to_number(v('APP_ID')) to_application_id, to_number(v('APP_PAGE_ID')) to_page_id
                 from dual) x
           on (t.from_app_alias = x.from_app_alias and t.from_page = x.from_page
               and t.to_application_id = x.to_application_id and t.to_page_id = x.to_page_id)
         when matched then update set t.open_count = t.open_count + 1, t.last_opened_date = systimestamp
         when not matched then insert (from_app_alias, from_page, to_application_id, to_page_id, open_count,
                                       first_opened_date, last_opened_date)
                               values (x.from_app_alias, x.from_page, x.to_application_id, x.to_page_id, 1,
                                       systimestamp, systimestamp);
        commit;
    exception
        when others then
            rollback;    -- the record is a statistic: the page opens all the same
    end record_open;
end xxfnd_nav_pkg;
/
