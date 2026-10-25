--------------------------------------------------------------------------------
-- 16j XXFND_USER_PKG - the Users & Access component (release 79: one package for the users).
--   Release 46: users of the shared access module. A LOCAL user gets an Oracle APEX account (APEX keeps the
--   password); the account is created / locked / reset here, from the access console, with the
--   workspace-administrator rights the APEX API needs (the user's own session is detached for the call).
--   Release 79 merges into it the user parts of XXFND_SECURITY_PKG (sign-in mapping, rename, first administrator)
--   and XXFND_AUTH_PKG (post-authentication of every sign-in scheme, the authorization-scheme entry, Fusion
--   groups); both are dropped here (old callers break on purpose: no wrappers). Role checks and segregation of
--   duties moved to XXFND_PRIVILEGE_PKG (09b), the Fusion HCM sync to XXFND_INTEGRATION_PKG (05b).
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_user_pkg authid definer as

    -- the collection of the signed-in user's Fusion roles / identity-domain groups
    -- (C001 group / display name, C002 role code, C003 description, C004 role id)
    c_roles_collection constant varchar2(30)  := 'FA_USER_ROLES';
    -- the REST Data Source (static ID) of the application that returns the user's Fusion roles
    c_roles_source     constant varchar2(100) := 'common-features-user-roles';

    ----------------------------------------------------------------------------
    -- Users
    ----------------------------------------------------------------------------
    -- An SSO user for an employee (returns the existing one when there is one).
    function employee_user(p_employee_id in number) return number;

    -- A LOCAL user with an Oracle APEX account. P_PASSWORD: the first password; the user changes it at first sign-in.
    function create_local_user(p_user_name in varchar2,
                               p_full_name in varchar2,
                               p_email     in varchar2,
                               p_password  in varchar2) return number;
    -- Release 99: the Oracle APEX account of an existing user (e.g. a user that signed in with a database account), so
    -- the user can sign in with a user name and password as well as with the company account (SSO, linked by user name
    -- or e-mail). P_PASSWORD: the first password, changed at first sign-in. Returns Y when the account was created, N when
    -- the user already has one.
    function ensure_apex_account(p_user_id in number, p_password in varchar2) return varchar2;

    -- New password for a LOCAL user (the user changes it at the next sign-in).
    procedure reset_password(p_user_id in number, p_password in varchar2);

    -- Enable / disable a user; a LOCAL user's APEX account is unlocked / locked with it.
    procedure set_enabled(p_user_id in number, p_enabled in varchar2);

    -- Y when the user is a LOCAL user (APEX account), N for SSO, null when unknown.
    function is_local(p_user_name in varchar2) return varchar2;

    -- Release 103: the application a user works in, for the Home of COMMON's shared pages when the user may not open
    -- COMMON Home: the APEX alias of the user's first active application other than COMMON (Users & Access), or null.
    function home_application(p_user_name in varchar2 default null) return varchar2;

    -- Release 79: the details an administrator maintains on the User screen. A LOCAL user's name and e-mail are
    -- kept here; an SSO user's come from the employee.
    procedure save_user(p_user_id       in number,
                        p_full_name     in varchar2,
                        p_email         in varchar2,
                        p_language_code in varchar2,
                        p_end_date      in date,
                        p_description   in varchar2);

    -- Release 79: the user-role pair, the same call from the User and the Role screen. ASSIGN_ROLE does nothing when
    -- the user holds the role already and refuses a role that conflicts with one the user holds (segregation of
    -- duties, global rules); UNASSIGN_ROLE ends the grant today (the row is kept for the audit).
    procedure assign_role(p_user_id in number, p_role_code in varchar2);
    procedure unassign_role(p_user_role_id in number);
    -- Release 96: a user's access to an application (one user, several applications). ASSIGN_ROLE grants it for the
    -- role's application when missing; END_APPLICATION ends the access and the user's roles of that application.
    procedure grant_application(p_user_id in number, p_application_code in varchar2);
    procedure end_application(p_user_id in number, p_application_code in varchar2);

    -- Moves every stored reference to a user name to a new one: request, case, approval, delegation and RFI
    -- user columns, the WHO columns of all XXFND_/XXCMP_ tables, and the potential owners of open workflow tasks.
    -- The audit log keeps the old name. Run by trigger XXHR_EMPLOYEES_RENAME when an employee's user name changes.
    procedure rename_user(p_old_user_name in varchar2, p_new_user_name in varchar2);
    -- True while RENAME_USER runs: record locks (closed cases) let the user name columns change.
    function renaming return boolean;

    -- Creates (or re-enables) a LOCAL employee and grants P_ROLE_CODE (the installer, so someone can sign in
    -- and grant further access).
    procedure bootstrap_admin(p_user_name in varchar2,
                              p_full_name in varchar2 default null,
                              p_email     in varchar2 default null,
                              p_role_code in varchar2 default 'SYSTEM_ADMIN');

    ----------------------------------------------------------------------------
    -- Authentication (post-authentication procedures of the sign-in schemes)
    ----------------------------------------------------------------------------
    -- The name the person signed in with (the e-mail with Database or APEX Accounts; the identity-domain user name
    -- with single sign-on) is mapped to the user's / employee's USER_NAME, which becomes APP_USER.
    procedure map_login_user;
    -- Post-authentication of Oracle APEX Accounts and Oracle Database Accounts.
    procedure post_auth_local;
    -- Post-authentication of the identity-domain (single sign-on) scheme.
    procedure post_auth_sso;
    -- The user's Fusion roles and identity-domain groups as dynamic groups.
    -- P_USER_NAME: the Fusion user name to ask for (default APP_USER).
    procedure load_user_roles(p_user_name in varchar2 default null);

    ----------------------------------------------------------------------------
    -- Authorization
    ----------------------------------------------------------------------------
    -- One entry for the authorization schemes: KYC_USER / APP_USER, PAGE_VIEW, PAGE_CREATE, PAGE_MANAGE, PAGE_SUBMIT,
    -- WORKFLOW_ADMINISTER, ADMIN_AREA, ADMIN_APP,
    -- SIGNED_IN (release 87: any enabled user - the shared pages of COMMON, which show only the
    -- user's own data). Reads APP_PAGE_ID, REQUEST and the Global Page party context from session state.
    function authorized(p_scheme in varchar2) return boolean;
    -- True when the signed-in user has the Fusion role / identity-domain group (dynamic group) P_GROUP.
    function in_group(p_group in varchar2) return boolean;

end xxfnd_user_pkg;
/
