--------------------------------------------------------------------------------
-- 31 Basic onboarding and the application menu (release 87). COMMON only (XXFUSION), after 30.
--   XXFND_ONBOARD_PKG.ONBOARD_SELF: the bare minimum an application needs to use the common components, called from
--   the application's own install (generic script 00c-onboard-with-common.sql, run as the application's schema): it
--   registers the APEX application of that schema through XXFND_APPLICATION_PKG.ONBOARD (registration rows, grants to
--   the schema, the <CODE>_ADMIN role, the menu entries). Nothing else (no APEX setting); the full onboarding is the
--   Application Journey (page 165). IT switches it off with the COMMON setting ONBOARD_SELF_ALLOWED = N.
--   Release 105: XXFND_APP_MENU_V (release 87, an application's navigation list) is no longer used - every
--   navigation comes from XXFND_NAV_PKG.NAV_MENU (31b, 31c) - and 31c drops it.
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_error_pkg.register_message('XXFND_REG_WRONG_CALLER',
        'Application {1} may only be changed by itself or by COMMON (called by {2}).', -20192);
    xxfnd_error_pkg.register_message('XXFND_ONBOARD_SELF_OFF',
        'Applications may not register themselves here: ask IT to register the application in COMMON (Applications).', -20193);
    xxfnd_error_pkg.register_message('XXFND_ONBOARD_SELF_APP',
        'No single APEX application of schema {1} matches {2}: give the application code (its alias).', -20194);
    xxfnd_error_pkg.register_message('XXFND_MENU_TARGET',
        'Menu entry {1}: the target type is COMMON_PAGE, APP_PAGE, MANAGED or SHARED_SETUP, and a page needs its number.', -20195);
    commit;
end;
/
