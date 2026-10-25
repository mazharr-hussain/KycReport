-- Onboard an APEX application on COMMON (release 86). Run as XXFUSION (the COMMON schema) in SQLcl / SQL*Plus,
-- after the application is imported into the workspace. Safe to re-run: the registration is refreshed from APEX and
-- what the administrators changed since (switches, description, the administrator role's privileges) is kept.
-- What it does (XXFND_APPLICATION_PKG.ONBOARD):
--   - registers the application (name, alias and parsing schema from APEX; grants on the shared objects to its schema;
--     one row per common function, not managed in the application; its workflow processes, the shared ones off);
--   - creates the role <CODE>_ADMIN with every privilege of the application's features and gives it to the
--     administrator user when one is named (the user must exist, or is created as in the first-administrator setup);
--   - the default notification rules (for every application) apply; documents are kept in the database until IT sets
--     up storage for the application.
-- Prompts for:
--   apex_app_id   APEX application ID in this workspace (e.g. 134)
--   app_code      application code, up to 30 capital letters, digits or _ (e.g. KYC)
--   description   short description (may be empty)
--   email_on      Y = e-mail on for the application, N = off
--   admin_user    user name of the application's administrator (may be empty)
set define on verify off serveroutput on feedback off
accept apex_app_id prompt 'APEX application ID: '
accept app_code    prompt 'Application code: '
accept description prompt 'Description (optional): '
accept email_on    default 'Y' prompt 'E-mail on (Y/N) [Y]: '
accept admin_user  prompt 'Administrator user name (optional): '

declare
    l_ws varchar2(255);
begin
    -- the workspace of COMMON (the APEX dictionary is read for it)
    select max(workspace) into l_ws from apex_applications
     where application_id = (select apex_application_id from xxfnd_applications where application_code = 'COMMON');
    if l_ws is not null then
        apex_util.set_workspace(l_ws);
    end if;
    xxfnd_application_pkg.onboard(p_apex_application_id => to_number('&apex_app_id'),
                                  p_application_code    => q'[&app_code]',
                                  p_description         => q'[&description]',
                                  p_email_enabled_flag  => upper(nvl(q'[&email_on]', 'Y')),
                                  p_admin_user          => q'[&admin_user]');
    commit;
    dbms_output.put_line('Onboarded ' || upper(trim(q'[&app_code]')) || ' (APEX application &apex_app_id).');
exception
    when others then
        rollback;
        raise;
end;
/
