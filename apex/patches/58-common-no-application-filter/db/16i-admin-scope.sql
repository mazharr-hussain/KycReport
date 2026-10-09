--------------------------------------------------------------------------------
-- 16i Administration scope (release 61). Installed by the COMMON application only (XXFUSION).
--   Each COMMON setup screen works for one application at a time (G_ADMIN_APP): it shows and changes only that
--   application's rows (and, for a Common Administrator, the shared rows: application empty).
--   - An application column on value sets, retention policies, storage rules and integration endpoints
--     (the other setup tables already have one; empty = shared by all applications).
--   Release 73: no application filter for IT; delegated administration - an application's administrators open
--   the COMMON screens of the functions IT lets them manage, from their own application, for its rows only.
--   - XXFND_ADMIN_SCOPE_PKG / XXFND_ADMIN_APPLICATIONS_V: the applications the signed-in user administers -
--     every application for a Common Administrator (role COMMON_ADMIN), otherwise the applications of the user's
--     active roles that hold an admin privilege.
-- Idempotent.
--------------------------------------------------------------------------------
-- application scope columns (empty = shared)
declare
    l_n pls_integer;
begin
    for t in (select column_value table_name
                from table(apex_t_varchar2('XXFND_VALUE_SETS', 'XXFND_RETENTION_POLICIES', 'XXFND_STORAGE_CONFIG',
                                           'XXFND_INTEGRATION_ENDPOINTS'))) loop
        select count(*) into l_n from user_tab_columns where table_name = t.table_name and column_name = 'APPLICATION_CODE';
        if l_n = 0 then
            execute immediate 'alter table ' || t.table_name || ' add (application_code varchar2(30))';
        end if;
    end loop;
end;
/

comment on column xxfnd_value_sets.application_code            is 'Application the value set belongs to; empty = shared by all applications.';
comment on column xxfnd_retention_policies.application_code    is 'Application the policy belongs to; empty = shared by all applications.';
comment on column xxfnd_storage_config.application_code        is 'Application the storage rule belongs to; empty = shared by all applications.';
comment on column xxfnd_integration_endpoints.application_code is 'Application the endpoint belongs to; empty = shared by all applications.';

