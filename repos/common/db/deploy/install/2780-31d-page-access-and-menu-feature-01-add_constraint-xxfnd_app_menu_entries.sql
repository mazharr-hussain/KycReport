--------------------------------------------------------------------------------
-- 31d Page access by privilege and the Application Menu feature (release 106). COMMON only (XXFUSION), after 35.
--   1. Access to a COMMON page is the privilege a role gives, from any application; what a COMMON setup screen shows
--      follows the applications whose roles give it (XXFND_APPLICATION_PKG.FEATURE_APPS / SCOPE_PREDICATE, 09d).
--      The "managed in the application" access of release 73 is retired: XXFND_APPLICATION_FUNCTIONS.MANAGED_IN_APP_FLAG
--      is no longer read (kept read-only), entry page 99 is gone, and the menu entry type MANAGED becomes a COMMON
--      page entry (the function's home page, shown by its privilege; hidden when the application did not manage it,
--      so nobody sees an entry he did not see before).
--   2. Application Menu is a feature of its own in the Reference Data module (with Lookups and Flexfields): pages 169
--      (All Pages: every page of every application and who uses it), 167 (Menu by Application) and 168 (an entry).
--      Roles with an Applications privilege get the same Application Menu privilege.
-- Idempotent: rows and constraints are added only when missing; the conversion touches only MANAGED rows.
--------------------------------------------------------------------------------
declare
    l_n pls_integer;
begin
    xxfnd_util_pkg.set_install_mode(true);

    -- 2. the feature, its privileges (the Applications rights of every role) and its pages
    xxfnd_privilege_pkg.register_feature('COMMON', 'APPLICATION_MENU', 'Application Menu', 'REFERENCE_DATA', 330, 'Y',
                                         169, 'fa-sitemap',
                                         'The menus of every application in one place, and every page with who uses it.');
    for a in (select column_value action from table(apex_t_varchar2('VIEW', 'CREATE', 'MANAGE'))) loop
        xxfnd_privilege_pkg.register_privilege('COMMON', 'APPLICATION_MENU', a.action);
        merge into xxfnd_role_privileges t
        using (select rp.role_code from xxfnd_role_privileges rp where rp.privilege_code = 'APPLICATIONS.' || a.action) s
           on (t.role_code = s.role_code and t.privilege_code = 'APPLICATION_MENU.' || a.action)
         when not matched then insert (role_code, privilege_code) values (s.role_code, 'APPLICATION_MENU.' || a.action);
    end loop;
    update xxfnd_feature_pages
       set feature_code = 'APPLICATION_MENU'
     where app_alias = 'COMMON' and page_id in (167, 168) and feature_code = 'APPLICATIONS';
    xxfnd_privilege_pkg.register_feature_page('COMMON', 'APPLICATION_MENU', 169, 'All Pages', 10);
    update xxfnd_feature_pages set tab_label = 'Menu by Application', tab_sequence = 20
     where app_alias = 'COMMON' and page_id = 167 and feature_code = 'APPLICATION_MENU' and tab_label is null;

    -- 1. MANAGED entries become COMMON page entries (the function's home page; Shared Setup when it has none)
    update xxfnd_app_menu_entries e
       set e.page_id      = (select f.home_page_id from xxfnd_features f where f.feature_code = e.feature_code),
           e.target_type  = case when (select f.home_page_id from xxfnd_features f where f.feature_code = e.feature_code)
                                      is null then 'SHARED_SETUP' else 'COMMON_PAGE' end,
           e.enabled_flag = case when e.enabled_flag = 'Y'
                                  and exists (select 1 from xxfnd_application_functions af
                                               where af.application_code = e.application_code
                                                 and af.feature_code = e.feature_code
                                                 and af.managed_in_app_flag = 'Y')
                                 then 'Y' else 'N' end
     where e.target_type = 'MANAGED';
    commit;

    -- the entry types without MANAGED
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK11',
        q'~check (target_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'SHARED_SETUP', 'FOLDER', 'USER_MENU', 'SIGN_OUT', 'SEPARATOR'))~');
    xxfnd_ddl_pkg.add_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK12',
        q'~check (target_type in ('SHARED_SETUP', 'FOLDER', 'USER_MENU', 'SIGN_OUT', 'SEPARATOR') or page_id is not null)~');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK8');
    xxfnd_ddl_pkg.drop_constraint('XXFND_APP_MENU_ENTRIES', 'XXFND_APP_MENU_ENTRIES_CK9');
    execute immediate q'~comment on column xxfnd_app_menu_entries.target_type is 'COMMON_PAGE: a COMMON page (shown by its privilege); APP_PAGE: a page of the application; ADMIN_PAGE: a page for the administrators; SHARED_SETUP: COMMON Administration (page 100); FOLDER: a parent of other entries; USER_MENU: the user''s name (a parent); SIGN_OUT; SEPARATOR. Release 106: MANAGED retired.'~';
    execute immediate q'~comment on column xxfnd_application_functions.managed_in_app_flag is 'Release 106: no longer used (read-only). Release 73-105: Y = the application''s administrators maintained the function''s setup themselves (COMMON page 99).'~';

    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
