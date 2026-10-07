--------------------------------------------------------------------------------
-- 16j Authentication and authorization (release 45)
--   XXFND_AUTH_PKG: everything the application's authentication and authorization schemes run, in the
--   database; the schemes only call this package.
--   * Authentication (post-authentication procedures):
--       post_auth_local - Oracle APEX / Database Accounts: the login (e-mail) becomes the employee's user name.
--       post_auth_sso   - OCI IAM identity domain (social sign-in): the same mapping, then the user's Fusion
--                         roles (REST Data Source common-features-user-roles) and identity-domain groups go
--                         into the collection FA_USER_ROLES and become APEX dynamic groups (fa_get_user_roles).
--   * Authorization: authorized(<scheme>) for every authorization scheme of the application; in_group for the
--     Fusion / identity-domain groups of the signed-in user.
--   Shared by every application (COMMON installs it too); KYC-only rules call their packages dynamically.
-- Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create or replace package xxfnd_auth_pkg authid definer as

    -- the collection of the signed-in user's Fusion roles / identity-domain groups
    -- (C001 group / display name, C002 role code, C003 description, C004 role id)
    c_roles_collection constant varchar2(30)  := 'FA_USER_ROLES';
    -- the REST Data Source (static ID) of the application that returns the user's Fusion roles
    c_roles_source     constant varchar2(100) := 'common-features-user-roles';

    ----------------------------------------------------------------------------
    -- Authentication
    ----------------------------------------------------------------------------
    -- Post-authentication of Oracle APEX Accounts and Oracle Database Accounts.
    procedure post_auth_local;
    -- Post-authentication of the identity-domain scheme (APEX_FA_IABWBN-DEV1_OAUTH).
    procedure post_auth_sso;
    -- The user's Fusion roles and identity-domain groups as dynamic groups (the former fa_get_user_roles).
    -- P_USER_NAME: the Fusion user name to ask for (default APP_USER).
    procedure load_user_roles(p_user_name in varchar2 default null);

    ----------------------------------------------------------------------------
    -- Authorization
    ----------------------------------------------------------------------------
    -- One entry for the authorization schemes: KYC_USER / APP_USER, PAGE_VIEW, PAGE_CREATE, PAGE_MANAGE, PAGE_SUBMIT,
    -- WORKFLOW_ADMINISTER, ADMIN_AREA, PARTY_DETAILS_VIEW, PARTY_DETAILS_CREATE, PARTY_DETAILS_MANAGE,
    -- PARTY_DETAILS_SUBMIT. Reads APP_PAGE_ID, REQUEST and the Global Page party context from session state.
    function authorized(p_scheme in varchar2) return boolean;
    -- True when the signed-in user has the Fusion role / identity-domain group (dynamic group) P_GROUP.
    function in_group(p_group in varchar2) return boolean;

end xxfnd_auth_pkg;
/

