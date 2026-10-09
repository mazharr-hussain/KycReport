--------------------------------------------------------------------------------
-- 21b Application functions (release 71) - the switches. COMMON only (XXFUSION), after 21. The table and
--   XXFND_APP_FUNCTION_PKG are in 09d (release 72).
--   IT registers the applications (XXFND_APPLICATIONS, page 160/161). Every common function works for every
--   application (release 73: no "Available" switch). Per application and function, IT decides whether the
--   application's administrators maintain the function's setup for their application from the application's own
--   menu (XXFND_APPLICATION_FUNCTIONS.MANAGED_IN_APP_FLAG, XXFND_APP_FUNCTION_PKG.IS_MANAGED).
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
-- every registered application has its switches (not managed in the application until IT switches one on)
begin
    xxfnd_util_pkg.set_install_mode(true);
    -- not a common function (any more): no switch
    delete from xxfnd_application_functions
     where feature_code not in (select column_value from table(xxfnd_app_function_pkg.common_functions));
    for a in (select application_code from xxfnd_applications) loop
        xxfnd_app_function_pkg.set_apex_id(a.application_code);   -- release 73: APEX ID known before the first sign-in
        xxfnd_app_function_pkg.ensure_rows(a.application_code);
    end loop;
    xxfnd_workflow_switch_pkg.sync_processes;   -- release 73: the workflow processes and their switches (09e)
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
