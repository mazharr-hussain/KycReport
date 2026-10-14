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

    -- New password for a LOCAL user (the user changes it at the next sign-in).
    procedure reset_password(p_user_id in number, p_password in varchar2);

    -- Enable / disable a user; a LOCAL user's APEX account is unlocked / locked with it.
    procedure set_enabled(p_user_id in number, p_enabled in varchar2);

    -- Y when the user is a LOCAL user (APEX account), N for SSO, null when unknown.
    function is_local(p_user_name in varchar2) return varchar2;

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

    -- Moves every stored reference to a user name to a new one: request, case, approval, delegation and RFI
    -- user columns, the WHO columns of all XXFND_/XXCMP_ tables, and the potential owners of open workflow tasks.
    -- The audit log keeps the old name. Run by trigger XXFND_EMPLOYEES_RENAME when an employee's user name changes.
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
    -- WORKFLOW_ADMINISTER, ADMIN_AREA, ADMIN_APP, PARTY_DETAILS_VIEW, PARTY_DETAILS_CREATE, PARTY_DETAILS_MANAGE,
    -- PARTY_DETAILS_SUBMIT. Reads APP_PAGE_ID, REQUEST and the Global Page party context from session state.
    function authorized(p_scheme in varchar2) return boolean;
    -- True when the signed-in user has the Fusion role / identity-domain group (dynamic group) P_GROUP.
    function in_group(p_group in varchar2) return boolean;

end xxfnd_user_pkg;
/