create or replace package body xxfnd_auth_pkg as

    ----------------------------------------------------------------------------
    -- Authentication
    ----------------------------------------------------------------------------
    -- release 46: each user signs in the way their type says (app setting LOGIN_TYPE_ENFORCED = Y):
    -- SSO users (linked to an employee) with the company account only, LOCAL users with their APEX account only
    function login_type_enforced return boolean is
        l_value varchar2(30);
    begin
        begin
            l_value := apex_app_setting.get_value('LOGIN_TYPE_ENFORCED');
        exception
            when others then
                l_value := null;
        end;
        return upper(l_value) = 'Y';
    end login_type_enforced;

    function user_type return varchar2 is
        l_type xxfnd_users.user_type%type;
    begin
        select max(user_type) into l_type from xxfnd_users where user_name = upper(v('APP_USER'));
        return l_type;
    end user_type;

    procedure post_auth_local is
    begin
        xxfnd_privilege_pkg.sync_current_application;
        xxfnd_security_pkg.map_login_user;
        if login_type_enforced and user_type = 'SSO' then
            raise_application_error(-20066, 'Sign in with your company account (Sign in with SSO).');
        end if;
    end post_auth_local;

    procedure load_user_roles(p_user_name in varchar2 default null) is
        l_params   apex_exec.t_parameters;
        l_context  apex_exec.t_context;
        l_id_idx   pls_integer;
        l_val_idx  pls_integer;
        l_desc_idx pls_integer;
        l_disp_idx pls_integer;
        l_groups   apex_t_varchar2 := apex_t_varchar2();

        procedure add_dyn_group(p_group in varchar2,
                                p_code  in varchar2 default null,
                                p_desc  in varchar2 default null,
                                p_id    in varchar2 default null) is
            l_count number;
        begin
            if p_group is null then
                return;
            end if;
            select count(*) into l_count
              from apex_collections
             where collection_name = c_roles_collection and c001 = p_group;
            if l_count = 0 then
                -- the details of the Fusion role
                apex_collection.add_member(p_collection_name => c_roles_collection,
                                           p_c001 => p_group, p_c002 => p_code, p_c003 => p_desc, p_c004 => p_id);
                -- the role becomes a dynamic group
                apex_string.push(p_table => l_groups, p_value => p_group);
            end if;
        end add_dyn_group;
    begin
        apex_collection.create_or_truncate_collection(c_roles_collection);

        -- the groups from Fusion (REST Data Source of the application); skipped when it cannot be called
        begin
            apex_exec.add_parameter(l_params, 'USER_NAME', nvl(p_user_name, v('APP_USER')));
            l_context := apex_exec.open_rest_source_query(p_static_id  => c_roles_source,
                                                          p_max_rows   => 1000,
                                                          p_parameters => l_params);
            l_id_idx   := apex_exec.get_column_position(l_context, 'ID');
            l_val_idx  := apex_exec.get_column_position(l_context, 'VALUE');
            l_desc_idx := apex_exec.get_column_position(l_context, 'DESCRIPTION');
            l_disp_idx := apex_exec.get_column_position(l_context, 'DISPLAY_NAME');
            while apex_exec.next_row(l_context) loop
                add_dyn_group(p_group => apex_exec.get_varchar2(l_context, l_disp_idx),
                              p_code  => apex_exec.get_varchar2(l_context, l_val_idx),
                              p_desc  => apex_exec.get_varchar2(l_context, l_desc_idx),
                              p_id    => apex_exec.get_varchar2(l_context, l_id_idx));
            end loop;
            apex_exec.close(l_context);
        exception
            when others then
                apex_exec.close(l_context);
                apex_debug.warn('Cannot get the user''s groups from Fusion Apps: %0', sqlerrm);
        end;

        -- the groups from the identity domain (user info of the sign-in): the name only, but possibly more groups
        -- than Fusion, or the only ones when Fusion cannot be called
        for g in 1 .. nvl(apex_json.get_count(p_path => 'groups'), 0) loop
            add_dyn_group(apex_json.get_varchar2(p_path => 'groups[%0].name', p0 => g));
        end loop;

        apex_authorization.enable_dynamic_groups(p_group_names => l_groups);
    exception
        when others then
            apex_debug.error('Error in xxfnd_auth_pkg.load_user_roles: %0', sqlerrm);
            apex_debug.log_long_message(p_message => sys.dbms_utility.format_error_stack);
            raise;
    end load_user_roles;

    procedure post_auth_sso is
        -- the identity-domain user name, before it is mapped to the employee's user name
        l_login varchar2(255) := v('APP_USER');
    begin
        xxfnd_privilege_pkg.sync_current_application;
        xxfnd_security_pkg.map_login_user;
        if login_type_enforced and user_type = 'LOCAL' then
            raise_application_error(-20067, 'This user signs in with a user name and password, not the company account.');
        end if;
        load_user_roles(l_login);
    end post_auth_sso;

    ----------------------------------------------------------------------------
    -- Authorization
    ----------------------------------------------------------------------------
    function page_id return number is
    begin
        return to_number(v('APP_PAGE_ID'));
    end page_id;

    -- the requester working on the party their request created (Global Page context). Called dynamically:
    -- the package is shared by every application and XXCMP_PARTY_PKG exists only where KYC is installed.
    function party_details_editable return boolean is
        l_yn varchar2(1);
    begin
        execute immediate 'begin :r := ' || xxfnd_util_pkg.qualified('XXCMP_PARTY_PKG') || '.can_edit_details(:p, :q); end;'
            using out l_yn, to_number(v('P0_SUMMARY_PARTY_ID')), to_number(v('P0_REQUEST_ID'));
        return l_yn = 'Y';
    end party_details_editable;

    function authorized(p_scheme in varchar2) return boolean is
    begin
        return case upper(p_scheme)
                   -- application level: at least one privilege through an active role
                   when 'KYC_USER'             then xxfnd_privilege_pkg.has_any_privilege
                   when 'APP_USER'             then xxfnd_privilege_pkg.has_any_privilege
                   -- generic page access: the privilege on the feature the page is mapped to (XXFND_FEATURE_PAGES)
                   when 'PAGE_VIEW'            then xxfnd_privilege_pkg.has_page_privilege(page_id, 'VIEW')
                   when 'PAGE_CREATE'          then xxfnd_privilege_pkg.has_page_privilege(page_id, 'CREATE')
                   when 'PAGE_MANAGE'          then xxfnd_privilege_pkg.has_page_privilege(page_id, 'MANAGE')
                   -- processes that change data: request CREATE needs CREATE, any other request MANAGE
                   when 'PAGE_SUBMIT'          then xxfnd_privilege_pkg.has_page_request_privilege(page_id, v('REQUEST'))
                   when 'WORKFLOW_ADMINISTER'  then xxfnd_privilege_pkg.has_privilege('WORKFLOW_MONITOR', 'MANAGE')
                   when 'ADMIN_AREA'           then xxfnd_privilege_pkg.has_any_admin_privilege
                   -- party detail dialogs (contact person, owner / officer): the page privilege or the requester
                   when 'PARTY_DETAILS_VIEW'   then xxfnd_privilege_pkg.has_page_privilege(page_id, 'VIEW') or party_details_editable
                   when 'PARTY_DETAILS_CREATE' then xxfnd_privilege_pkg.has_page_privilege(page_id, 'CREATE') or party_details_editable
                   when 'PARTY_DETAILS_MANAGE' then xxfnd_privilege_pkg.has_page_privilege(page_id, 'MANAGE') or party_details_editable
                   when 'PARTY_DETAILS_SUBMIT' then xxfnd_privilege_pkg.has_page_request_privilege(page_id, v('REQUEST'))
                                                    or party_details_editable
                   else false
               end;
    end authorized;

    function in_group(p_group in varchar2) return boolean is
    begin
        return apex_util.current_user_in_group(p_group);
    end in_group;

