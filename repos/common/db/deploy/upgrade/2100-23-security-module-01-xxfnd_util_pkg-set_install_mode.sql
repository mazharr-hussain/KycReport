--------------------------------------------------------------------------------
-- 23 COMMON Security module (release 79). COMMON only (XXFUSION), after 22.
--   Users & Access, Roles & Privileges and Data Security work as one module: a data access rule is assigned to
--   users and roles (XXFND_DATA_RULE_ASSIGNMENTS, 09b), the three screens share one Assign dialog (page 183).
--   This script brings the descriptions an existing installation already has in line with that; a fresh install
--   gets them from the admin seed (19c).
-- Idempotent: guarded updates; a re-run changes nothing.
--------------------------------------------------------------------------------
begin
    xxfnd_util_pkg.set_install_mode(true);
    update xxfnd_features set description = 'Users, their roles and their data access.'
     where feature_code = 'USERS_ACCESS' and description = 'Employees and the roles they hold.';
    update xxfnd_features set description = 'Data access rules: which rows each user and role can see.'
     where feature_code = 'DATA_SECURITY' and description = 'Which rows each role can see.';
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
