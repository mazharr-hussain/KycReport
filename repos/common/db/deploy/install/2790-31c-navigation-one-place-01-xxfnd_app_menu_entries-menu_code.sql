--------------------------------------------------------------------------------
-- 31c Navigation in one place (release 105). COMMON only (XXFUSION), after 31b.
--   Every navigation of every application, COMMON included, is kept in the registry XXFND_APP_MENU_ENTRIES and shown
--   by privileges (XXFND_NAV_PKG.NAV_MENU):
--   - MENU_CODE: SIDE (the navigation menu), TOP_BAR (the navigation bar) or ADMIN (administration).
--   - New entry types for the navigation bar: USER_MENU (the user's name, a parent), SIGN_OUT and SEPARATOR.
--   - COMMON's own menu and navigation bar are registry rows now (XXFND_APPLICATION_PKG.SYNC_MENU: Home, My Tasks,
--     the modules with their features; Notifications, Give Feedback, the user menu with Sign Out).
--   Navigation no longer used is removed: the view XXFND_APP_MENU_V (release 87, replaced by XXFND_NAV_PKG.NAV_MENU)
--   and, on the application pages, the second menu editor (Show / Hide on pages 165 / 166: page 167 only now).
--   Release 106: the entry type constraints are kept by 31b and 31d; this script runs after 31d (and 35), so COMMON's
--   menu gets an entry for every COMMON screen registered by the install.
-- Idempotent: rows are added only when missing.
--------------------------------------------------------------------------------
begin
    execute immediate q'~comment on column xxfnd_app_menu_entries.menu_code is 'Release 105: the navigation the entry belongs to - SIDE (navigation menu), TOP_BAR (navigation bar) or ADMIN (administration).'~';

    -- the release 87 navigation list, used by no application any more
    for v in (select view_name from user_views where view_name = 'XXFND_APP_MENU_V') loop
        execute immediate 'drop view ' || v.view_name;
    end loop;

    -- COMMON's own navigation, as registry rows
    xxfnd_application_pkg.sync_menu('COMMON');
    commit;
end;
/