end xxfnd_auth_pkg;
/

--------------------------------------------------------------------------------
-- XXFND_USER_PKG (release 46): users of the shared access module. A LOCAL user gets an Oracle APEX account
-- (APEX keeps the password); the account is created / locked / reset here, from the access console, with the
-- workspace-administrator rights the APEX API needs (the user's own session is detached for the call).
--------------------------------------------------------------------------------
create or replace package xxfnd_user_pkg authid definer as

    -- An SSO user for an employee (returns the existing one when there is one).
    function employee_user(p_employee_id in number) return number;

    -- A LOCAL user with an Oracle APEX account. P_PASSWORD: the first password; the user changes it at first sign-in.
    function create_local_user(p_user_name in varchar2,
                               p_full_name in varchar2,
                               p_email     in varchar2,
                               p_password  in varchar2) return number;

    -- New password for a LOCAL user (the user changes it at the next sign-in).
    procedure reset_password(p_user_id in number, p_password in varchar2);

    -- Enable / disable a user; a LOCAL user's APEX account is unlocked / locked with it.
    procedure set_enabled(p_user_id in number, p_enabled in varchar2);

    -- Y when the user is a LOCAL user (APEX account), N for SSO, null when unknown.
    function is_local(p_user_name in varchar2) return varchar2;

end xxfnd_user_pkg;
/

create or replace package body xxfnd_user_pkg as

    -- only access administrators maintain users
    procedure check_admin is
    begin
        if not xxfnd_privilege_pkg.has_privilege('USERS_ACCESS', 'MANAGE') then
            raise_application_error(-20061, 'You are not allowed to maintain users.');
        end if;
    end check_admin;

    -- runs P_ACTION on APEX accounts as the workspace: outside the signed-in user's APEX session
    procedure apex_account(p_action    in varchar2,
                           p_user_name in varchar2,
                           p_full_name in varchar2 default null,
                           p_email     in varchar2 default null,
                           p_password  in varchar2 default null,
                           p_locked    in varchar2 default null) is
        l_sgid    number := apex_custom_auth.get_security_group_id;
        l_session number := to_number(v('APP_SESSION'));
        l_app     number := to_number(v('APP_ID'));
        l_page    number := to_number(v('APP_PAGE_ID'));
        l_err     varchar2(4000);
        procedure do_it is
            l_id number;
        begin
            case p_action
                when 'CREATE' then
                    apex_util.create_user(p_user_name                    => p_user_name,
                                          p_first_name                   => p_full_name,
                                          p_email_address                => p_email,
                                          p_web_password                 => p_password,
                                          p_change_password_on_first_use => 'Y');
                when 'PASSWORD' then
                    l_id := apex_util.get_user_id(p_user_name);
                    apex_util.edit_user(p_user_id => l_id, p_user_name => p_user_name, p_web_password => p_password,
                                        p_new_password => p_password, p_change_password_on_first_use => 'Y');
                when 'LOCK' then
                    l_id := apex_util.get_user_id(p_user_name);
                    if p_locked = 'Y' then
                        apex_util.lock_account(p_user_name => p_user_name);
                    else
                        apex_util.unlock_account(p_user_name => p_user_name);
                    end if;
            end case;
        end do_it;
    begin
        if l_session is null then
            -- outside APEX (scripts, jobs): the workspace is set by the caller
            do_it;
            return;
        end if;
        apex_session.detach;
        begin
            apex_util.set_security_group_id(l_sgid);
            do_it;
        exception
            when others then
                l_err := sqlerrm;
        end;
        apex_session.attach(p_app_id => l_app, p_page_id => l_page, p_session_id => l_session);
        if l_err is not null then
            raise_application_error(-20062, 'APEX account ' || p_user_name || ': ' || l_err);
        end if;
    end apex_account;

    function employee_user(p_employee_id in number) return number is
        l_id  xxfnd_users.user_id%type;
        l_emp xxfnd_employees%rowtype;
    begin
        select max(user_id) into l_id from xxfnd_users where employee_id = p_employee_id;
        if l_id is null then
            check_admin;
            select * into l_emp from xxfnd_employees where employee_id = p_employee_id;
            insert into xxfnd_users (user_name, user_type, employee_id, full_name, email_address)
            values (upper(l_emp.user_name), 'SSO', l_emp.employee_id, l_emp.full_name, l_emp.email_address)
            returning user_id into l_id;
        end if;
        return l_id;
    end employee_user;

    function create_local_user(p_user_name in varchar2,
                               p_full_name in varchar2,
                               p_email     in varchar2,
                               p_password  in varchar2) return number is
        l_name  varchar2(255) := upper(trim(p_user_name));
        l_id    number;
        l_count pls_integer;
    begin
        check_admin;
        if l_name is null or trim(p_password) is null then
            raise_application_error(-20063, 'Enter the user name and the first password.');
        end if;
        select count(*) into l_count from xxfnd_employees where upper(user_name) = l_name or upper(email_address) = l_name;
        if l_count > 0 then
            raise_application_error(-20064, l_name || ' is an employee: create an SSO user for the employee instead.');
        end if;
        select count(*) into l_count from xxfnd_users where user_name = l_name;
        if l_count > 0 then
            raise_application_error(-20068, 'User ' || l_name || ' already exists.');
        end if;
        -- the APEX account first: it is the step that can fail (name taken, password rules)
        apex_account('CREATE', l_name, trim(p_full_name), lower(trim(p_email)), p_password);
        insert into xxfnd_users (user_name, user_type, full_name, email_address)
        values (l_name, 'LOCAL', trim(p_full_name), lower(trim(p_email)))
        returning user_id into l_id;
        return l_id;
    end create_local_user;

    procedure reset_password(p_user_id in number, p_password in varchar2) is
        l_user xxfnd_users%rowtype;
    begin
        check_admin;
        select * into l_user from xxfnd_users where user_id = p_user_id;
        if l_user.user_type <> 'LOCAL' then
            raise_application_error(-20065, l_user.user_name || ' signs in with the company account (SSO): no password here.');
        end if;
        apex_account('PASSWORD', l_user.user_name, p_password => p_password);
    end reset_password;

    procedure set_enabled(p_user_id in number, p_enabled in varchar2) is
        l_user xxfnd_users%rowtype;
    begin
        check_admin;
        update xxfnd_users set enabled_flag = case when p_enabled = 'Y' then 'Y' else 'N' end
         where user_id = p_user_id
        returning user_id, user_name, user_type into l_user.user_id, l_user.user_name, l_user.user_type;
        if l_user.user_type = 'LOCAL' then
            apex_account('LOCK', l_user.user_name, p_locked => case when p_enabled = 'Y' then 'N' else 'Y' end);
        end if;
    end set_enabled;

    function is_local(p_user_name in varchar2) return varchar2 is
        l_type xxfnd_users.user_type%type;
    begin
        select max(user_type) into l_type from xxfnd_users where user_name = upper(trim(p_user_name));
        return case l_type when 'LOCAL' then 'Y' when 'SSO' then 'N' end;
    end is_local;

end xxfnd_user_pkg;
/
