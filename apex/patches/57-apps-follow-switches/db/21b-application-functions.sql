--------------------------------------------------------------------------------
-- 21b Application functions (release 71) - the switches. COMMON only (XXFUSION), after 21. The table and
--   XXFND_APP_FUNCTION_PKG are in 09d (release 72).
--   IT registers the applications (XXFND_APPLICATIONS, page 160/161) and switches on, per application, the common
--   functions it may use (XXFND_APPLICATION_FUNCTIONS). The functions are the admin features with a COMMON setup
--   page (Lookups, Flexfields, Attachments, Notifications, Retention, Workflow Setup, Integrations, Users and Access,
--   Roles and Privileges, Data Security, Audit Log, Application Settings); a feature added there gets a switch too.
--   XXFND_APP_FUNCTION_PKG.IS_ENABLED(application, function) - Y / N - is what an application asks before it
--   shows or runs a common function; the COMMON setup forms list only applications with the function on.
-- Idempotent (release 69 rule: CREATE_TABLE only when missing; changes as checked steps).
--------------------------------------------------------------------------------
-- every registered application has its switches; the existing applications keep what they use today (all on)
declare
    l_new pls_integer;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_new from xxfnd_application_functions;
    -- not a common function (any more): no switch
    delete from xxfnd_application_functions
     where feature_code not in (select column_value from table(xxfnd_app_function_pkg.common_functions));
    for a in (select application_code from xxfnd_applications) loop
        xxfnd_app_function_pkg.ensure_rows(a.application_code);
    end loop;
    if l_new = 0 then
        -- first install of this release: nothing changes for the applications already in use
        update xxfnd_application_functions set enabled_flag = 'Y';
    end if;
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
