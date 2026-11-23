
create or replace package body xxfnd_application_pkg as


    function common_functions return apex_t_varchar2 is
        l_codes apex_t_varchar2;
    begin
        -- the admin features with a COMMON setup page (not the registration itself)
        select distinct f.feature_code bulk collect into l_codes
          from xxfnd_features f
          join xxfnd_feature_pages fp on fp.feature_code = f.feature_code and fp.app_alias = 'COMMON'
         where f.admin_flag = 'Y' and f.feature_code <> 'APPLICATIONS';
        return l_codes;
    end common_functions;

    procedure ensure_rows(p_application_code in varchar2) is
    begin
        insert into xxfnd_application_functions (application_code, feature_code, managed_in_app_flag)
        select upper(p_application_code), f.feature_code, 'N'
          from xxfnd_features f
         where f.feature_code in (select column_value from table(common_functions))
           and not exists (select 1 from xxfnd_application_functions x
                            where x.application_code = upper(p_application_code) and x.feature_code = f.feature_code);
    end ensure_rows;

    procedure set_apex_id(p_application_code in varchar2) is
    begin
        update xxfnd_applications a
           set a.apex_application_id = (select max(x.application_id) from apex_applications x
                                         where upper(x.alias) = upper(a.apex_app_alias))
         where a.application_code = upper(p_application_code)
           and exists (select 1 from apex_applications x where upper(x.alias) = upper(a.apex_app_alias))
           and decode(a.apex_application_id, (select max(x.application_id) from apex_applications x
                                               where upper(x.alias) = upper(a.apex_app_alias)), 0, 1) = 1;
    end set_apex_id;

    procedure register_application(p_application_code in varchar2) is
        l_schema xxfnd_applications.schema_name%type;
        l_n      pls_integer;
    begin
        select max(schema_name) into l_schema from xxfnd_applications where application_code = upper(p_application_code);
        select count(*) into l_n from all_users where username = upper(l_schema);
        if l_n > 0 and upper(l_schema) <> user then
            -- XXFND_SHARE_PKG is installed later (19c): called by name
            execute immediate 'call xxfnd_share_pkg.grant_to(:s)' using upper(l_schema);
        end if;
        set_apex_id(p_application_code);
        ensure_rows(p_application_code);
    end register_application;


    function app_allowed(p_setup_type_code in varchar2, p_application_code in varchar2) return varchar2 is
        l_level xxfnd_setup_types.allowed_level%type;
        l_all   xxfnd_setup_types.all_applications_flag%type;
        l_n     pls_integer;
    begin
        select max(allowed_level), max(all_applications_flag) into l_level, l_all
          from xxfnd_setup_types where setup_type_code = upper(p_setup_type_code);
        if l_level is null then
            return 'Y';   -- not a setup type: no rule
        elsif p_application_code is null then
            return case when l_level in ('I', 'B') then 'Y' else 'N' end;
        elsif l_level = 'I' or upper(p_application_code) = 'COMMON' then
            return 'N';
        elsif l_all = 'Y' then
            return 'Y';
        end if;
        select count(*) into l_n from xxfnd_setup_type_apps
         where setup_type_code = upper(p_setup_type_code) and application_code = upper(p_application_code);
        return case when l_n > 0 then 'Y' else 'N' end;
    end app_allowed;

    function page_type(p_page_id in number) return varchar2 is
        l_code xxfnd_setup_types.setup_type_code%type;
    begin
        select max(setup_type_code) into l_code from xxfnd_setup_types
         where p_page_id in (list_page_id, form_page_id);
        return l_code;
    end page_type;

    procedure check_level(p_table_name in varchar2, p_application_code in varchar2) is
    begin
        if not xxfnd_util_pkg.in_apex_session then
            return;
        end if;
        for t in (select setup_type_code, setup_type_name, allowed_level from xxfnd_setup_types
                   where table_name = upper(p_table_name)) loop
            if app_allowed(t.setup_type_code, p_application_code) = 'N' then
                raise_application_error(-20160, t.setup_type_name || ': ' ||
                    case when p_application_code is null then 'choose an application (application level only).'
                         when t.allowed_level = 'I' then 'kept for the whole workspace (all applications) only.'
                         else 'not available for ' || upper(p_application_code) || '.' end);
            end if;
        end loop;
    end check_level;

    procedure create_triggers is
    begin
        for t in (select distinct s.table_name from xxfnd_setup_types s
                   where s.table_name is not null
                     and exists (select 1 from user_tab_columns c
                                  where c.table_name = s.table_name and c.column_name = 'APPLICATION_CODE')) loop
            execute immediate 'create or replace trigger ' || substr(t.table_name, 1, 120) || '_LV
                before insert or update of application_code on ' || t.table_name || '
                for each row
            begin
                -- release 73 (21c): the level the setup type is kept at (XXFND_SETUP_TYPES)
                if inserting or nvl(:new.application_code, ''#'') <> nvl(:old.application_code, ''#'') then
                    xxfnd_application_pkg.check_level(''' || t.table_name || ''', :new.application_code);
                end if;
            end;';
        end loop;
    end create_triggers;

    procedure save_setup_type_apps(p_setup_type_code in varchar2, p_allowed_level in varchar2,
                                   p_all_applications_flag in varchar2, p_applications in varchar2) is
    begin
        delete from xxfnd_setup_type_apps where setup_type_code = upper(p_setup_type_code);
        if p_allowed_level <> 'I' and p_all_applications_flag = 'N' then
            insert into xxfnd_setup_type_apps (setup_type_code, application_code)
            select upper(p_setup_type_code), column_value from table(apex_string.split(p_applications, ':'))
             where column_value is not null;
        end if;
    end save_setup_type_apps;


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
    -- itself (its rows and the instance rows). Release 106: anyone else by the privilege of the page (FEATURE_APPS):
    -- reads the rows of those applications and the instance rows, changes only those applications' rows.
    -- release 87: who issued the call into COMMON. Walks the call stack past this package: COMMON's own code
    -- (P_KIND COMMON), an APEX page, process or job (APEX: the application is v('APP_ID'); in App Builder the
    -- application being worked on, FB_FLOW_ID), or the database code of a schema / the session's schema (SCHEMA).
    -- P_ANY_COMMON: any other COMMON unit on the way counts as COMMON (the scope policy); else COMMON units are passed.
    procedure caller(p_kind out varchar2, p_value out varchar2, p_any_common in boolean) is
        l_owner varchar2(128);
    begin
        for i in 2 .. utl_call_stack.dynamic_depth loop
            l_owner := utl_call_stack.owner(i);
            if l_owner = $$PLSQL_UNIT_OWNER then
                if p_any_common and utl_call_stack.subprogram(i)(1) <> 'XXFND_APPLICATION_PKG' then
                    p_kind := 'COMMON';
                    return;
                end if;
            elsif l_owner like 'APEX\_%' escape '\' or l_owner = 'SYS' then
                p_kind := 'APEX';
                return;
            elsif l_owner is not null then
                p_kind := 'SCHEMA';
                p_value := l_owner;
                return;
            end if;
        end loop;
        if v('APP_ID') is not null then
            p_kind := 'APEX';
        elsif sys_context('userenv', 'session_user') = $$PLSQL_UNIT_OWNER then
            p_kind := 'COMMON';
        else
            p_kind := 'SCHEMA';
            p_value := sys_context('userenv', 'session_user');
        end if;
    end caller;

    -- the registered applications the caller acts for; null = no limit (COMMON itself, or unknown: an install
    -- outside an application)
    function caller_apps(p_kind in varchar2, p_value in varchar2) return apex_t_varchar2 is
        l_id   number;
        l_list apex_t_varchar2;
    begin
        if p_kind = 'COMMON' then
            return null;
        elsif p_kind = 'APEX' then
            l_id := to_number(v('APP_ID'));
            if l_id between 4000 and 4999 then
                l_id := to_number(v('FB_FLOW_ID'));    -- App Builder: the application being installed
            end if;
            if l_id is null then
                return null;
            end if;
            select application_code bulk collect into l_list from xxfnd_applications where apex_application_id = l_id;
        else
            select application_code bulk collect into l_list from xxfnd_applications
             where upper(schema_name) = upper(p_value);
        end if;
        if 'COMMON' member of l_list then
            return null;
        end if;
        return l_list;
    end caller_apps;

    function scope_predicate(p_change in boolean default false) return varchar2 is
        l_app  varchar2(30) := upper(v('G_ADMIN_APP'));
        l_pred varchar2(4000);
        l_kind varchar2(10);
        l_val  varchar2(128);
        l_apps apex_t_varchar2;
    begin
        -- release 84: server code that has authorised its caller, or a background job (e.g. a workflow task action
        -- reading the notification wording), reads the setup of every application
        if xxfnd_vpd_pkg.is_trusted then
            return null;
        elsif not in_common then
            -- release 87: an application sees its own setup and the shared (instance) rows, never another
            -- application's; COMMON's own code (called by the application) reads every row
            caller(l_kind, l_val, true);
            l_apps := caller_apps(l_kind, l_val);
            if l_apps is null then
                return null;
            elsif l_apps.count = 0 then
                return 'application_code is null';
            end if;
            return 'application_code is null or application_code in (select column_value from table(apex_string.split('
                   || dbms_assert.enquote_literal(apex_string.join(l_apps, ':')) || ', '':'')))';
        elsif is_common_admin = 'Y' then
            if l_app is null or l_app = 'ALL' then
                return null;
            end if;
            return 'application_code is null or application_code = ' || dbms_assert.enquote_literal(l_app);
        end if;
        -- release 106: anyone else - the applications whose roles give the privilege of the running page (COMMON:
        -- the shared rows), narrowed to G_ADMIN_APP when it is one of them; the shared rows are read by all of them
        l_apps := feature_apps;
        if l_app is not null and l_app <> 'ALL' then
            if l_app member of l_apps then
                l_apps := apex_t_varchar2(l_app);
            else
                l_apps := apex_t_varchar2();
            end if;
        end if;
        if l_apps.count = 0 then
            return '1 = 0';
        end if;
        l_pred := 'application_code in (select column_value from table(apex_string.split('
                  || dbms_assert.enquote_literal(apex_string.join(l_apps, ':')) || ', '':'')))';
        if not p_change or 'COMMON' member of l_apps then
            l_pred := 'application_code is null or ' || l_pred;
        end if;
        return l_pred;
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
                               'XXFND_INTEGRATION_PURPOSES', 'XXFND_DOCUMENT_ENTITIES',   -- release 86: endpoints retired
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
        -- release 106: the COMMON page itself; it works for the application it is opened from (SET_ADMIN_APP)
        return apex_page.get_url(p_application => 'COMMON', p_page => p_page_id);
    end setup_page_url;

    function local_page(p_page_id in number) return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from apex_application_pages
         where application_id = to_number(v('APP_ID')) and page_id = p_page_id;
        return case when l_n > 0 then 'Y' else 'N' end;
    end local_page;

    function feature_apps(p_feature_code in varchar2 default null, p_user_name in varchar2 default null)
        return apex_t_varchar2 is
        l_user    varchar2(255) := norm_user(p_user_name);
        l_feature xxfnd_features.feature_code%type := upper(p_feature_code);
        l_list    apex_t_varchar2;
    begin
        if l_feature is null and in_common then
            select max(feature_code) into l_feature from xxfnd_feature_pages
             where app_alias = 'COMMON' and page_id = to_number(v('APP_PAGE_ID'));
        end if;
        select distinct nvl(r.application_code, 'COMMON') bulk collect into l_list
          from xxfnd_user_role_tree_v t
          join xxfnd_roles r            on r.role_code = t.assigned_role_code
          join xxfnd_role_privileges rp on rp.role_code = t.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where t.user_name = l_user
           and t.active_flag = 'Y'
           and f.enabled_flag = 'Y'
           and (p.feature_code = l_feature or (l_feature is null and f.admin_flag = 'Y'));
        return l_list;
    end feature_apps;

    function is_delegated(p_application_code in varchar2, p_feature_code in varchar2,
                          p_user_name in varchar2 default null) return varchar2 is
    begin
        return 'N';
    end is_delegated;

    procedure submit_feedback(p_application_id in number, p_page_id in number, p_type in number, p_comment in varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_applications where apex_application_id = p_application_id;
        if l_n = 0 then
            raise_application_error(-20171, 'Feedback is taken for the registered applications only.');
        end if;
        if trim(p_comment) is null then
            raise_application_error(-20173, 'Enter your feedback.');
        end if;
        apex_util.submit_feedback(p_comment        => p_comment,
                                  p_type           => nvl(p_type, 1),
                                  p_application_id => p_application_id,
                                  p_page_id        => p_page_id);
    end submit_feedback;

    procedure feedback_follow_up(p_feedback_id in number, p_follow_up in varchar2) is
    begin
        if not xxfnd_privilege_pkg.has_privilege('USAGE_FEEDBACK', 'MANAGE') then
            raise_application_error(-20172, 'You are not allowed to follow up feedback (Usage and Feedback - Manage).');
        end if;
        apex_util.submit_feedback_followup(p_feedback_id => p_feedback_id, p_follow_up => p_follow_up);
    end feedback_follow_up;

    ----------------------------------------------------------------------------
    -- Release 86: onboarding and the registration rule
    ----------------------------------------------------------------------------
    -- in an APEX session the caller needs Applications - Manage; scripts (no APEX session) may
    procedure check_manage is
    begin
        if xxfnd_util_pkg.in_apex_session and not xxfnd_privilege_pkg.has_privilege('APPLICATIONS', 'MANAGE') then
            xxfnd_error_pkg.raise_error('XXFND_NOT_ALLOWED');
        end if;
    end check_manage;

    function registered_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type;
    begin
        select max(application_code) into l_code from xxfnd_applications
         where application_code = upper(trim(p_application_code));
        if l_code is null then
            xxfnd_error_pkg.raise_error('XXFND_APP_NOT_REGISTERED',
                                        apex_t_varchar2(nvl(upper(trim(p_application_code)), '-')));
        end if;
        -- release 87: the caller changes only its own application's rows (golden rule): COMMON itself and IT (the COMMON
        -- application) may act for any application
        declare
            l_kind varchar2(10);
            l_val  varchar2(128);
            l_apps apex_t_varchar2;
        begin
            caller(l_kind, l_val, false);
            l_apps := caller_apps(l_kind, l_val);
            if l_apps is not null and not (l_code member of l_apps) then
                xxfnd_error_pkg.raise_error('XXFND_REG_WRONG_CALLER',
                    apex_t_varchar2(l_code, nvl(apex_string.join(l_apps, ', '), nvl(l_val, l_kind))));
            end if;
        end;
        return l_code;
    end registered_code;

    function setup_code(p_application_code in varchar2) return varchar2 is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        return case when l_code = 'COMMON' then null else l_code end;
    end setup_code;

    procedure assert_same_application(p_what in varchar2, p_key in varchar2, p_row_application in varchar2,
                                      p_application_code in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        if p_row_application is not null and upper(p_row_application) <> l_code then
            xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP', apex_t_varchar2(p_what, p_key, upper(p_row_application)));
        end if;
    end assert_same_application;

    -- I-062 (#221): the owner expression is joined into dynamic SQL, so only the expressions COMMON's own packages use
    -- are accepted (explicit allow-list; compared without case and extra spaces). A new caller adds its expression
    -- here. Anything else is refused before any SQL runs (a programming error, not a user message).
    function owner_expression(p_owner_sql in varchar2) return varchar2 is
        l_sql varchar2(4000) := lower(regexp_replace(trim(p_owner_sql), '\s+', ' '));
    begin
        if l_sql in (
            't.application_code',
            '(select a.application_code from xxfnd_applications a where a.application_id = t.application_id)',
            '(select a.application_code from xxfnd_features f join xxfnd_applications a on a.application_id = f.application_id where f.feature_code = t.feature_code)',
            '(select f.application_code from xxfnd_df_flexfields f where f.descriptive_flexfield_code = t.descriptive_flexfield_code)',
            '(select max(a.application_code) from xxfnd_applications a where upper(nvl(a.apex_app_alias, a.application_code)) = upper(t.app_alias))',
            '(select y.application_code from xxfnd_approval_types y where y.approval_type_code = t.approval_type_code)',
            '(select y.application_code from xxfnd_lookup_types y where y.lookup_type = t.lookup_type)') then
            return l_sql;
        end if;
        raise_application_error(-20189, 'Owner expression not allowed: ' || substr(p_owner_sql, 1, 200));
    end owner_expression;

    procedure remove_registered(p_application_code in varchar2,
                                p_what             in varchar2,
                                p_table            in varchar2,
                                p_key_columns      in apex_t_varchar2,
                                p_keys             in apex_t_varchar2,
                                p_owner_sql        in varchar2 default 't.application_code') is
        e_in_use exception;
        pragma exception_init(e_in_use, -2292);
        l_code  xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_where varchar2(4000);
        l_key   varchar2(4000) := apex_string.join(p_keys, ' / ');
        l_n     pls_integer;
        l_owner varchar2(255);
        l_owner_sql varchar2(4000) := owner_expression(p_owner_sql);
        procedure run(p_sql in varchar2, p_into in boolean) is
        begin
            case p_keys.count
                when 1 then
                    if p_into then execute immediate p_sql into l_n, l_owner using p_keys(1);
                    else execute immediate p_sql using p_keys(1); end if;
                when 2 then
                    if p_into then execute immediate p_sql into l_n, l_owner using p_keys(1), p_keys(2);
                    else execute immediate p_sql using p_keys(1), p_keys(2); end if;
                else
                    if p_into then execute immediate p_sql into l_n, l_owner using p_keys(1), p_keys(2), p_keys(3);
                    else execute immediate p_sql using p_keys(1), p_keys(2), p_keys(3); end if;
            end case;
        end run;
    begin
        for i in 1 .. p_key_columns.count loop
            l_where := l_where || case when i > 1 then ' and ' end
                    || 't.' || dbms_assert.simple_sql_name(p_key_columns(i)) || ' = :k' || i;
        end loop;
        -- every row is seen, whoever asks: the ownership check below decides
        xxfnd_vpd_pkg.begin_trusted;
        begin
            run('select count(*), max(nvl(' || l_owner_sql || ', ''COMMON'')) from '
                || dbms_assert.simple_sql_name(p_table) || ' t where ' || l_where, true);
            if l_n = 0 then
                xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2(p_what, l_key));
            elsif l_owner <> l_code then
                xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP', apex_t_varchar2(p_what, l_key, l_owner));
            end if;
            run('delete from ' || dbms_assert.simple_sql_name(p_table) || ' t where ' || l_where, false);
        exception
            when e_in_use then
                xxfnd_vpd_pkg.end_trusted;
                xxfnd_error_pkg.raise_error('XXFND_REG_IN_USE', apex_t_varchar2(p_what, l_key));
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end remove_registered;

    procedure remove_all_registered(p_application_code in varchar2,
                                    p_what             in varchar2,
                                    p_table            in varchar2,
                                    p_owner_sql        in varchar2 default 't.application_code') is
        e_in_use exception;
        pragma exception_init(e_in_use, -2292);
        l_code      xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_owner_sql varchar2(4000) := owner_expression(p_owner_sql);
    begin
        if l_code = 'COMMON' then
            xxfnd_error_pkg.raise_error('XXFND_APP_DELETE_COMMON');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        begin
            execute immediate 'delete from ' || dbms_assert.simple_sql_name(p_table) || ' t where ' || l_owner_sql || ' = :c'
                using l_code;
        exception
            when e_in_use then
                xxfnd_vpd_pkg.end_trusted;
                xxfnd_error_pkg.raise_error('XXFND_REG_IN_USE', apex_t_varchar2(p_what, l_code));
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
    end remove_all_registered;

    procedure unregister_menu_entry(p_application_code in varchar2, p_entry_code in varchar2) is
        l_made xxfnd_app_menu_entries.made_by%type;
    begin
        select max(made_by) into l_made from xxfnd_app_menu_entries
         where application_code = registered_code(p_application_code) and entry_code = upper(trim(p_entry_code));
        if l_made = 'COMMON' then
            xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP',
                                        apex_t_varchar2('Menu entry', upper(trim(p_entry_code)), 'COMMON'));
        end if;
        remove_registered(p_application_code, 'Menu entry', 'XXFND_APP_MENU_ENTRIES',
                          apex_t_varchar2('APPLICATION_CODE', 'ENTRY_CODE'),
                          apex_t_varchar2(registered_code(p_application_code), upper(trim(p_entry_code))));
    end unregister_menu_entry;

    -- the workspace of the registered applications (COMMON's), else the running application's
    function workspace_name return varchar2 is
        l_ws varchar2(255);
    begin
        select max(x.workspace) into l_ws
          from apex_applications x
         where x.application_id = coalesce((select max(apex_application_id) from xxfnd_applications
                                             where application_code = 'COMMON'), to_number(v('APP_ID')));
        return l_ws;
    end workspace_name;

    procedure save_application(p_application_code    in varchar2,
                               p_apex_application_id in number,
                               p_description         in varchar2 default null,
                               p_enabled_flag        in varchar2 default 'Y',
                               p_email_enabled_flag  in varchar2 default 'Y') is
        l_code   xxfnd_applications.application_code%type := upper(trim(p_application_code));
        l_ws     varchar2(255) := workspace_name;
        l_name   varchar2(4000);
        l_alias  varchar2(4000);
        l_schema varchar2(4000);
        l_other  xxfnd_applications.application_code%type;
    begin
        check_manage;
        if l_code is null or not regexp_like(l_code, '^[A-Z][A-Z0-9_]{0,29}$') then
            xxfnd_error_pkg.raise_error('XXFND_APP_CODE_INVALID', apex_t_varchar2(nvl(l_code, '-')));
        end if;
        -- name, alias and parsing schema are those of the APEX application (one source of truth)
        select max(application_name), max(alias), max(owner) into l_name, l_alias, l_schema
          from apex_applications
         where application_id = p_apex_application_id
           and (l_ws is null or workspace = l_ws);
        if l_name is null then
            xxfnd_error_pkg.raise_error('XXFND_APP_APEX_NOT_FOUND', apex_t_varchar2(to_char(p_apex_application_id)));
        end if;
        select max(application_code) into l_other from xxfnd_applications
         where application_code <> l_code
           and (apex_application_id = p_apex_application_id or upper(apex_app_alias) = upper(l_alias));
        if l_other is not null then
            xxfnd_error_pkg.raise_error('XXFND_APP_APEX_TAKEN', apex_t_varchar2(to_char(p_apex_application_id), l_other));
        end if;
        merge into xxfnd_applications t
        using (select l_code application_code from dual) s
           on (t.application_code = s.application_code)
         when matched then update set t.application_name    = substr(l_name, 1, 240),
                                      t.apex_app_alias      = l_alias,
                                      t.apex_application_id = p_apex_application_id,
                                      t.schema_name         = l_schema,
                                      t.description         = p_description,
                                      t.enabled_flag        = case when l_code = 'COMMON' then 'Y'
                                                                   else nvl(p_enabled_flag, 'Y') end
         when not matched then insert (application_code, application_name, apex_app_alias, apex_application_id,
                                       schema_name, description, enabled_flag)
                               values (l_code, substr(l_name, 1, 240), l_alias, p_apex_application_id, l_schema,
                                       p_description, nvl(p_enabled_flag, 'Y'));
        -- the e-mail switch (column added after this package, 09e: written by name)
        execute immediate 'update xxfnd_applications set email_enabled_flag = :e where application_code = :c'
            using case when p_email_enabled_flag = 'N' then 'N' else 'Y' end, l_code;
        -- grants to its schema, its APEX ID and one row per common function (not managed in the application)
        register_application(l_code);
        -- its workflow processes and the RFI process (new rows on, existing rows kept); XXFND_WORKFLOW_PKG is
        -- installed later (15): called by name
        execute immediate 'begin xxfnd_workflow_pkg.sync_processes; end;';
    end save_application;

    procedure onboard(p_apex_application_id in number,
                      p_application_code    in varchar2,
                      p_description         in varchar2 default null,
                      p_email_enabled_flag  in varchar2 default 'Y',
                      p_admin_user          in varchar2 default null) is
        l_code    xxfnd_applications.application_code%type := upper(trim(p_application_code));
        l_app     xxfnd_applications%rowtype;
        l_before  apex_t_varchar2;
        l_new     apex_t_varchar2;
        l_role    xxfnd_roles.role_code%type;
        l_roles   pls_integer;
        l_created timestamp;
        l_email   varchar2(1);
        l_granted pls_integer;
    begin
        check_manage;
        -- XXFND_WORKFLOW_PROCESSES is created after this package (09e): read by name
        execute immediate 'select process_code from xxfnd_workflow_processes where application_code = :c'
            bulk collect into l_before using l_code;
        select count(*) into l_roles from xxfnd_applications where application_code = l_code;
        if l_roles > 0 then
            -- a re-run refreshes the registration and keeps what the administrators set
            select * into l_app from xxfnd_applications where application_code = l_code;
            execute immediate 'select email_enabled_flag from xxfnd_applications where application_code = :c'
                into l_email using l_code;
            save_application(l_code, p_apex_application_id, nvl(l_app.description, p_description),
                             l_app.enabled_flag, l_email);
        else
            save_application(l_code, p_apex_application_id, p_description, 'Y', nvl(p_email_enabled_flag, 'Y'));
        end if;
        select * into l_app from xxfnd_applications where application_code = l_code;

        -- the shared processes (not the application's own APEX workflows, e.g. RFI) start off; only rows made now
        execute immediate q'~select w.process_code from xxfnd_workflow_processes w
                   where w.application_code = :c
                     and w.process_code not in (select column_value from table(:b))
                     and not exists (select 1 from apex_appl_workflows x
                                      where x.application_id = :i and upper(x.static_id) = w.process_code)~'
            bulk collect into l_new using l_code, l_before, l_app.apex_application_id;
        for i in 1 .. l_new.count loop
            -- XXFND_WORKFLOW_PKG is installed later (15): called by name
            execute immediate 'begin xxfnd_workflow_pkg.set_process_enabled(:a, :p, ''N''); end;'
                using l_code, l_new(i);
        end loop;

        -- the application's administrator: every privilege of its features when the role is made; on a re-run only
        -- the privileges registered since the last onboarding (the role's LAST_UPDATE_DATE, set below), so what an
        -- administrator took away stays away
        l_role := substr(l_code, 1, 24) || '_ADMIN';
        select count(*) into l_roles from xxfnd_roles where role_code = l_role;
        xxfnd_privilege_pkg.register_role(l_code, l_role, substr(l_app.application_name, 1, 185) || ' Administrator',
                                          substr('Administers ' || l_app.application_name
                                                 || ': every feature of the application (onboarding).', 1, 500));
        select last_update_date into l_created from xxfnd_roles where role_code = l_role;
        l_granted := 0;
        for p in (select p.privilege_code from xxfnd_privileges p
                    join xxfnd_features f on f.feature_code = p.feature_code
                   where f.application_id = l_app.application_id
                     and (l_roles = 0 or p.creation_date > l_created)) loop
            xxfnd_privilege_pkg.add_role_privilege(l_code, l_role, p.privilege_code);
            l_granted := l_granted + 1;
        end loop;
        if l_granted > 0 and l_roles > 0 then
            -- the onboarding mark: the WHO trigger sets LAST_UPDATE_DATE
            update xxfnd_roles set role_name = role_name where role_code = l_role;
        end if;
        if trim(p_admin_user) is not null then
            -- XXFND_USER_PKG is installed later (16j): called by name; it gives the role outside an APEX session
            execute immediate 'begin xxfnd_user_pkg.bootstrap_admin(p_user_name => :u, p_role_code => :r); end;'
                using upper(trim(p_admin_user)), l_role;
        end if;
        ensure_menu(l_code);    -- release 87: the application's menu for the common functions
    end onboard;

    procedure set_enabled(p_application_code in varchar2, p_enabled_flag in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        check_manage;
        if l_code = 'COMMON' and nvl(p_enabled_flag, 'N') <> 'Y' then
            xxfnd_error_pkg.raise_error('XXFND_APP_COMMON_ALWAYS');
        end if;
        update xxfnd_applications set enabled_flag = case when p_enabled_flag = 'Y' then 'Y' else 'N' end
         where application_code = l_code
           and enabled_flag <> case when p_enabled_flag = 'Y' then 'Y' else 'N' end;
    end set_enabled;

    function delete_blocker(p_application_code in varchar2) return varchar2 is
        l_app  xxfnd_applications%rowtype;
        l_list varchar2(4000);
        l_n    number;
        procedure found(p_what in varchar2, p_count in number) is
        begin
            if p_count > 0 then
                l_list := substr(l_list || case when l_list is not null then ', ' end || p_what || ': ' || p_count, 1, 3000);
            end if;
        end found;
    begin
        select * into l_app from xxfnd_applications where application_code = registered_code(p_application_code);
        if l_app.application_code = 'COMMON' then
            return xxfnd_error_pkg.message('XXFND_APP_DELETE_COMMON');
        elsif l_app.enabled_flag = 'Y' then
            return xxfnd_error_pkg.message('XXFND_APP_DELETE_ENABLED', apex_t_varchar2(l_app.application_code));
        end if;
        -- every row is counted, whoever asks (data security and the administration scope do not hide any)
        xxfnd_vpd_pkg.begin_trusted;
        begin
            -- any table of the platform that keeps an application code: RFIs, communications, notifications ...
            -- release 88 (C9): business data only - the application's own standard rows and the setup it registered
            -- (removed by DELETE_APPLICATION through each component's UNREGISTER_APPLICATION) do not block
            for t in (select c.table_name from user_tab_columns c
                        join user_tables u on u.table_name = c.table_name
                       where c.column_name = 'APPLICATION_CODE'
                         and (c.table_name like 'XXFND\_%' escape '\' or c.table_name like 'XXHR\_%' escape '\')
                         and c.table_name not in ('XXFND_APPLICATIONS', 'XXFND_APPLICATION_FUNCTIONS',
                                                  'XXFND_WORKFLOW_PROCESSES', 'XXFND_SETUP_TYPE_APPS', 'XXFND_ROLES',
                                                  'XXFND_APP_MENU_ENTRIES', 'XXFND_LOOKUP_TYPES', 'XXFND_APPROVAL_TYPES',
                                                  'XXFND_ATTACHMENT_FUNCTIONS', 'XXFND_DF_FLEXFIELDS', 'XXFND_VALUE_SETS',
                                                  'XXFND_DOCUMENT_CATEGORIES', 'XXFND_DOCUMENT_ENTITIES',
                                                  'XXFND_INTEGRATION_PURPOSES', 'XXFND_NOTIFICATION_TEMPLATES',
                                                  'XXFND_NOTIFY_RULES', 'XXFND_STORAGE_CONFIG', 'XXFND_CONTACT_SOURCES',
                                                  'XXFND_DM_APP_SCOPES', 'XXFND_DM_TABLE_GROUPS',
                                                  -- release 96: security model rows (removed with the application)
                                                  'XXFND_USER_APPLICATIONS', 'XXFND_DATA_OBJECTS',
                                                  'XXFND_DATA_DIMENSIONS', 'XXHR_ORGANIZATIONS')
                       order by c.table_name) loop
                execute immediate 'select count(*) from ' || dbms_assert.simple_sql_name(t.table_name)
                               || ' where application_code = :c' into l_n using l_app.application_code;
                found(initcap(replace(regexp_replace(t.table_name, '^XX[A-Z]+_'), '_', ' ')), l_n);
            end loop;
            -- documents of the application's records (its registered entities)
            select count(*) into l_n from xxfnd_attached_documents ad
              join xxfnd_document_entities e on e.entity_name = ad.entity_name
             where e.application_code = l_app.application_code;
            found('Documents', l_n);
            -- roles in use: named by segregation of duties, deadlines or another application's approvals (release 88:
            -- the roles' users, its own data rules and approval rules go with it); the deadline and approval
            -- tables are created after this package (15, 15d): read by name
            execute immediate q'~select count(*) from xxfnd_roles r
             where r.application_code = :c
               and (exists (select 1 from xxfnd_sod_rules x where r.role_code in (x.role_code_1, x.role_code_2))
                    or exists (select 1 from xxfnd_task_settings x where x.escalation_role_code = r.role_code)
                    or exists (select 1 from xxfnd_approval_rule_steps x
                                 join xxfnd_approval_rules ar on ar.rule_id = x.rule_id
                                 join xxfnd_approval_types y on y.approval_type_code = ar.approval_type_code
                                where x.role_code = r.role_code and nvl(y.application_code, '#') <> :c))~'
                into l_n using l_app.application_code, l_app.application_code;
            found('Roles in use', l_n);
            -- its APEX tasks and workflows
            select count(*) into l_n from apex_tasks where application_id = l_app.apex_application_id;
            found('Tasks', l_n);
            select count(*) into l_n from apex_workflows where application_id = l_app.apex_application_id;
            found('Workflows', l_n);
        exception
            when others then
                xxfnd_vpd_pkg.end_trusted;
                raise;
        end;
        xxfnd_vpd_pkg.end_trusted;
        if l_list is not null then
            return xxfnd_error_pkg.message('XXFND_APP_DELETE_DATA', apex_t_varchar2(l_app.application_code, l_list));
        end if;
        return null;
    end delete_blocker;

    procedure delete_application(p_application_code in varchar2) is
        l_code   xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_reason varchar2(4000);
    begin
        check_manage;
        l_reason := delete_blocker(l_code);
        if l_reason is not null then
            xxfnd_error_pkg.raise_error('XXFND_APP_DELETE_BLOCKED', apex_t_varchar2(l_reason));
        end if;
        -- release 88 (C9): the setup it registered goes first, each component removing its own rows (created after
        -- this package: called by name); a row still used by business data stops the delete (ORA-20196)
        for c in (select column_value pkg from table(apex_t_varchar2(
                      'XXFND_APPROVAL_RULE_PKG', 'XXFND_NOTIFY_PKG', 'XXFND_WORKFLOW_PKG', 'XXFND_INTEGRATION_PKG',
                      'XXFND_ATTACH_PKG', 'XXFND_DFF_PKG', 'XXFND_LOOKUP_PKG', 'XXFND_PRIVILEGE_PKG',
                      'XXFND_DATA_MODEL_PKG', 'XXFND_VPD_PKG'))) loop
            execute immediate 'begin ' || dbms_assert.simple_sql_name(c.pkg) || '.unregister_application(:c); end;'
                using l_code;
        end loop;
        -- its own standard rows (made when it was registered) go with it; unused roles take their privileges along
        delete from xxfnd_application_functions where application_code = l_code;
        -- XXFND_WORKFLOW_PROCESSES is created after this package (09e): by name
        execute immediate 'delete from xxfnd_workflow_processes where application_code = :c' using l_code;
        delete from xxfnd_setup_type_apps where application_code = l_code;
        delete from xxfnd_roles where application_code = l_code;
        delete from xxfnd_applications where application_code = l_code;
    end delete_application;

    procedure ensure_menu(p_application_code in varchar2) is
        l_code xxfnd_applications.application_code%type := upper(p_application_code);
        procedure entry(p_entry in varchar2, p_label in varchar2, p_type in varchar2, p_page in number,
                        p_feature in varchar2, p_icon in varchar2, p_seq in number) is
        begin
            insert into xxfnd_app_menu_entries (application_code, entry_code, label, display_sequence, icon_css,
                                                target_type, page_id, feature_code, made_by)
            select l_code, p_entry, p_label, p_seq, p_icon, p_type, p_page, p_feature, 'COMMON' from dual
             where not exists (select 1 from xxfnd_app_menu_entries
                                where application_code = l_code and entry_code = p_entry);
        end entry;
    begin
        if l_code = 'COMMON' then
            return;     -- COMMON has its own navigation
        end if;
        entry('MY_TASKS',      'My Tasks',      'COMMON_PAGE',  40,   null, 'fa-inbox',      10);
        entry('NOTIFICATIONS', 'Notifications', 'COMMON_PAGE',  43,   null, 'fa-bell-o',     20);
        entry('SHARED_SETUP',  'Shared Setup',  'SHARED_SETUP', null, null, 'fa-cogs',       80);
        entry('GIVE_FEEDBACK', 'Feedback',      'COMMON_PAGE',  173,  null, 'fa-comment-o',  90);
    end ensure_menu;

    procedure register_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number   default null,
                                  p_feature_code     in varchar2 default null,
                                  p_icon_css         in varchar2 default null,
                                  p_display_sequence in number   default null,
                                  p_parent_code      in varchar2 default null,
                                  p_menu_code        in varchar2 default 'SIDE') is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        if upper(p_target_type) not in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'SHARED_SETUP', 'FOLDER', 'USER_MENU', 'SIGN_OUT', 'SEPARATOR')
           or upper(nvl(p_menu_code, 'SIDE')) not in ('SIDE', 'TOP_BAR', 'ADMIN')
           or (upper(p_target_type) in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE') and p_page_id is null) then
            xxfnd_error_pkg.raise_error('XXFND_MENU_TARGET', apex_t_varchar2(p_entry_code));
        end if;
        insert into xxfnd_app_menu_entries (application_code, entry_code, label, parent_code, display_sequence, icon_css,
                                            target_type, page_id, feature_code, made_by, menu_code)
        select l_code, upper(trim(p_entry_code)), p_label, upper(p_parent_code), nvl(p_display_sequence, 100), p_icon_css,
               upper(p_target_type), p_page_id, upper(p_feature_code), 'APP', upper(nvl(p_menu_code, 'SIDE'))
          from dual
         where not exists (select 1 from xxfnd_app_menu_entries
                            where application_code = l_code and entry_code = upper(trim(p_entry_code)));
    end register_menu_entry;

    procedure save_menu_entry(p_application_code in varchar2,
                              p_entry_code       in varchar2,
                              p_label            in varchar2,
                              p_display_sequence in number,
                              p_icon_css         in varchar2,
                              p_enabled_flag     in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
    begin
        check_manage;
        update xxfnd_app_menu_entries
           set label = nvl(p_label, label), display_sequence = nvl(p_display_sequence, display_sequence),
               icon_css = nvl(p_icon_css, icon_css),
               enabled_flag = case when p_enabled_flag = 'N' then 'N' else 'Y' end
         where application_code = l_code and entry_code = upper(p_entry_code);
    end save_menu_entry;

    procedure maintain_menu_entry(p_application_code in varchar2,
                                  p_entry_code       in varchar2,
                                  p_label            in varchar2,
                                  p_parent_code      in varchar2,
                                  p_display_sequence in number,
                                  p_icon_css         in varchar2,
                                  p_target_type      in varchar2,
                                  p_page_id          in number,
                                  p_feature_code     in varchar2,
                                  p_enabled_flag     in varchar2,
                                  p_menu_code        in varchar2 default 'SIDE') is
        l_code   xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_menu   xxfnd_app_menu_entries.menu_code%type    := upper(nvl(p_menu_code, 'SIDE'));
        l_entry  xxfnd_app_menu_entries.entry_code%type   := upper(trim(p_entry_code));
        l_type   xxfnd_app_menu_entries.target_type%type  := upper(p_target_type);
        l_parent xxfnd_app_menu_entries.parent_code%type  := upper(trim(p_parent_code));
        l_page   number := case when l_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE') then p_page_id end;
        l_n      pls_integer;
    begin
        check_manage;
        if l_entry is null or trim(p_label) is null
           or l_type not in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE', 'SHARED_SETUP', 'FOLDER', 'USER_MENU', 'SIGN_OUT', 'SEPARATOR')
           or l_menu not in ('SIDE', 'TOP_BAR', 'ADMIN')
           or (l_type in ('COMMON_PAGE', 'APP_PAGE', 'ADMIN_PAGE') and l_page is null) then
            xxfnd_error_pkg.raise_error('XXFND_MENU_TARGET', apex_t_varchar2(nvl(l_entry, '-')));
        end if;
        -- the parent: a folder of the application, not the entry itself and not an entry inside it
        if l_parent is not null then
            select count(*) into l_n from xxfnd_app_menu_entries
             where application_code = l_code and entry_code = l_parent and target_type in ('FOLDER', 'USER_MENU')
               and menu_code = (select nvl(max(m.menu_code), l_menu) from xxfnd_app_menu_entries m
                                 where m.application_code = l_code and m.entry_code = l_entry)
               and l_parent not in (select entry_code from xxfnd_app_menu_entries
                                     where application_code = l_code
                                     start with entry_code = l_entry and application_code = l_code
                                     connect by prior entry_code = parent_code and application_code = l_code);
            if l_n = 0 then
                xxfnd_error_pkg.raise_error('XXFND_MENU_PARENT', apex_t_varchar2(l_entry));
            end if;
        end if;
        merge into xxfnd_app_menu_entries t
        using (select l_code application_code, l_entry entry_code from dual) s
           on (t.application_code = s.application_code and t.entry_code = s.entry_code)
         when matched then update set t.label = trim(p_label), t.parent_code = l_parent,
              t.display_sequence = nvl(p_display_sequence, t.display_sequence), t.icon_css = p_icon_css,
              t.target_type = l_type, t.page_id = l_page, t.feature_code = upper(p_feature_code),
              t.enabled_flag = case when p_enabled_flag = 'N' then 'N' else 'Y' end
         when not matched then insert (application_code, entry_code, label, parent_code, display_sequence, icon_css,
                                       target_type, page_id, feature_code, enabled_flag, made_by, menu_code)
              values (l_code, l_entry, trim(p_label), l_parent, nvl(p_display_sequence, 100), p_icon_css, l_type, l_page,
                      upper(p_feature_code), case when p_enabled_flag = 'N' then 'N' else 'Y' end, 'ADMIN', l_menu);
    end maintain_menu_entry;

    procedure delete_menu_entry(p_application_code in varchar2, p_entry_code in varchar2) is
        l_code xxfnd_applications.application_code%type := registered_code(p_application_code);
        l_by   xxfnd_app_menu_entries.made_by%type;
    begin
        check_manage;
        select max(made_by) into l_by from xxfnd_app_menu_entries
         where application_code = l_code and entry_code = upper(p_entry_code);
        if l_by is null then
            return;
        elsif l_by <> 'ADMIN' then
            xxfnd_error_pkg.raise_error('XXFND_MENU_DELETE', apex_t_varchar2(upper(p_entry_code)));
        end if;
        -- the entry with the entries inside it (only entries an administrator added)
        delete from xxfnd_app_menu_entries
         where application_code = l_code
           and entry_code in (select entry_code from xxfnd_app_menu_entries
                               where application_code = l_code
                               start with entry_code = upper(p_entry_code) and application_code = l_code
                               connect by prior entry_code = parent_code and application_code = l_code)
           and made_by = 'ADMIN';
        -- an entry of COMMON or the application inside it moves up to the top level
        update xxfnd_app_menu_entries set parent_code = null
         where application_code = l_code
           and parent_code is not null
           and parent_code not in (select entry_code from xxfnd_app_menu_entries where application_code = l_code);
    end delete_menu_entry;

    procedure sync_menu(p_application_code in varchar2) is
        l_code xxfnd_applications.application_code%type := upper(p_application_code);
        procedure entry(p_entry in varchar2, p_label in varchar2, p_type in varchar2, p_page in number, p_icon in varchar2,
                        p_seq in number, p_parent in varchar2 default null, p_menu in varchar2 default 'SIDE') is
        begin
            insert into xxfnd_app_menu_entries (application_code, entry_code, label, parent_code, display_sequence,
                                                icon_css, target_type, page_id, made_by, menu_code)
            select l_code, p_entry, p_label, p_parent, p_seq, p_icon, p_type, p_page, 'COMMON', p_menu from dual
             where not exists (select 1 from xxfnd_app_menu_entries
                                where application_code = l_code and entry_code = p_entry);
        end entry;
    begin
        if l_code <> 'COMMON' then
            return;     -- an application registers its own entries (REGISTER_MENU_ENTRY); COMMON adds its defaults (ENSURE_MENU)
        end if;
        -- COMMON's navigation menu: Home, My Tasks, a folder per module, an entry per screen (the feature's home page,
        -- else its first page) - who sees an entry follows the privilege of its page
        entry('HOME',     'Home',     'APP_PAGE', 1,  'fa-home',  0);
        entry('MY_TASKS', 'My Tasks', 'APP_PAGE', 40, 'fa-inbox', 1);
        for m in (select lookup_code, meaning, nvl(tag, 'fa-folder') icon, display_sequence
                    from xxfnd_lookup_values where lookup_type = 'XXFND_MODULE' and enabled_flag = 'Y') loop
            entry('M_' || m.lookup_code, m.meaning, 'FOLDER', null, m.icon, m.display_sequence);
        end loop;
        for f in (select f.feature_code, f.feature_name, f.feature_group, nvl(f.icon_css, 'fa-cog') icon,
                         f.display_sequence,
                         (select min(fp.page_id) keep (dense_rank first order by
                                     case when fp.page_id = f.home_page_id then 0 else 1 end,
                                     fp.tab_sequence nulls last, fp.page_id)
                            from xxfnd_feature_pages fp
                           where fp.app_alias = 'COMMON' and fp.feature_code = f.feature_code) page_id
                    from xxfnd_features f
                   where f.admin_flag = 'Y' and f.enabled_flag = 'Y' and f.home_page_id is not null
                     and exists (select 1 from xxfnd_lookup_values m
                                  where m.lookup_type = 'XXFND_MODULE' and m.lookup_code = f.feature_group)) loop
            if f.page_id is not null then
                entry('F_' || f.feature_code, f.feature_name, 'APP_PAGE', f.page_id, f.icon, f.display_sequence,
                      'M_' || f.feature_group);
            end if;
        end loop;
        -- COMMON's navigation bar: Notifications, Feedback and the user menu
        entry('NOTIFICATIONS', 'Notifications', 'APP_PAGE',  43,   'fa-bell-o',    5,  null, 'TOP_BAR');
        entry('GIVE_FEEDBACK', 'Feedback',      'APP_PAGE',  173,  'fa-comment-o', 6,  null, 'TOP_BAR');
        entry('USER_MENU',     'User',          'USER_MENU', null, 'fa-user',      10, null, 'TOP_BAR');
        entry('USER_MENU_SEP', '---',           'SEPARATOR', null, null,           20, 'USER_MENU', 'TOP_BAR');
        entry('SIGN_OUT',      'Sign Out',      'SIGN_OUT',  null, 'fa-sign-out',  30, 'USER_MENU', 'TOP_BAR');
    end sync_menu;

    function entry_visible(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                           p_feature_code in varchar2, p_enabled_flag in varchar2) return varchar2 is
        l_alias   xxfnd_applications.apex_app_alias%type;
        l_feature xxfnd_feature_pages.feature_code%type;
    begin
        if p_enabled_flag <> 'Y' then
            return 'N';
        elsif p_target_type in ('FOLDER', 'USER_MENU') then
            return 'Y';      -- shown when one of its entries is shown (XXFND_NAV_MENU_V)
        elsif p_target_type in ('SIGN_OUT', 'SEPARATOR') then
            return 'Y';      -- release 105: the user menu of every signed-in user
        elsif p_target_type = 'ADMIN_PAGE' and p_feature_code is null then
            -- the application's administration (e.g. its Administration page): an administrator of anything
            return case when xxfnd_privilege_pkg.has_any_admin_privilege then 'Y' else 'N' end;
        elsif p_target_type = 'SHARED_SETUP' or p_feature_code is not null
              or p_target_type not in ('APP_PAGE', 'ADMIN_PAGE', 'COMMON_PAGE') then
            return menu_visible(p_application_code, p_target_type, p_feature_code, p_enabled_flag);
        end if;
        -- a page of the application (release 106: or of COMMON): the privilege of the feature the page belongs to, as
        -- on the page itself
        if p_target_type = 'COMMON_PAGE' then
            l_alias := 'COMMON';
        else
            select max(apex_app_alias) into l_alias from xxfnd_applications where application_code = upper(p_application_code);
        end if;
        select max(feature_code) into l_feature
          from xxfnd_feature_pages where upper(app_alias) = upper(l_alias) and page_id = p_page_id;
        if l_feature is null then
            return 'Y';      -- a page of no feature (e.g. the home page): every signed-in user
        end if;
        return xxfnd_privilege_pkg.has_privilege_yn(l_feature, 'VIEW');
    end entry_visible;

    function menu_visible(p_application_code in varchar2, p_target_type in varchar2, p_feature_code in varchar2,
                          p_enabled_flag in varchar2) return varchar2 is
    begin
        if p_enabled_flag <> 'Y' then
            return 'N';
        elsif p_target_type = 'SHARED_SETUP' then
            return case when xxfnd_privilege_pkg.has_any_admin_privilege then 'Y' else 'N' end;
        elsif p_feature_code is null then
            return 'Y';      -- every signed-in user (what each COMMON page shows is limited to the user's own data)
        end if;
        return xxfnd_privilege_pkg.has_privilege_yn(p_feature_code, 'VIEW');
    end menu_visible;

    function menu_url(p_application_code in varchar2, p_target_type in varchar2, p_page_id in number,
                      p_feature_code in varchar2, p_entry_code in varchar2 default null) return varchar2 is
        l_alias xxfnd_applications.apex_app_alias%type;
    begin
        -- release 105: the entries of the user menu (navigation bar)
        if p_target_type = 'SIGN_OUT' then
            return '&LOGOUT_URL.';
        elsif p_target_type = 'SEPARATOR' then
            return 'separator';
        elsif p_target_type = 'USER_MENU' then
            return '#';
        elsif p_page_id = 173 and (p_target_type = 'COMMON_PAGE' or upper(p_application_code) = 'COMMON') then
            -- Give Feedback: on the page the user is on
            return apex_page.get_url(p_application => 'COMMON', p_page => 173,
                                     p_items  => 'P173_APPLICATION_ID,P173_PAGE_ID',
                                     p_values => v('APP_ID') || ',' || v('APP_PAGE_ID'));
        end if;
        if p_target_type in ('APP_PAGE', 'ADMIN_PAGE') then
            -- release 104: the application's own page, also when its menu is shown in COMMON
            select max(apex_app_alias) into l_alias from xxfnd_applications
             where application_code = upper(p_application_code);
            return apex_page.get_url(p_application => l_alias, p_page => p_page_id);
        elsif p_target_type = 'FOLDER' then
            -- release 111: a group opens its group page (its entries as cards); without a code it only expands
            return case when p_entry_code is not null then
                        apex_page.get_url(p_application => 'COMMON', p_page => 100, p_items => 'P100_GROUP',
                                          p_values => p_entry_code, p_clear_cache => '100') end;
        elsif p_target_type = 'SHARED_SETUP' then
            return apex_page.get_url(p_application => 'COMMON', p_page => 100);
        elsif p_page_id = 173 then
            -- Give Feedback: on the page the user is on
            return apex_page.get_url(p_application => 'COMMON', p_page => 173,
                                     p_items  => 'P173_APPLICATION_ID,P173_PAGE_ID',
                                     p_values => v('APP_ID') || ',' || v('APP_PAGE_ID'));
        end if;
        return apex_page.get_url(p_application => 'COMMON', p_page => p_page_id);
    end menu_url;

end xxfnd_application_pkg;
/
