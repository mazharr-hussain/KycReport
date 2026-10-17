
--------------------------------------------------------------------------------
-- Row-level data security (Virtual Private Database)
--------------------------------------------------------------------------------
create or replace package xxfnd_vpd_pkg authid definer as
    -- DBMS_RLS policy function for every table that has data security rules.
    function policy(p_schema in varchar2, p_object in varchar2) return varchar2;
    -- Attach the policy to every table referenced by a rule (idempotent).
    procedure apply_policies;
    -- Narrow bypass for server code that has already authorised the caller
    -- (e.g. a validated RFI response token). Always paired with end_trusted.
    procedure begin_trusted;
    -- Release 84: Y-state of that bypass (or a background job, as the policy): the other row policies of the setup
    -- (the administration scope of XXFND_APPLICATION_PKG) honour it too.
    function is_trusted return boolean;
    procedure end_trusted;
    -- Release 74 (R23): the predicate of a user and table is kept for a few seconds in the APEX session (a report
    -- that calls a function per row runs the policy once, not once per row). CLEAR_CACHE forgets it at once.
    procedure clear_cache;
    -- Release 76: the values of P_COLUMN in P_TABLE the user's data security allows, for a form's list of values and
    -- the save check: null = every value (a rule for all rows or for the user's own records), otherwise the
    -- comma-separated values of the user's "column in list" rules on that column ('#NONE' when no rule gives any).
    function allowed_values(p_table in varchar2, p_column in varchar2, p_user in varchar2 default null) return varchar2;
    -- Release 79: assign a data access rule to a user (P_USER_ID) or a role (P_ROLE_CODE); nothing happens when it is
    -- assigned already. The same call serves the User, Role and Data access rule screens.
    procedure assign_rule(p_rule_id in number, p_user_id in number default null, p_role_code in varchar2 default null);
    procedure unassign_rule(p_assignment_id in number);

    -- Release 86: a data access rule of a role of the application (registration: added only when the role has no
    -- rule of that type on that table and column; assigned to the role). The application must be registered
    -- (ORA-20180) and own the role (ORA-20186). The table gets its policy from the application's own install
    -- (XXFND_SCHEMA_PKG.APPLY_POLICIES in its schema).
    procedure register_data_rule(p_application_code in varchar2,
                                 p_role_code        in varchar2,
                                 p_table_name       in varchar2,
                                 p_rule_type        in varchar2,
                                 p_column_name      in varchar2 default null,
                                 p_value_list       in varchar2 default null,
                                 p_description      in varchar2 default null);
end xxfnd_vpd_pkg;
/

create or replace package body xxfnd_vpd_pkg as
    g_trusted pls_integer := 0;
    c_policy  constant varchar2(30) := 'XXFND_DATA_SECURITY';
    -- predicate cache (R23): key APEX session : user : table; an entry lives c_cache_ttl hundredths of a second, so a
    -- change of roles or rules applies within seconds even where the package state outlives the request
    c_cache_ttl constant pls_integer := 500;
    type t_entry is record (predicate varchar2(32767), stamp pls_integer);
    type t_cache is table of t_entry index by varchar2(400);
    g_cache t_cache;

    -- release 79: the enabled rules of a table that apply to a user - assigned to the user or to one of the user's
    -- active roles (XXFND_DATA_RULE_ASSIGNMENTS); access adds up
    cursor c_rules(p_user in varchar2, p_table in varchar2) is
        select distinct d.rule_type, d.column_name, d.value_list
          from xxfnd_data_security_rules d
          join xxfnd_data_rule_assignments a on a.rule_id = d.rule_id
         where d.enabled_flag = 'Y'
           and d.table_name = p_table
           and (a.user_id in (select u.user_id from xxfnd_users u where u.user_name = p_user and u.enabled_flag = 'Y')
                or a.role_code in (select ur.role_code from xxfnd_user_roles_v ur
                                    where ur.user_name = p_user and ur.active_flag = 'Y'));

    procedure clear_cache is begin g_cache.delete; end clear_cache;

    procedure begin_trusted is begin g_trusted := g_trusted + 1; end begin_trusted;
    procedure end_trusted   is begin g_trusted := greatest(g_trusted - 1, 0); end end_trusted;
    function is_trusted return boolean is
    begin
        return g_trusted > 0 or sys_context('USERENV', 'BG_JOB_ID') is not null;
    end is_trusted;

    function quoted_list(p_values in varchar2) return varchar2 is
        l_out varchar2(32767);
    begin
        for v in (select trim(column_value) val from table(apex_string.split(p_values, ','))
                   where trim(column_value) is not null) loop
            l_out := l_out || case when l_out is not null then ',' end
                           || dbms_assert.enquote_literal(replace(v.val, '''', ''''''));
        end loop;
        return l_out;
    end quoted_list;

    -- Users who delegate to p_user today (Workflow Setup > Delegations), comma-separated.
    function delegators(p_user in varchar2) return varchar2 is
        l_list varchar2(4000);
    begin
        select listagg(distinct upper(delegator_user_name), ',') within group (order by 1)
          into l_list
          from xxfnd_wf_delegations
         where upper(delegate_user_name) = p_user
           and trunc(sysdate) between start_date and end_date;
        return l_list;
    end delegators;

    function predicate(p_user in varchar2, p_object in varchar2) return varchar2;

    function policy(p_schema in varchar2, p_object in varchar2) return varchar2 is
        l_user      varchar2(255) := upper(sys_context('APEX$SESSION', 'APP_USER'));
        l_key       varchar2(400);
        l_predicate varchar2(32767);
    begin
        -- Install scripts, scheduler jobs and developer sessions run without an APEX user. APEX runs
        -- workflow activities and automations in scheduler background jobs (as NOBODY): system work too.
        -- Browser requests through ORDS never run in a scheduler job.
        if l_user is null or g_trusted > 0 or sys_context('USERENV', 'BG_JOB_ID') is not null then
            return null;
        end if;
        l_key := substr(sys_context('APEX$SESSION', 'APP_SESSION') || ':' || l_user || ':' || upper(p_object), 1, 400);
        if g_cache.exists(l_key) and abs(dbms_utility.get_time - g_cache(l_key).stamp) < c_cache_ttl then
            return g_cache(l_key).predicate;
        end if;
        l_predicate := predicate(l_user, p_object);
        g_cache(l_key).predicate := l_predicate;
        g_cache(l_key).stamp := dbms_utility.get_time;
        return l_predicate;
    end policy;

    function predicate(p_user in varchar2, p_object in varchar2) return varchar2 is
        l_user      varchar2(255) := p_user;
        l_predicate varchar2(32767);
        l_part      varchar2(4000);
    begin
        for r in c_rules(l_user, upper(p_object)) loop
            if r.rule_type = 'ALL_ROWS' then
                return null;
            end if;
            l_part := case r.rule_type
                        when 'OWN_RECORDS' then
                            -- the user's own rows, and those of anyone currently delegating to the user
                            'upper(' || dbms_assert.simple_sql_name(r.column_name) || ') in ('
                            || quoted_list(l_user || nvl2(delegators(l_user), ',' || delegators(l_user), null)) || ')'
                        when 'COLUMN_IN_LIST' then
                            dbms_assert.simple_sql_name(r.column_name) || ' in (' || quoted_list(r.value_list) || ')'
                      end;
            if l_part is not null then
                l_predicate := l_predicate || case when l_predicate is not null then ' or ' end || '(' || l_part || ')';
            end if;
        end loop;
        -- No rule for this user and table: deny.
        return nvl(l_predicate, '1 = 0');
    end predicate;

    function allowed_values(p_table in varchar2, p_column in varchar2, p_user in varchar2 default null) return varchar2 is
        l_user varchar2(255) := upper(nvl(p_user, xxfnd_util_pkg.current_user));
        l_list varchar2(32767);
        l_own  boolean := false;
    begin
        for r in c_rules(l_user, upper(p_table)) loop
            if r.rule_type = 'ALL_ROWS' then
                return null;
            elsif r.rule_type = 'OWN_RECORDS' then
                l_own := true;
            elsif r.rule_type = 'COLUMN_IN_LIST' and upper(r.column_name) = upper(p_column) then
                l_list := l_list || case when l_list is not null then ',' end || r.value_list;
            end if;
        end loop;
        -- release 79: a create list offers the "column in list" values even when the user also has own records;
        -- own records alone leave every value open (the record is the user's own)
        return case when l_list is not null then l_list when l_own then null else '#NONE' end;
    end allowed_values;

    -- only Data Security administrators change who a rule applies to
    procedure check_manage is
    begin
        if not xxfnd_privilege_pkg.has_privilege('DATA_SECURITY', 'MANAGE') then
            raise_application_error(-20070, 'You are not allowed to assign data access rules.');
        end if;
    end check_manage;

    procedure assign_rule(p_rule_id in number, p_user_id in number default null, p_role_code in varchar2 default null) is
    begin
        check_manage;
        if (p_user_id is null) = (p_role_code is null) then
            raise_application_error(-20071, 'Assign the rule to one user or one role.');
        end if;
        merge into xxfnd_data_rule_assignments t
        using (select p_rule_id rule_id, p_user_id user_id, p_role_code role_code from dual) s
           on (t.rule_id = s.rule_id and nvl(to_char(t.user_id), '#') = nvl(to_char(s.user_id), '#')
               and nvl(t.role_code, '#') = nvl(s.role_code, '#'))
         when not matched then insert (rule_id, user_id, role_code) values (s.rule_id, s.user_id, s.role_code);
        clear_cache;
    end assign_rule;

    procedure unassign_rule(p_assignment_id in number) is
    begin
        check_manage;
        delete from xxfnd_data_rule_assignments where assignment_id = p_assignment_id;
        clear_cache;
    end unassign_rule;

    procedure apply_policies is
    begin
        -- release 54: the generator is invoker rights (xxfnd_schema_pkg); called here, it covers this schema
        xxfnd_schema_pkg.apply_policies;
    end apply_policies;

    -- Release 86: registration
    procedure register_data_rule(p_application_code in varchar2,
                                 p_role_code        in varchar2,
                                 p_table_name       in varchar2,
                                 p_rule_type        in varchar2,
                                 p_column_name      in varchar2 default null,
                                 p_value_list       in varchar2 default null,
                                 p_description      in varchar2 default null) is
        l_code xxfnd_applications.application_code%type;
        l_role xxfnd_roles.application_code%type;
        l_n    pls_integer;
    begin
        -- the registration rule is XXFND_APPLICATION_PKG's, installed after this package (09d): called by name
        execute immediate 'begin :r := xxfnd_application_pkg.registered_code(:c); end;'
            using out l_code, in p_application_code;
        select count(*), max(application_code) into l_n, l_role from xxfnd_roles where role_code = upper(p_role_code);
        if l_n = 0 then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Role', upper(p_role_code)));
        end if;
        execute immediate 'begin xxfnd_application_pkg.assert_same_application(:w, :k, :r, :a); end;'
            using 'Role', upper(p_role_code), l_role, l_code;
        select count(*) into l_n from xxfnd_data_security_rules d
         where d.table_name = upper(p_table_name) and d.rule_type = upper(p_rule_type)
           and nvl(d.column_name, '#') = nvl(upper(p_column_name), '#')
           and (d.role_code = upper(p_role_code)
                or exists (select 1 from xxfnd_data_rule_assignments a
                            where a.rule_id = d.rule_id and a.role_code = upper(p_role_code)));
        if l_n = 0 then
            -- the trigger XXFND_DATA_RULES_ASSIGN assigns it to the role
            insert into xxfnd_data_security_rules (role_code, table_name, rule_type, column_name, value_list, description)
            values (upper(p_role_code), upper(p_table_name), upper(p_rule_type), upper(p_column_name), p_value_list,
                    p_description);
            clear_cache;
        end if;
    end register_data_rule;

end xxfnd_vpd_pkg;
/