create or replace package body xxfnd_user_pkg as

    g_renaming boolean := false;


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

    -- user-role assignments: from the User screen (Users & Access) or the Role screen (Roles & Privileges)
    procedure check_assign is
    begin
        if not (xxfnd_privilege_pkg.has_privilege('USERS_ACCESS', 'MANAGE')
                or xxfnd_privilege_pkg.has_privilege('ROLES_PRIVILEGES', 'MANAGE')) then
            raise_application_error(-20072, 'You are not allowed to assign roles.');
        end if;
    end check_assign;

    procedure save_user(p_user_id       in number,
                        p_full_name     in varchar2,
                        p_email         in varchar2,
                        p_language_code in varchar2,
                        p_end_date      in date,
                        p_description   in varchar2) is
    begin
        check_admin;
        update xxfnd_users u
           set u.full_name       = case when u.user_type = 'LOCAL' then nvl(trim(p_full_name), u.full_name) else u.full_name end,
               u.email_address   = case when u.user_type = 'LOCAL' then lower(trim(p_email)) else u.email_address end,
               u.language_code   = nvl(p_language_code, 'en'),
               u.end_date_active = p_end_date,
               u.description     = p_description
         where u.user_id = p_user_id;
    end save_user;

    procedure assign_role(p_user_id in number, p_role_code in varchar2) is
        l_user  xxfnd_users.user_name%type;
        l_count pls_integer;
    begin
        check_assign;
        select user_name into l_user from xxfnd_users where user_id = p_user_id;
        select count(*) into l_count from xxfnd_user_roles
         where user_id = p_user_id and role_code = p_role_code and enabled_flag = 'Y'
           and (end_date_active is null or end_date_active >= trunc(sysdate));
        if l_count > 0 then
            return;
        end if;
        if xxfnd_privilege_pkg.sod_conflict(p_role_code, null, l_user) then
            raise_application_error(-20073, l_user || ' holds a role that may not be combined with ' || p_role_code
                                            || ' (Segregation of Duties).');
        end if;
        insert into xxfnd_user_roles (user_id, employee_id, role_code)
        select u.user_id, u.employee_id, p_role_code from xxfnd_users u where u.user_id = p_user_id;
        xxfnd_vpd_pkg.clear_cache;
    end assign_role;

    procedure unassign_role(p_user_role_id in number) is
    begin
        check_assign;
        update xxfnd_user_roles
           set end_date_active = greatest(trunc(sysdate) - 1, start_date_active), enabled_flag = 'N'
         where user_role_id = p_user_role_id;
        xxfnd_vpd_pkg.clear_cache;
    end unassign_role;

    function is_local(p_user_name in varchar2) return varchar2 is
        l_type xxfnd_users.user_type%type;
    begin
        select max(user_type) into l_type from xxfnd_users where user_name = upper(trim(p_user_name));
        return case l_type when 'LOCAL' then 'Y' when 'SSO' then 'N' end;
    end is_local;

    function renaming return boolean is
    begin
        return g_renaming;
    end renaming;

    procedure rename_user(p_old_user_name in varchar2, p_new_user_name in varchar2) is
        l_old varchar2(255) := upper(trim(p_old_user_name));
        l_new varchar2(255) := upper(trim(p_new_user_name));
    begin
        if l_old is null or l_new is null or l_old = l_new then
            return;
        end if;
        g_renaming := true;
        xxfnd_util_pkg.set_install_mode(true);
        xxfnd_util_pkg.set_preserve_who(true);    -- the rows keep their dates; only the user names change
        execute immediate 'call xxfnd_vpd_pkg.begin_trusted()';   -- 09b creates XXFND_VPD_PKG later              -- every row, whatever the caller may see
        -- release 54: the tables of this schema and of every application schema that granted them
        for c in (select c.owner, c.table_name, c.column_name
                    from all_tab_columns c
                    join all_tables t on t.owner = c.owner and t.table_name = c.table_name
                   where (c.owner = $$PLSQL_UNIT_OWNER
                          or c.owner in (select schema_name from xxfnd_applications where schema_name is not null))
                     and (c.table_name like 'XXCMP\_%' escape '\' or c.table_name like 'XXFND\_%' escape '\')
                     and c.table_name not in ('XXFND_EMPLOYEES', 'XXFND_AUDIT_LOG')
                     and c.data_type like '%CHAR%'
                     and c.column_name in ('CREATED_BY', 'LAST_UPDATED_BY', 'APPROVED_BY', 'ACKNOWLEDGED_BY',
                                           'DECIDED_BY', 'MATCH_RESOLVED_BY', 'ASSIGNED_TO', 'REQUESTER_USER_NAME',
                                           'RECIPIENT_USER_NAME', 'DELEGATE_USER_NAME', 'DELEGATOR_USER_NAME',
                                           'USER_NAME')) loop
            execute immediate 'update ' || dbms_assert.enquote_name(c.owner, false) || '.' || c.table_name || ' set ' || c.column_name || ' = :n where upper('
                              || c.column_name || ') = :o' using l_new, l_old;
        end loop;
        -- open workflow tasks: the new name becomes a potential owner instead of the old one
        for t in (select distinct p.task_id, upper(k.actual_owner) as actual_owner
                    from apex_task_participants p
                    join apex_tasks k on k.task_id = p.task_id
                   where upper(p.participant) = l_old
                     and p.participant_type = 'POTENTIAL_OWNER'
                     and k.state_code in ('UNASSIGNED', 'ASSIGNED', 'INFO_REQUESTED')) loop
            begin
                begin
                    apex_human_task.add_task_potential_owner(p_task_id => t.task_id, p_potential_owner => l_new);
                exception
                    when others then
                        null;    -- already a potential owner
                end;
                if t.actual_owner = l_old then
                    apex_human_task.delegate_task(p_task_id => t.task_id, p_to_user => l_new);
                end if;
                apex_human_task.remove_potential_owner(p_task_id => t.task_id, p_potential_owner => l_old);
            exception
                when others then
                    apex_debug.warn('rename_user: task %0 not moved from %1 to %2: %3', t.task_id, l_old, l_new, sqlerrm);
            end;
        end loop;
        execute immediate 'call xxfnd_vpd_pkg.end_trusted()';
        xxfnd_util_pkg.set_install_mode(false);
        xxfnd_util_pkg.set_preserve_who(false);
        g_renaming := false;
    exception
        when others then
            execute immediate 'call xxfnd_vpd_pkg.end_trusted()';
            xxfnd_util_pkg.set_install_mode(false);
            xxfnd_util_pkg.set_preserve_who(false);
            g_renaming := false;
            raise;
    end rename_user;

    procedure bootstrap_admin(p_user_name in varchar2,
                              p_full_name in varchar2 default null,
                              p_email     in varchar2 default null,
                              p_role_code in varchar2 default 'SYSTEM_ADMIN') is
        l_user  varchar2(255) := upper(trim(p_user_name));
        l_email varchar2(320) := lower(trim(coalesce(p_email,
                                     case when instr(p_user_name, '@') > 0 then p_user_name end,
                                     p_user_name || '@unknown.invalid')));
        l_id    number;
    begin
        if l_user is null then
            return;
        end if;
        -- release 86 (onboarding an application's administrator): an existing user without an employee (LOCAL) gets
        -- the role on the user itself (an employee made for it would clash with the user's name)
        select max(user_id) into l_id from xxfnd_users where user_name = l_user and employee_id is null;
        if l_id is not null then
            merge into xxfnd_user_roles t
            using (select l_id user_id, p_role_code role_code from dual) s
               on (t.user_id = s.user_id and t.role_code = s.role_code and t.end_date_active is null)
             when matched then update set t.enabled_flag = 'Y'
             when not matched then insert (user_id, role_code) values (s.user_id, s.role_code);
            return;
        end if;
        begin
            select employee_id into l_id from xxfnd_employees where user_name = l_user;
            update xxfnd_employees set enabled_flag = 'Y', end_date_active = null where employee_id = l_id;
        exception
            when no_data_found then
                insert into xxfnd_employees (source_type, user_name, full_name, email_address)
                values ('LOCAL', l_user, coalesce(trim(p_full_name), l_user), l_email)
                returning employee_id into l_id;
        end;
        merge into xxfnd_user_roles t
        using (select l_id employee_id, p_role_code role_code from dual) s
           on (t.employee_id = s.employee_id and t.role_code = s.role_code and t.end_date_active is null)
         when matched then update set t.enabled_flag = 'Y'
         when not matched then insert (employee_id, role_code) values (s.employee_id, s.role_code);
    end bootstrap_admin;

    ----------------------------------------------------------------------------
    -- Authentication
    ----------------------------------------------------------------------------
    procedure map_login_user is
        l_login varchar2(255) := upper(trim(v('APP_USER')));
        l_user  xxfnd_employees.user_name%type;
    begin
        -- release 46: the users of the shared access module first, then the employees
        select max(user_name) keep (dense_rank first order by src, case when user_name = l_login then 0 else 1 end)
          into l_user
          from (select 1 src, u.user_name, upper(u.email_address) email from xxfnd_users u where u.enabled_flag = 'Y'
                union all
                select 2, upper(e.user_name), upper(e.email_address) from xxfnd_employees e where e.enabled_flag = 'Y')
         where user_name = l_login or email = l_login;
        if l_user is not null and upper(l_user) <> l_login then
            apex_custom_auth.set_user(upper(l_user));
        end if;
    end map_login_user;

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
        map_login_user;
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
            apex_debug.error('Error in xxfnd_user_pkg.load_user_roles: %0', sqlerrm);
            apex_debug.log_long_message(p_message => sys.dbms_utility.format_error_stack);
            raise;
    end load_user_roles;

    procedure post_auth_sso is
        -- the identity-domain user name, before it is mapped to the employee's user name
        l_login varchar2(255) := v('APP_USER');
    begin
        xxfnd_privilege_pkg.sync_current_application;
        map_login_user;
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
                   -- release 61: COMMON - a privilege on a COMMON feature or any admin privilege (administrators
                   -- of an application maintain its setup on the COMMON screens)
                   -- release 71: COMMON is for IT only (Common Administrator)
                   -- release 73: and an application's administrators on the functions IT lets them manage (delegated)
                   when 'APP_USER'             then case when upper(v('APP_ALIAS')) = 'COMMON'
                                                         then xxfnd_application_pkg.is_common_admin = 'Y'
                                                              or xxfnd_application_pkg.delegated_any = 'Y'
                                                         else xxfnd_privilege_pkg.has_any_privilege
                                                              or xxfnd_application_pkg.administers_any = 'Y' end
                   -- release 61: the application in scope on a COMMON admin screen (G_ADMIN_APP) is one the user administers
                   when 'ADMIN_APP'            then xxfnd_application_pkg.can_administer(v('G_ADMIN_APP')) = 'Y'
                   -- generic page access: the privilege on the feature the page is mapped to (XXFND_FEATURE_PAGES)
                   -- release 73: in COMMON a delegated user only on the pages of a function managed in the application
                   when 'PAGE_VIEW'            then xxfnd_privilege_pkg.has_page_privilege(page_id, 'VIEW')
                                                    and xxfnd_application_pkg.page_allowed(page_id) = 'Y'
                   when 'PAGE_CREATE'          then xxfnd_privilege_pkg.has_page_privilege(page_id, 'CREATE')
                                                    and xxfnd_application_pkg.page_allowed(page_id) = 'Y'
                   when 'PAGE_MANAGE'          then xxfnd_privilege_pkg.has_page_privilege(page_id, 'MANAGE')
                                                    and xxfnd_application_pkg.page_allowed(page_id) = 'Y'
                   -- processes that change data: request CREATE needs CREATE, any other request MANAGE
                   when 'PAGE_SUBMIT'          then xxfnd_privilege_pkg.has_page_request_privilege(page_id, v('REQUEST'))
                                                    and xxfnd_application_pkg.page_allowed(page_id) = 'Y'
                   when 'WORKFLOW_ADMINISTER'  then xxfnd_privilege_pkg.has_privilege('WORKFLOW_MONITOR', 'MANAGE')
                   when 'ADMIN_AREA'           then case when upper(v('APP_ALIAS')) = 'COMMON'
                                                         then xxfnd_application_pkg.is_common_admin = 'Y'   -- release 71
                                                         else xxfnd_privilege_pkg.has_any_admin_privilege end
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

end xxfnd_user_pkg;
/

-- An employee's user name changed (Fusion user name from the HCM sync, or a LOCAL edit): every stored reference
-- moves to the new name (xxfnd_user_pkg.rename_user), so the person keeps their requests, cases and tasks.
create or replace trigger xxfnd_employees_rename
    after update of user_name on xxfnd_employees
    for each row
    when (upper(new.user_name) <> upper(old.user_name))
begin
    xxfnd_user_pkg.rename_user(:old.user_name, :new.user_name);
end;
/

-- the packages merged into this one (old callers break on purpose: no wrappers)
begin
    xxfnd_ddl_pkg.drop_object('XXFND_AUTH_PKG', 'PACKAGE');
    xxfnd_ddl_pkg.drop_object('XXFND_SECURITY_PKG', 'PACKAGE');
end;
/
