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
--   Runs after 16e (the party detail rules use XXCMP_PARTY_PKG).
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
    -- One entry for the authorization schemes: KYC_USER, PAGE_VIEW, PAGE_CREATE, PAGE_MANAGE, PAGE_SUBMIT,
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
    procedure post_auth_local is
    begin
        xxfnd_security_pkg.map_login_user;
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
        xxfnd_security_pkg.map_login_user;
        load_user_roles(l_login);
    end post_auth_sso;

    ----------------------------------------------------------------------------
    -- Authorization
    ----------------------------------------------------------------------------
    function page_id return number is
    begin
        return to_number(v('APP_PAGE_ID'));
    end page_id;

    -- the requester working on the party their request created (Global Page context)
    function party_details_editable return boolean is
    begin
        return xxcmp_party_pkg.can_edit_details(to_number(v('P0_SUMMARY_PARTY_ID')), to_number(v('P0_REQUEST_ID'))) = 'Y';
    end party_details_editable;

    function authorized(p_scheme in varchar2) return boolean is
    begin
        return case upper(p_scheme)
                   -- application level: at least one privilege through an active role
                   when 'KYC_USER'             then xxfnd_privilege_pkg.has_any_privilege
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
