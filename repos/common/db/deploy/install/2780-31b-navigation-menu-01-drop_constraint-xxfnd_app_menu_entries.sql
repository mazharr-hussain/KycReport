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
