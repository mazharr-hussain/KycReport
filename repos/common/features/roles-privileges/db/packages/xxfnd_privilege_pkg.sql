
--------------------------------------------------------------------------------
-- Privilege API
--------------------------------------------------------------------------------
create or replace package xxfnd_privilege_pkg authid definer as
    -- Current (or given) user holds FEATURE.ACTION through an active role.
    function has_privilege(p_feature_code in varchar2, p_action in varchar2,
                           p_user_name in varchar2 default null) return boolean;
    function has_privilege_yn(p_feature_code in varchar2, p_action in varchar2,
                              p_user_name in varchar2 default null) return varchar2;
    -- Privilege on the feature an APEX page belongs to. Unmapped page = no access.
    function has_page_privilege(p_page_id in number, p_action in varchar2,
                                p_app_alias in varchar2 default null) return boolean;
    -- For DML processes: request CREATE needs CREATE, any other request needs MANAGE.
    function has_page_request_privilege(p_page_id in number, p_request in varchar2,
                                        p_app_alias in varchar2 default null) return boolean;
    -- True when the user holds at least one privilege (application-level check).
    function has_any_privilege(p_user_name in varchar2 default null) return boolean;
    -- True when the user holds a privilege on any admin feature (Admin Console).
    function has_any_admin_privilege(p_user_name in varchar2 default null) return boolean;
    -- release 47: the running application (XXFND_APPLICATIONS) found by its APEX alias, else by its APEX ID;
    -- null outside APEX.
    function current_application_id return number;
    -- Records the APEX ID of the running application in this environment (called at sign-in).
    procedure sync_current_application;
    -- Colon-separated privilege codes of a role (shuttle value on the Role screen).
    function role_privilege_list(p_role_code in varchar2) return varchar2;
    -- Makes the role hold exactly the given privileges (colon-separated).
    procedure set_role_privileges(p_role_code in varchar2, p_privilege_list in varchar2);
    -- release 79 (from XXFND_SECURITY_PKG): roles and segregation of duties
    function has_role(p_role_code in varchar2, p_user_name in varchar2 default null) return boolean;
    function has_role_yn(p_role_code in varchar2, p_user_name in varchar2 default null) return varchar2;
    -- Comma-separated role codes; true when the user holds any of them.
    function has_any_role(p_role_codes in varchar2, p_user_name in varchar2 default null) return boolean;
    -- Y/N form of HAS_ANY_ROLE for use in SQL (report where clauses, LOVs).
    function has_any_role_yn(p_role_codes in varchar2, p_user_name in varchar2 default null) return varchar2;
    -- True when one of the user's roles may see sensitive data (XXFND_ROLES.VIEW_SENSITIVE_FLAG).
    function can_view_sensitive(p_user_name in varchar2 default null) return boolean;
    -- Four-eyes: true when acting under p_role_code would combine, on the same record, with a role the user
    -- already acted under there (p_prior_roles, SAME_RECORD rules), or when the user permanently holds a
    -- GLOBAL-conflicting role.
    function sod_conflict(p_role_code   in varchar2,
                          p_prior_roles in apex_t_varchar2 default null,
                          p_user_name   in varchar2 default null) return boolean;

    ----------------------------------------------------------------------------
    -- Release 86: registration by an application (its install script or COMMON's onboarding). Each adds the row only
    -- when it is missing and never changes what an administrator changed; a re-run does nothing. The application
    -- must be registered (XXFND_APP_NOT_REGISTERED, ORA-20180); a row of another application is refused
    -- (ORA-20186). No APEX session needed.
    ----------------------------------------------------------------------------
    procedure register_feature(p_application_code in varchar2,
                               p_feature_code     in varchar2,
                               p_feature_name     in varchar2,
                               p_feature_group    in varchar2 default 'BUSINESS',
                               p_display_sequence in number   default 100,
                               p_admin_flag       in varchar2 default 'N',
                               p_home_page_id     in number   default null,
                               p_icon_css         in varchar2 default null,
                               p_description      in varchar2 default null);
    -- A page of the application belongs to a feature (the application's APEX alias; ORA-20187 for an unknown feature).
    procedure register_feature_page(p_application_code in varchar2,
                                    p_feature_code     in varchar2,
                                    p_page_id          in number,
                                    p_tab_label        in varchar2 default null,
                                    p_tab_sequence     in number   default null);
    -- FEATURE.ACTION (VIEW, CREATE or MANAGE) of one of the application's features.
    procedure register_privilege(p_application_code in varchar2,
                                 p_feature_code     in varchar2,
                                 p_action_code      in varchar2,
                                 p_privilege_name   in varchar2 default null);
    -- Release 86: the privileges every role holds (each user works his own tasks, sends the e-mails and sees the
    -- documents of the records he may see, gives feedback): given to a new role (trigger XXFND_ROLES_EVERY_ROLE, 28),
    -- only those that exist; nothing else is changed.
    procedure give_every_role_privileges(p_role_code in varchar2);
    procedure register_role(p_application_code    in varchar2,
                            p_role_code           in varchar2,
                            p_role_name           in varchar2,
                            p_description         in varchar2 default null,
                            p_view_sensitive_flag in varchar2 default 'N');
    -- Gives one privilege (any application's, e.g. COMMON's DOCUMENTS.VIEW) to a role of the application. Additive:
    -- the role's other privileges stay (SET_ROLE_PRIVILEGES replaces them all).
    procedure add_role_privilege(p_application_code in varchar2, p_role_code in varchar2, p_privilege_code in varchar2);
    -- Two roles one person may not combine (stored in canonical order; scope SAME_RECORD or GLOBAL); at least one
    -- of them is the application's.
    procedure register_sod_rule(p_application_code in varchar2,
                                p_role_code_1      in varchar2,
                                p_role_code_2      in varchar2,
                                p_conflict_scope   in varchar2 default 'SAME_RECORD',
                                p_description      in varchar2 default null);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    -- C8: a page of the application no longer mapped to a feature
    procedure unregister_feature_page(p_application_code in varchar2, p_page_id in number);
    procedure unregister_privilege(p_application_code in varchar2, p_privilege_code in varchar2);
    -- the feature with its privileges and pages (refused while a role holds one of its privileges: in use)
    procedure unregister_feature(p_application_code in varchar2, p_feature_code in varchar2);
    -- a role given to nobody (its privileges and data rules go with it)
    procedure unregister_role(p_application_code in varchar2, p_role_code in varchar2);
    -- the pages, privileges and features of the application (its roles are deleted with the application)
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_privilege_pkg;
/

create or replace package body xxfnd_privilege_pkg as

    function norm_user(p_user_name in varchar2) return varchar2 is
    begin
        return upper(nvl(p_user_name, xxfnd_util_pkg.current_user));
    end norm_user;

    function has_privilege(p_feature_code in varchar2, p_action in varchar2,
                           p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);   -- private function: not callable inside SQL
    begin
        select count(*) into l_count
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name   = l_user
           and ur.active_flag = 'Y'
           and f.enabled_flag = 'Y'
           and p.feature_code = upper(p_feature_code)
           and p.action_code  = upper(p_action)
           and rownum = 1;
        return l_count > 0;
    end has_privilege;

    function has_privilege_yn(p_feature_code in varchar2, p_action in varchar2,
                              p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when has_privilege(p_feature_code, p_action, p_user_name) then 'Y' else 'N' end;
    end has_privilege_yn;

    function page_feature(p_page_id in number, p_app_alias in varchar2) return varchar2 is
        l_feature xxfnd_feature_pages.feature_code%type;
    begin
        select max(feature_code) into l_feature
          from xxfnd_feature_pages
         where upper(app_alias) = upper(nvl(p_app_alias, v('APP_ALIAS')))
           and page_id = p_page_id;
        return l_feature;
    end page_feature;

    function has_page_privilege(p_page_id in number, p_action in varchar2,
                                p_app_alias in varchar2 default null) return boolean is
        l_feature xxfnd_feature_pages.feature_code%type := page_feature(p_page_id, p_app_alias);
    begin
        return l_feature is not null and has_privilege(l_feature, p_action);
    end has_page_privilege;

    function has_page_request_privilege(p_page_id in number, p_request in varchar2,
                                        p_app_alias in varchar2 default null) return boolean is
    begin
        return has_page_privilege(p_page_id,
                                  case when upper(p_request) = 'CREATE' then 'CREATE' else 'MANAGE' end,
                                  p_app_alias);
    end has_page_request_privilege;

    function current_application_id return number is
        l_id number;
    begin
        if v('APP_ID') is null then
            return null;
        end if;
        select max(application_id) keep (dense_rank first order by case when upper(apex_app_alias) = upper(v('APP_ALIAS')) then 0 else 1 end)
          into l_id
          from xxfnd_applications
         where upper(apex_app_alias) = upper(v('APP_ALIAS'))
            or apex_application_id = to_number(v('APP_ID'));
        return l_id;
    end current_application_id;

    procedure sync_current_application is
    begin
        update xxfnd_applications
           set apex_application_id = to_number(v('APP_ID'))
         where upper(apex_app_alias) = upper(v('APP_ALIAS'))
           and decode(apex_application_id, to_number(v('APP_ID')), 0, 1) = 1;
        -- release 73: every other registered application too (from its alias), so its APEX ID is known before
        -- its own first sign-in
        update xxfnd_applications a
           set a.apex_application_id = (select max(x.application_id) from apex_applications x
                                         where upper(x.alias) = upper(a.apex_app_alias))
         where upper(a.apex_app_alias) <> upper(nvl(v('APP_ALIAS'), '#'))
           and exists (select 1 from apex_applications x where upper(x.alias) = upper(a.apex_app_alias))
           and decode(a.apex_application_id, (select max(x.application_id) from apex_applications x
                                               where upper(x.alias) = upper(a.apex_app_alias)), 0, 1) = 1;
    end sync_current_application;

    function has_any_privilege(p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
        l_app   number := current_application_id;
    begin
        -- release 46: a privilege on a feature of the current application (any application outside APEX)
        select count(*) into l_count
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name = l_user and ur.active_flag = 'Y' and f.enabled_flag = 'Y'
           and (l_app is null or f.application_id = l_app)
           and rownum = 1;
        return l_count > 0;
    end has_any_privilege;

    function has_any_admin_privilege(p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
        l_app   number := current_application_id;
    begin
        select count(*) into l_count
          from xxfnd_user_roles_v ur
          join xxfnd_role_privileges rp on rp.role_code = ur.role_code
          join xxfnd_privileges p       on p.privilege_code = rp.privilege_code
          join xxfnd_features f         on f.feature_code = p.feature_code
         where ur.user_name = l_user and ur.active_flag = 'Y'
           and f.admin_flag = 'Y' and f.enabled_flag = 'Y'
           and (l_app is null or f.application_id = l_app)
           and rownum = 1;
        return l_count > 0;
    end has_any_admin_privilege;

    function role_privilege_list(p_role_code in varchar2) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(privilege_code, ':') within group (order by privilege_code) into l_list
          from xxfnd_role_privileges
         where role_code = p_role_code;
        return l_list;
    end role_privilege_list;

    procedure set_role_privileges(p_role_code in varchar2, p_privilege_list in varchar2) is
        l_wanted apex_t_varchar2 := apex_string.split(p_privilege_list, ':');
    begin
        delete from xxfnd_role_privileges
         where role_code = p_role_code
           and privilege_code not in (select column_value from table(l_wanted));
        insert into xxfnd_role_privileges (role_code, privilege_code)
        select p_role_code, p.privilege_code
          from xxfnd_privileges p
         where p.privilege_code in (select column_value from table(l_wanted))
           and not exists (select 1 from xxfnd_role_privileges rp
                            where rp.role_code = p_role_code and rp.privilege_code = p.privilege_code);
    end set_role_privileges;

    -- release 79: roles and segregation of duties (from XXFND_SECURITY_PKG)
    function has_role(p_role_code in varchar2, p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select count(*)
          into l_count
          from xxfnd_user_roles_v v
         where v.user_name = l_user
           and v.role_code = p_role_code
           and v.active_flag = 'Y';
        return l_count > 0;
    end has_role;

    function has_role_yn(p_role_code in varchar2, p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when has_role(p_role_code, p_user_name) then 'Y' else 'N' end;
    end has_role_yn;

    function has_any_role(p_role_codes in varchar2, p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select count(*)
          into l_count
          from xxfnd_user_roles_v v
         where v.user_name = l_user
           and v.active_flag = 'Y'
           and v.role_code in (select trim(column_value)
                                 from table(apex_string.split(p_role_codes, ',')));
        return l_count > 0;
    end has_any_role;

    function has_any_role_yn(p_role_codes in varchar2, p_user_name in varchar2 default null) return varchar2 is
    begin
        return case when has_any_role(p_role_codes, p_user_name) then 'Y' else 'N' end;
    end has_any_role_yn;

    function can_view_sensitive(p_user_name in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        select count(*)
          into l_count
          from xxfnd_user_roles_v v
          join xxfnd_roles r on r.role_code = v.role_code
         where v.user_name = l_user
           and v.active_flag = 'Y'
           and r.view_sensitive_flag = 'Y';
        return l_count > 0;
    end can_view_sensitive;

    function sod_conflict(p_role_code   in varchar2,
                          p_prior_roles in apex_t_varchar2 default null,
                          p_user_name   in varchar2 default null) return boolean is
        l_count pls_integer;
        l_user  varchar2(255) := norm_user(p_user_name);
    begin
        -- Same record: the user already acted on this record under a conflicting role.
        if p_prior_roles is not null and p_prior_roles.count > 0 then
            select count(*)
              into l_count
              from xxfnd_sod_rules s
             where s.enabled_flag = 'Y'
               and s.conflict_scope = 'SAME_RECORD'
               and ((s.role_code_1 = p_role_code and s.role_code_2 in (select column_value from table(p_prior_roles))) or
                    (s.role_code_2 = p_role_code and s.role_code_1 in (select column_value from table(p_prior_roles))));
            if l_count > 0 then
                return true;
            end if;
        end if;

        -- Global: the user holds a role that may never be combined with p_role_code.
        select count(*)
          into l_count
          from xxfnd_sod_rules s
          join xxfnd_user_roles_v v
            on v.user_name = l_user
           and v.active_flag = 'Y'
           and v.role_code = case when s.role_code_1 = p_role_code then s.role_code_2 else s.role_code_1 end
         where s.enabled_flag = 'Y'
           and s.conflict_scope = 'GLOBAL'
           and p_role_code in (s.role_code_1, s.role_code_2);
        return l_count > 0;
    end sod_conflict;

    ----------------------------------------------------------------------------
    -- Release 86: registration
    ----------------------------------------------------------------------------
    -- the registered application (the rule is XXFND_APPLICATION_PKG's, installed after this package (09d): called
    -- by name)
    function app_row(p_application_code in varchar2) return xxfnd_applications%rowtype is
        l_code xxfnd_applications.application_code%type;
        l_row  xxfnd_applications%rowtype;
    begin
        execute immediate 'begin :r := xxfnd_application_pkg.registered_code(:c); end;'
            using out l_code, in p_application_code;
        select * into l_row from xxfnd_applications where application_code = l_code;
        return l_row;
    end app_row;

    -- release 88: XXFND_APPLICATION_PKG is created after this package (09d): called by name
    function registered_code(p_application_code in varchar2) return varchar2 is
        l_code varchar2(30);
    begin
        execute immediate 'begin :r := xxfnd_application_pkg.registered_code(:c); end;' using out l_code, in p_application_code;
        return l_code;
    end registered_code;

    procedure remove_registered(p_application_code in varchar2, p_what in varchar2, p_table in varchar2,
                                p_key_columns in apex_t_varchar2, p_keys in apex_t_varchar2,
                                p_owner_sql in varchar2 default 't.application_code') is
    begin
        execute immediate 'begin xxfnd_application_pkg.remove_registered(:a, :w, :t, :c, :k, :o); end;'
            using p_application_code, p_what, p_table, p_key_columns, p_keys, p_owner_sql;
    end remove_registered;

    procedure remove_all_registered(p_application_code in varchar2, p_what in varchar2, p_table in varchar2,
                                    p_owner_sql in varchar2 default 't.application_code') is
    begin
        execute immediate 'begin xxfnd_application_pkg.remove_all_registered(:a, :w, :t, :o); end;'
            using p_application_code, p_what, p_table, p_owner_sql;
    end remove_all_registered;

    procedure same_application(p_what in varchar2, p_key in varchar2, p_row_application in varchar2,
                               p_application_code in varchar2) is
    begin
        execute immediate 'begin xxfnd_application_pkg.assert_same_application(:w, :k, :r, :a); end;'
            using p_what, p_key, p_row_application, p_application_code;
    end same_application;

    -- the application code of a feature; P_EXISTS false when the feature does not exist
    function feature_application(p_feature_code in varchar2, p_exists out boolean) return varchar2 is
        l_n    pls_integer;
        l_code xxfnd_applications.application_code%type;
    begin
        select count(*), max(a.application_code) into l_n, l_code
          from xxfnd_features f left join xxfnd_applications a on a.application_id = f.application_id
         where f.feature_code = upper(p_feature_code);
        p_exists := l_n > 0;
        return l_code;
    end feature_application;

    -- the application of a role (ORA-20187 when the role does not exist)
    function role_application(p_role_code in varchar2) return varchar2 is
        l_code xxfnd_roles.application_code%type;
        l_n    pls_integer;
    begin
        select count(*), max(application_code) into l_n, l_code from xxfnd_roles where role_code = upper(p_role_code);
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Role', upper(p_role_code)));
        end if;
        return l_code;
    end role_application;

    procedure register_feature(p_application_code in varchar2,
                               p_feature_code     in varchar2,
                               p_feature_name     in varchar2,
                               p_feature_group    in varchar2 default 'BUSINESS',
                               p_display_sequence in number   default 100,
                               p_admin_flag       in varchar2 default 'N',
                               p_home_page_id     in number   default null,
                               p_icon_css         in varchar2 default null,
                               p_description      in varchar2 default null) is
        l_app    xxfnd_applications%rowtype := app_row(p_application_code);
        l_exists boolean;
        l_owner  xxfnd_applications.application_code%type;
    begin
        l_owner := feature_application(p_feature_code, l_exists);
        if l_exists then
            same_application('Feature', upper(p_feature_code), l_owner, l_app.application_code);
            return;
        end if;
        -- HOME_PAGE_ID / ICON_CSS are added after this package (09c): written by name
        execute immediate 'insert into xxfnd_features (feature_code, feature_name, feature_group, display_sequence,
                                admin_flag, application_id, home_page_id, icon_css, description)
                           values (:1, :2, :3, :4, :5, :6, :7, :8, :9)'
            using upper(p_feature_code), p_feature_name, upper(nvl(p_feature_group, 'BUSINESS')),
                  nvl(p_display_sequence, 100), nvl(p_admin_flag, 'N'), l_app.application_id, p_home_page_id,
                  p_icon_css, p_description;
    end register_feature;

    procedure register_feature_page(p_application_code in varchar2,
                                    p_feature_code     in varchar2,
                                    p_page_id          in number,
                                    p_tab_label        in varchar2 default null,
                                    p_tab_sequence     in number   default null) is
        l_app    xxfnd_applications%rowtype := app_row(p_application_code);
        l_exists boolean;
        l_owner  xxfnd_applications.application_code%type;
    begin
        l_owner := feature_application(p_feature_code, l_exists);
        if not l_exists then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Feature', upper(p_feature_code)));
        end if;
        -- a page already mapped (perhaps changed by an administrator) is kept; TAB_LABEL / TAB_SEQUENCE are added
        -- after this package (09c): written by name
        execute immediate 'merge into xxfnd_feature_pages t
            using (select :a app_alias, :p page_id from dual) s
               on (upper(t.app_alias) = upper(s.app_alias) and t.page_id = s.page_id)
             when not matched then insert (app_alias, page_id, feature_code, tab_label, tab_sequence)
                                   values (s.app_alias, s.page_id, :f, :l, :s)'
            using nvl(l_app.apex_app_alias, l_app.application_code), p_page_id, upper(p_feature_code), p_tab_label,
                  p_tab_sequence;
    end register_feature_page;

    procedure register_privilege(p_application_code in varchar2,
                                 p_feature_code     in varchar2,
                                 p_action_code      in varchar2,
                                 p_privilege_name   in varchar2 default null) is
        l_app    xxfnd_applications%rowtype := app_row(p_application_code);
        l_exists boolean;
        l_owner  xxfnd_applications.application_code%type;
        l_name   xxfnd_features.feature_name%type;
    begin
        l_owner := feature_application(p_feature_code, l_exists);
        if not l_exists then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Feature', upper(p_feature_code)));
        end if;
        same_application('Feature', upper(p_feature_code), l_owner, l_app.application_code);
        select feature_name into l_name from xxfnd_features where feature_code = upper(p_feature_code);
        merge into xxfnd_privileges t
        using (select upper(p_feature_code) || '.' || upper(p_action_code) privilege_code from dual) s
           on (t.privilege_code = s.privilege_code)
         when not matched then insert (privilege_code, feature_code, action_code, privilege_name)
                               values (s.privilege_code, upper(p_feature_code), upper(p_action_code),
                                       substr(nvl(p_privilege_name, l_name || ' - ' || initcap(p_action_code)), 1, 240));
    end register_privilege;

    procedure give_every_role_privileges(p_role_code in varchar2) is
    begin
        merge into xxfnd_role_privileges t
        using (select upper(p_role_code) role_code, p.privilege_code
                 from xxfnd_privileges p
                where p.privilege_code in ('MY_TASKS.VIEW', 'MY_TASKS.MANAGE', 'COMMUNICATIONS.VIEW',
                                           'COMMUNICATIONS.CREATE', 'DOCUMENTS.VIEW', 'DOCUMENTS.CREATE',
                                           'DOCUMENTS.MANAGE', 'GIVE_FEEDBACK.VIEW', 'GIVE_FEEDBACK.CREATE')) s
           on (t.role_code = s.role_code and t.privilege_code = s.privilege_code)
         when not matched then insert (role_code, privilege_code) values (s.role_code, s.privilege_code);
    end give_every_role_privileges;

    procedure register_role(p_application_code    in varchar2,
                            p_role_code           in varchar2,
                            p_role_name           in varchar2,
                            p_description         in varchar2 default null,
                            p_view_sensitive_flag in varchar2 default 'N') is
        l_app  xxfnd_applications%rowtype := app_row(p_application_code);
        l_n    pls_integer;
        l_code xxfnd_roles.application_code%type;
    begin
        select count(*), max(application_code) into l_n, l_code from xxfnd_roles where role_code = upper(p_role_code);
        if l_n > 0 then
            same_application('Role', upper(p_role_code), l_code, l_app.application_code);
            return;
        end if;
        -- a role always has an application (COMMON's roles too)
        insert into xxfnd_roles (role_code, application_code, application_id, role_name, description, view_sensitive_flag)
        values (upper(p_role_code), l_app.application_code, l_app.application_id, p_role_name, p_description,
                nvl(p_view_sensitive_flag, 'N'));
    end register_role;

    procedure add_role_privilege(p_application_code in varchar2, p_role_code in varchar2, p_privilege_code in varchar2) is
        l_app xxfnd_applications%rowtype := app_row(p_application_code);
        l_n   pls_integer;
    begin
        same_application('Role', upper(p_role_code), role_application(p_role_code), l_app.application_code);
        select count(*) into l_n from xxfnd_privileges where privilege_code = upper(p_privilege_code);
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Privilege', upper(p_privilege_code)));
        end if;
        merge into xxfnd_role_privileges t
        using (select upper(p_role_code) role_code, upper(p_privilege_code) privilege_code from dual) s
           on (t.role_code = s.role_code and t.privilege_code = s.privilege_code)
         when not matched then insert (role_code, privilege_code) values (s.role_code, s.privilege_code);
    end add_role_privilege;

    procedure register_sod_rule(p_application_code in varchar2,
                                p_role_code_1      in varchar2,
                                p_role_code_2      in varchar2,
                                p_conflict_scope   in varchar2 default 'SAME_RECORD',
                                p_description      in varchar2 default null) is
        l_app xxfnd_applications%rowtype := app_row(p_application_code);
        l_r1  xxfnd_roles.role_code%type := least(upper(p_role_code_1), upper(p_role_code_2));
        l_r2  xxfnd_roles.role_code%type := greatest(upper(p_role_code_1), upper(p_role_code_2));
        l_a1  xxfnd_roles.application_code%type;
        l_a2  xxfnd_roles.application_code%type;
    begin
        l_a1 := role_application(l_r1);
        l_a2 := role_application(l_r2);
        -- at least one of the two roles is the application's own
        if l_app.application_code not in (l_a1, l_a2) then
            same_application('Role', l_r1, l_a1, l_app.application_code);
        end if;
        merge into xxfnd_sod_rules t
        using (select l_r1 r1, l_r2 r2, upper(nvl(p_conflict_scope, 'SAME_RECORD')) scope from dual) s
           on (t.role_code_1 = s.r1 and t.role_code_2 = s.r2 and t.conflict_scope = s.scope)
         when not matched then insert (role_code_1, role_code_2, conflict_scope, description)
                               values (s.r1, s.r2, s.scope, p_description);
    end register_sod_rule;

    -- release 88 (C8, C9)
    procedure unregister_feature_page(p_application_code in varchar2, p_page_id in number) is
        l_app xxfnd_applications%rowtype := app_row(p_application_code);
    begin
        remove_registered(p_application_code, 'Feature page', 'XXFND_FEATURE_PAGES', apex_t_varchar2('APP_ALIAS', 'PAGE_ID'),
            apex_t_varchar2(nvl(l_app.apex_app_alias, l_app.application_code), to_char(p_page_id)),
            '(select max(a.application_code) from xxfnd_applications a where upper(nvl(a.apex_app_alias, a.application_code)) = upper(t.app_alias))');
    end unregister_feature_page;

    procedure unregister_privilege(p_application_code in varchar2, p_privilege_code in varchar2) is
    begin
        remove_registered(p_application_code, 'Privilege', 'XXFND_PRIVILEGES', apex_t_varchar2('PRIVILEGE_CODE'),
            apex_t_varchar2(upper(trim(p_privilege_code))),
            '(select a.application_code from xxfnd_features f join xxfnd_applications a on a.application_id = f.application_id where f.feature_code = t.feature_code)');
    end unregister_privilege;

    procedure unregister_feature(p_application_code in varchar2, p_feature_code in varchar2) is
        l_feature xxfnd_features.feature_code%type := upper(trim(p_feature_code));
        l_exists  boolean;
        l_owner   xxfnd_applications.application_code%type := feature_application(l_feature, l_exists);
    begin
        if l_exists and nvl(l_owner, 'COMMON') = registered_code(p_application_code) then
            for p in (select app_alias, page_id from xxfnd_feature_pages where feature_code = l_feature) loop
                unregister_feature_page(p_application_code, p.page_id);
            end loop;
            for p in (select privilege_code from xxfnd_privileges where feature_code = l_feature) loop
                unregister_privilege(p_application_code, p.privilege_code);
            end loop;
        end if;
        remove_registered(p_application_code, 'Feature', 'XXFND_FEATURES', apex_t_varchar2('FEATURE_CODE'), apex_t_varchar2(l_feature),
            '(select a.application_code from xxfnd_applications a where a.application_id = t.application_id)');
    end unregister_feature;

    procedure unregister_role(p_application_code in varchar2, p_role_code in varchar2) is
    begin
        remove_registered(p_application_code, 'Role', 'XXFND_ROLES', apex_t_varchar2('ROLE_CODE'), apex_t_varchar2(upper(trim(p_role_code))));
    end unregister_role;

    procedure unregister_application(p_application_code in varchar2) is
        l_app xxfnd_applications%rowtype := app_row(p_application_code);
    begin
        -- the application's own roles are taken back from their users (the roles go with the application)
        delete from xxfnd_user_roles
         where role_code in (select role_code from xxfnd_roles where application_code = l_app.application_code);
        -- the application's roles keep no privilege of its features (the roles go with the application)
        delete from xxfnd_role_privileges rp
         where rp.role_code in (select role_code from xxfnd_roles where application_code = l_app.application_code)
           and rp.privilege_code in (select p.privilege_code from xxfnd_privileges p
                                       join xxfnd_features f on f.feature_code = p.feature_code
                                      where f.application_id = l_app.application_id);
        remove_all_registered(p_application_code, 'Feature pages', 'XXFND_FEATURE_PAGES', '(select max(a.application_code) from xxfnd_applications a where upper(nvl(a.apex_app_alias, a.application_code)) = upper(t.app_alias))');
        remove_all_registered(p_application_code, 'Privileges', 'XXFND_PRIVILEGES', '(select a.application_code from xxfnd_features f join xxfnd_applications a on a.application_id = f.application_id where f.feature_code = t.feature_code)');
        remove_all_registered(p_application_code, 'Features', 'XXFND_FEATURES', '(select a.application_code from xxfnd_applications a where a.application_id = t.application_id)');
    end unregister_application;

end xxfnd_privilege_pkg;
/
