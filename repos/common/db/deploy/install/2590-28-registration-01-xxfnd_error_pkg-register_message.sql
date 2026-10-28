--------------------------------------------------------------------------------
-- 28 Registration and onboarding (release 86, part A). COMMON only (XXFUSION), after 27.
--   Every component registers an application's rows itself (one package per component, the routine in the package
--   that owns the table): XXFND_PRIVILEGE_PKG (features, pages, privileges, roles, role privileges, segregation of
--   duties), XXFND_VPD_PKG (data access rules), XXFND_LOOKUP_PKG (lookup types and values), XXFND_DFF_PKG (value
--   sets, flexfields, contexts), XXFND_ATTACH_PKG (document entities, categories, attachment pages; MOVE_DOCUMENTS),
--   XXFND_NOTIFY_PKG (notification wording), XXFND_WORKFLOW_PKG (task deadlines), XXFND_APPROVAL_RULE_PKG (a default
--   approval rule), XXFND_APPROVAL_PKG (configuration tables), XXFND_INTEGRATION_PKG (integration purposes).
--   Each adds only what is missing and keeps what an administrator changed; an application that is not registered
--   is refused (XXFND_APPLICATION_PKG.REGISTERED_CODE). XXFND_APPLICATION_PKG.ONBOARD registers an application from
--   its APEX application ID (apex/db/admin/onboard-application.sql).
--   This script: the catalogue messages of these routines (texts administrators may change are kept) and the
--   recompile. No table changes.
-- Idempotent: a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_error_pkg.register_message('XXFND_APP_NOT_REGISTERED',
        'Application {1} is not registered. Register it in Applications first.', -20180);
    xxfnd_error_pkg.register_message('XXFND_APP_APEX_NOT_FOUND',
        'APEX application {1} is not in this workspace.', -20181);
    xxfnd_error_pkg.register_message('XXFND_APP_APEX_TAKEN',
        'APEX application {1} is already registered as {2}.', -20182);
    xxfnd_error_pkg.register_message('XXFND_APP_CODE_INVALID',
        'Enter an application code of up to 30 capital letters, digits or _, starting with a letter ({1}).', -20183);
    xxfnd_error_pkg.register_message('XXFND_APP_DELETE_BLOCKED', '{1}', -20184);
    xxfnd_error_pkg.register_message('XXFND_APP_COMMON_ALWAYS', 'COMMON is always enabled: every application uses it.', -20185);
    xxfnd_error_pkg.register_message('XXFND_APP_DELETE_COMMON',
        'COMMON cannot be deleted: every application uses it.');
    xxfnd_error_pkg.register_message('XXFND_APP_DELETE_ENABLED',
        'Disable application {1} before you delete it.');
    xxfnd_error_pkg.register_message('XXFND_APP_DELETE_DATA',
        'Application {1} cannot be deleted: data refers to it ({2}).');
    xxfnd_error_pkg.register_message('XXFND_REG_OTHER_APP', '{1} {2} belongs to application {3}.', -20186);
    xxfnd_error_pkg.register_message('XXFND_REG_UNKNOWN', '{1} {2} is not registered.', -20187);
    xxfnd_error_pkg.register_message('XXFND_REG_RULE_STEP',
        'Approval step "{1}": write "name=ROLE=role code", "name=USER=user name" or "name=REQUESTER".', -20188);
    xxfnd_error_pkg.register_message('XXFND_REG_DFF_TABLE', 'Table {1} already has the flexfield {2}.', -20190);
    xxfnd_error_pkg.register_message('XXFND_REG_PAGE_TAKEN',
        'Page {2} of {1} is already registered as attachment page {3}.', -20191);
    commit;
end;
/

-- anything a change above left invalid is compiled again (no install error, no stale package state)
begin
    dbms_utility.compile_schema(schema => user, compile_all => false);
end;
/