-- the applications the signed-in user administers
create or replace package xxfnd_admin_scope_pkg authid definer as
    -- Y when the user holds the active role COMMON_ADMIN (administers every application).
    function is_common_admin(p_user_name in varchar2 default null) return varchar2;
    -- Y when the user may administer the application (application code); null code = shared rows: Common Administrator only.
    function can_administer(p_application_code in varchar2, p_user_name in varchar2 default null) return varchar2;
    -- Y when the user administers at least one application (may use the COMMON application).
    function administers_any(p_user_name in varchar2 default null) return varchar2;
    -- The application filter a COMMON screen opens with (release 71): the requested application, else ALL.
    function default_application(p_requested in varchar2 default null) return varchar2;
    -- DBMS_RLS policy functions (policy XXFND_ADMIN_SCOPE on the setup tables with APPLICATION_CODE). Only inside the
    -- COMMON application (release 71: IT only): nothing for anyone but a Common Administrator; G_ADMIN_APP = ALL:
    -- every row; one application: its rows and the shared rows. Other applications and code outside APEX: no limit.
    function policy_read(p_schema in varchar2, p_object in varchar2) return varchar2;
    function policy_change(p_schema in varchar2, p_object in varchar2) return varchar2;
    -- The setup tables scoped by application (policies and the default-application trigger).
    function scoped_tables return apex_t_varchar2;
    -- APEX application ID of an application (code; recorded at its sign-in), else the running application.
    function apex_app_id(p_application_code in varchar2) return number;
    -- release 68: link to a setup page from a business application - the page in the running application when it
    -- has it, otherwise the page in COMMON (entry page 99), opened for the running application (locked to it).
    function setup_page_url(p_page_id in number) return varchar2;
    -- release 72: Y when the running application has the page (menus show only an application's own pages).
    function local_page(p_page_id in number) return varchar2;
    -- release 73: delegated administration. Y when IT lets the application's administrators maintain the common
    -- function (XXFND_APPLICATION_FUNCTIONS.MANAGED_IN_APP_FLAG) and the user holds a privilege on it through an
    -- active role of that application.
    function is_delegated(p_application_code in varchar2, p_feature_code in varchar2,
                          p_user_name in varchar2 default null) return varchar2;
    -- Y when the user is delegated for at least one function of any application (may open COMMON's delegated screens).
    function delegated_any(p_user_name in varchar2 default null) return varchar2;
    -- The application a delegated COMMON screen works for: G_ADMIN_APP when the application opened it for itself
    -- (G_ADMIN_LOCK = Y, page 99) and the user is delegated for it; else null.
    function delegated_app return varchar2;
    -- Y when the user may open the COMMON page: a Common Administrator any page; a delegated user only the pages of
    -- a function managed in the application that opened it.
    function page_allowed(p_page_id in number) return varchar2;
    -- release 73: a menu entry of the running application for a common function managed in it (link to the
    -- application's Setup dialog page 98, which shows the COMMON page): null when not delegated.
    function delegated_url(p_feature_code in varchar2) return varchar2;
end xxfnd_admin_scope_pkg;
/

create or replace package body xxfnd_admin_scope_pkg as

    function norm_user(p_user_name in varchar2) return varchar2 is
    begin
        return upper(nvl(p_user_name, xxfnd_util_pkg.current_user));
    end norm_user;

    function is_common_admin(p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        select count(*) into l_n
          from xxfnd_user_roles_v
         where user_name = l_user and role_code = 'COMMON_ADMIN' and active_flag = 'Y';
        return case when l_n > 0 then 'Y' else 'N' end;
    end is_common_admin;

    function can_administer(p_application_code in varchar2, p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        if is_common_admin(p_user_name) = 'Y' then
            return 'Y';
        end if;
        if p_application_code is null then
            return 'N';
        end if;
        select count(*) into l_n
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name = l_user
           and ur.active_flag = 'Y'
           and ur.application_code = upper(p_application_code)
           and f.admin_flag = 'Y'
           and f.enabled_flag = 'Y'
           and rownum = 1;
        return case when l_n > 0 then 'Y' else 'N' end;
    end can_administer;

    function administers_any(p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        if is_common_admin(p_user_name) = 'Y' then
            return 'Y';
        end if;
        select count(*) into l_n
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name = l_user
           and ur.active_flag = 'Y' and f.admin_flag = 'Y' and f.enabled_flag = 'Y'
           and rownum = 1;
        return case when l_n > 0 then 'Y' else 'N' end;
    end administers_any;

    function default_application(p_requested in varchar2 default null) return varchar2 is
        l_n pls_integer;
    begin
        -- release 71: ALL (every application) unless a registered application is requested
        if p_requested is null or upper(p_requested) = 'ALL' then
            return 'ALL';
        end if;
        select count(*) into l_n from xxfnd_applications where application_code = upper(p_requested);
        return case when l_n > 0 then upper(p_requested) else 'ALL' end;
    end default_application;

    function in_common return boolean is
    begin
        return nvl(upper(v('APP_ALIAS')), '#') = 'COMMON';   -- false (not null) outside APEX
    end in_common;

    -- release 71: COMMON is for IT (Common Administrator) only. G_ADMIN_APP is a view filter there: ALL (default) =
    -- every application's rows, one application = its rows and the shared rows.
    -- release 73: no application filter for IT (G_ADMIN_APP = ALL), unless an application opened the screen for
    -- itself (its rows and the instance rows). A delegated user (not IT): reads the application's rows and the
    -- instance rows, changes only the application's rows.
    function scope_predicate(p_change in boolean default false) return varchar2 is
        l_app varchar2(30) := upper(v('G_ADMIN_APP'));
        l_del varchar2(30);
    begin
        if not in_common then
            return null;
        elsif is_common_admin = 'Y' then
            if l_app is null or l_app = 'ALL' then
                return null;
            end if;
            return 'application_code is null or application_code = ' || dbms_assert.enquote_literal(l_app);
        end if;
        l_del := delegated_app;
        if l_del is null then
            return '1 = 0';
        elsif p_change then
            return 'application_code = ' || dbms_assert.enquote_literal(l_del);
        end if;
        return 'application_code is null or application_code = ' || dbms_assert.enquote_literal(l_del);
    end scope_predicate;

    function policy_read(p_schema in varchar2, p_object in varchar2) return varchar2 is
    begin
        return scope_predicate;
    end policy_read;

    function policy_change(p_schema in varchar2, p_object in varchar2) return varchar2 is
    begin
        return scope_predicate(true);
    end policy_change;

    function scoped_tables return apex_t_varchar2 is
    begin
        -- not XXFND_ROLES: the access checks read every role (the Roles screen filters by application itself)
        return apex_t_varchar2('XXFND_LOOKUP_TYPES', 'XXFND_NOTIFICATION_TEMPLATES',
                               'XXFND_INTEGRATION_PURPOSES', 'XXFND_INTEGRATION_ENDPOINTS', 'XXFND_DOCUMENT_ENTITIES',
                               'XXFND_DOCUMENT_CATEGORIES', 'XXFND_ATTACHMENT_FUNCTIONS', 'XXFND_DF_FLEXFIELDS',
                               'XXFND_VALUE_SETS', 'XXFND_RETENTION_POLICIES', 'XXFND_STORAGE_CONFIG');
    end scoped_tables;

    function apex_app_id(p_application_code in varchar2) return number is
        l_id number;
    begin
        if upper(p_application_code) = 'ALL' then
            return null;   -- release 71: no single application chosen
        end if;
        select max(apex_application_id) into l_id from xxfnd_applications where application_code = upper(p_application_code);
        return coalesce(l_id, to_number(v('APP_ID')));
    end apex_app_id;

    function setup_page_url(p_page_id in number) return varchar2 is
        l_n    pls_integer;
        l_code xxfnd_applications.application_code%type;
    begin
        if p_page_id is null then
            return null;
        end if;
        select count(*) into l_n from apex_application_pages
         where application_id = to_number(v('APP_ID')) and page_id = p_page_id;
        if l_n > 0 then
            return apex_page.get_url(p_page => p_page_id);
        end if;
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'));
        return apex_page.get_url(p_application => 'COMMON', p_page => 99,
                                 p_items  => 'G_ADMIN_APP,G_ADMIN_LOCK,P99_PAGE',
                                 p_values => nvl(l_code, upper(v('APP_ALIAS'))) || ',Y,' || to_char(p_page_id));
    end setup_page_url;

    function local_page(p_page_id in number) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from apex_application_pages
         where application_id = to_number(v('APP_ID')) and page_id = p_page_id;
        return case when l_n > 0 then 'Y' else 'N' end;
    end local_page;

    function is_delegated(p_application_code in varchar2, p_feature_code in varchar2,
                          p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        select count(*) into l_n
          from xxfnd_application_functions af
         where af.application_code = upper(p_application_code)
           and af.feature_code = upper(p_feature_code)
           and af.managed_in_app_flag = 'Y'
           and exists (select 1
                         from xxfnd_user_roles_v ur
                         join xxfnd_role_privileges rp on rp.role_code = ur.role_code
                         join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
                        where ur.user_name = l_user
                          and ur.active_flag = 'Y'
                          and ur.application_code = af.application_code
                          and p.feature_code = af.feature_code);
        return case when l_n > 0 then 'Y' else 'N' end;
    end is_delegated;

    function delegated_any(p_user_name in varchar2 default null) return varchar2 is
        l_n    pls_integer;
        l_user varchar2(255) := norm_user(p_user_name);
    begin
        select count(*) into l_n
          from xxfnd_application_functions af
         where af.managed_in_app_flag = 'Y'
           and exists (select 1
                         from xxfnd_user_roles_v ur
                         join xxfnd_role_privileges rp on rp.role_code = ur.role_code
                         join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
                        where ur.user_name = l_user
                          and ur.active_flag = 'Y'
                          and ur.application_code = af.application_code
                          and p.feature_code = af.feature_code)
           and rownum = 1;
        return case when l_n > 0 then 'Y' else 'N' end;
    end delegated_any;

    function delegated_app return varchar2 is
        l_app varchar2(30) := upper(v('G_ADMIN_APP'));
        l_n   pls_integer;
    begin
        if nvl(v('G_ADMIN_LOCK'), 'N') <> 'Y' or l_app is null or l_app = 'ALL' then
            return null;
        end if;
        select count(*) into l_n from xxfnd_application_functions
         where application_code = l_app and managed_in_app_flag = 'Y'
           and is_delegated(application_code, feature_code) = 'Y';
        return case when l_n > 0 then l_app end;
    end delegated_app;

    function page_allowed(p_page_id in number) return varchar2 is
        l_feature xxfnd_feature_pages.feature_code%type;
        l_app     varchar2(30);
    begin
        if not in_common or is_common_admin = 'Y' then
            return 'Y';
        end if;
        l_app := delegated_app;
        if l_app is null then
            return 'N';
        end if;
        select max(feature_code) into l_feature from xxfnd_feature_pages
         where app_alias = 'COMMON' and page_id = p_page_id;
        if l_feature is null then
            return case when p_page_id = 99 then 'Y' else 'N' end;   -- the entry page
        end if;
        return is_delegated(l_app, l_feature);
    end page_allowed;

    function delegated_url(p_feature_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        select max(application_code) into l_code from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'));
        if l_code is null or is_delegated(l_code, p_feature_code) = 'N' then
            return null;
        end if;
        return apex_page.get_url(p_page => 98, p_items => 'P98_FEATURE', p_values => upper(p_feature_code));
    end delegated_url;

end xxfnd_admin_scope_pkg;
/

-- the scope on every setup table with an application column: policies + new rows belong to the application in scope
declare
    l_n pls_integer;
begin
    -- tables no longer scoped
    for p in (select object_name, policy_name from user_policies
               where policy_name like 'XXFND\_ADMIN\_SCOPE\_%' escape '\'
                 and object_name not in (select column_value from table(xxfnd_admin_scope_pkg.scoped_tables))) loop
        dbms_rls.drop_policy(object_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                             object_name => p.object_name, policy_name => p.policy_name);
    end loop;
    for t in (select trigger_name from user_triggers
               where trigger_name like '%\_SC' escape '\'
                 and table_name not in (select column_value from table(xxfnd_admin_scope_pkg.scoped_tables))
                 and table_name like 'XXFND\_%' escape '\') loop
        execute immediate 'drop trigger ' || t.trigger_name;
    end loop;
    for t in (select column_value table_name from table(xxfnd_admin_scope_pkg.scoped_tables)) loop
        for p in (select 'XXFND_ADMIN_SCOPE_R' policy_name, 'POLICY_READ' fn, 'SELECT' stmts, false chk from dual
                  union all
                  select 'XXFND_ADMIN_SCOPE_C', 'POLICY_CHANGE', 'INSERT,UPDATE,DELETE', true from dual) loop
            select count(*) into l_n from user_policies where object_name = t.table_name and policy_name = p.policy_name;
            if l_n = 0 then
                dbms_rls.add_policy(object_schema   => sys_context('USERENV', 'CURRENT_SCHEMA'),
                                    object_name     => t.table_name,
                                    policy_name     => p.policy_name,
                                    function_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                                    policy_function => 'XXFND_ADMIN_SCOPE_PKG.' || p.fn,
                                    statement_types => p.stmts,
                                    update_check    => p.chk,
                                    policy_type     => dbms_rls.context_sensitive);
            end if;
        end loop;
        execute immediate 'create or replace trigger ' || substr(t.table_name, 1, 120) || '_SC
            before insert on ' || t.table_name || '
            for each row
            when (new.application_code is null)
        begin
            -- release 61 (16i): a row created on a COMMON setup screen belongs to the application in scope
            if upper(v(''APP_ALIAS'')) = ''COMMON'' and nvl(upper(v(''G_ADMIN_APP'')), ''COMMON'') not in (''COMMON'', ''ALL'') then
                :new.application_code := upper(v(''G_ADMIN_APP''));
            end if;
        end;';
    end loop;
end;
/

create or replace view xxfnd_admin_applications_v as
select a.application_id, a.application_code, a.application_name
  from xxfnd_applications a
 where a.enabled_flag = 'Y'
   and xxfnd_admin_scope_pkg.can_administer(a.application_code) = 'Y';

comment on table xxfnd_admin_applications_v is 'Applications the signed-in user administers (COMMON application selector).';

