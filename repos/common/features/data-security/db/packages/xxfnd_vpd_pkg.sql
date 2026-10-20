
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

    ----------------------------------------------------------------------------
    -- Release 96: the security model (09a). Data access only through roles; it decides which records (privileges
    -- decide what). Every routine takes the application and changes only its rows (COMMON administrator: any).
    ----------------------------------------------------------------------------
    -- A dimension (what access is decided by): VALUE_SOURCE ORGANIZATION (P_ORGANIZATION_TYPE), LOOKUP (P_LOOKUP_TYPE)
    -- or FREE. Added when missing, otherwise its name and source are updated.
    procedure register_dimension(p_application_code  in varchar2,
                                 p_dimension_code    in varchar2,
                                 p_dimension_name    in varchar2,
                                 p_value_source      in varchar2 default 'ORGANIZATION',
                                 p_organization_type in varchar2 default null,
                                 p_lookup_type       in varchar2 default null,
                                 p_description       in varchar2 default null);
    -- A department / organization (type, code): added or updated; P_PARENT_CODE of the same type.
    procedure save_organization(p_application_code  in varchar2,
                                p_organization_type in varchar2,
                                p_organization_code in varchar2,
                                p_organization_name in varchar2,
                                p_parent_code       in varchar2 default null,
                                p_enabled_flag      in varchar2 default 'Y',
                                p_source_type       in varchar2 default 'LOCAL',
                                p_fusion_id         in varchar2 default null);
    -- A secured table of the application: P_DIMENSION_COLUMN holds the dimension's value, P_OWNER_COLUMN the owner.
    -- Release 102: P_DIMENSION_VALUE_TYPE CODE (default) - the column holds the value code; ID - it holds
    -- XXHR_ORGANIZATIONS.ORGANIZATION_ID (a dimension of value source ORGANIZATION). Null keeps a registered object's type.
    procedure register_data_object(p_application_code in varchar2,
                                   p_data_object_code in varchar2,
                                   p_object_name      in varchar2,
                                   p_table_name       in varchar2,
                                   p_dimension_code   in varchar2 default null,
                                   p_dimension_column in varchar2 default null,
                                   p_owner_column     in varchar2 default null,
                                   p_description      in varchar2 default null,
                                   p_dimension_value_type in varchar2 default null);
    -- A role reaches the records of a data object at a level: ALL, VALUES (the assignment's values) or OWN.
    procedure grant_data_access(p_application_code in varchar2, p_role_code in varchar2,
                                p_data_object_code in varchar2, p_access_level in varchar2);
    procedure revoke_data_access(p_application_code in varchar2, p_role_code in varchar2,
                                 p_data_object_code in varchar2, p_access_level in varchar2 default null);
    -- The values of a user's role assignment for a dimension: P_DATA_OBJECT_CODE null = the default of every object of
    -- the dimension, set = an override for that object. P_VALUES (comma-separated) replace the current ones; empty
    -- removes them (an override removed = the object follows the default again).
    procedure set_assignment_values(p_user_role_id     in number,
                                    p_dimension_code   in varchar2,
                                    p_data_object_code in varchar2 default null,
                                    p_values           in varchar2 default null);
    function assignment_values(p_user_role_id in number, p_dimension_code in varchar2,
                               p_data_object_code in varchar2 default null) return varchar2;
    -- the application's dimensions, organizations and data objects (XXFND_APPLICATION_PKG.DELETE_APPLICATION)
    procedure unregister_application(p_application_code in varchar2);
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

    -- release 96: the user's data access to a data object (XXFND_USER_DATA_ACCESS_V): every level of every active
    -- role; for VALUES the assignment's values (override, else default)
    cursor c_access(p_user in varchar2, p_table in varchar2) is
        select access_level, dimension_column, owner_column,
               -- release 102: as the column holds it (code, or organization ID)
               listagg(distinct dimension_value, ',') within group (order by dimension_value) as value_list
          from xxfnd_user_data_access_v
         where user_name = p_user and table_name = p_table
         group by access_level, dimension_column, owner_column;

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


    function has_object(p_table in varchar2) return boolean is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxfnd_data_objects where table_name = upper(p_table) and enabled_flag = 'Y';
        return l_n > 0;
    end has_object;

    function predicate_96(p_user in varchar2, p_table in varchar2) return varchar2 is
        l_predicate varchar2(32767);
        l_part      varchar2(4000);
    begin
        for r in c_access(p_user, p_table) loop
            if r.access_level = 'ALL' then
                return null;
            end if;
            l_part := case
                        when r.access_level = 'OWN' and r.owner_column is not null then
                            -- the user's own rows, and those of anyone currently delegating to the user
                            'upper(' || dbms_assert.simple_sql_name(r.owner_column) || ') in ('
                            || quoted_list(p_user || nvl2(delegators(p_user), ',' || delegators(p_user), null)) || ')'
                        when r.access_level = 'VALUES' and r.dimension_column is not null and r.value_list is not null then
                            dbms_assert.simple_sql_name(r.dimension_column) || ' in (' || quoted_list(r.value_list) || ')'
                      end;
            if l_part is not null then
                l_predicate := l_predicate || case when l_predicate is not null then ' or ' end || '(' || l_part || ')';
            end if;
        end loop;
        return nvl(l_predicate, '1 = 0');
    end predicate_96;

    function predicate(p_user in varchar2, p_object in varchar2) return varchar2 is
        l_user      varchar2(255) := p_user;
        l_predicate varchar2(32767);
        l_part      varchar2(4000);
    begin
        if has_object(p_object) then
            return predicate_96(l_user, upper(p_object));   -- release 96: the security model
        end if;
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
        if has_object(p_table) then
            -- release 96: the values of the user's VALUES access on that column (any ALL: every value)
            for r in c_access(l_user, upper(p_table)) loop
                if r.access_level = 'ALL' then
                    return null;
                elsif r.access_level = 'OWN' then
                    l_own := true;
                elsif r.access_level = 'VALUES' and upper(r.dimension_column) = upper(p_column) and r.value_list is not null then
                    l_list := l_list || case when l_list is not null then ',' end || r.value_list;
                end if;
            end loop;
            return case when l_list is not null then l_list when l_own then null else '#NONE' end;
        end if;
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
        -- release 96: the same access in the security model (the table becomes a data object of the role's
        -- application when it is not one yet; a "column in list" rule's fixed values are not carried: in the model
        -- values belong to each user's role assignment)
        declare
            l_obj   xxfnd_data_objects.data_object_code%type;
            l_level varchar2(10) := case upper(p_rule_type) when 'ALL_ROWS' then 'ALL' when 'OWN_RECORDS' then 'OWN'
                                                           else 'VALUES' end;
        begin
            select max(data_object_code) into l_obj from xxfnd_data_objects where table_name = upper(p_table_name);
            if l_obj is null then
                l_obj := substr(upper(p_table_name), 1, 60);
                insert into xxfnd_data_objects (data_object_code, object_name, application_code, table_name, owner_column)
                values (l_obj, initcap(replace(regexp_replace(upper(p_table_name), '^XX[A-Z]+_'), '_', ' ')),
                        case when upper(p_table_name) like 'XXFND\_%' escape '\' or upper(p_table_name) like 'XXHR\_%' escape '\'
                             then 'COMMON' else l_code end,
                        upper(p_table_name), case when l_level = 'OWN' then upper(p_column_name) end);
            elsif l_level = 'OWN' then
                update xxfnd_data_objects set owner_column = nvl(owner_column, upper(p_column_name))
                 where data_object_code = l_obj;
            end if;
            merge into xxfnd_role_data_access t
            using (select upper(p_role_code) r, l_obj o, l_level l from dual) x
               on (t.role_code = x.r and t.data_object_code = x.o and t.access_level = x.l)
             when not matched then insert (role_code, data_object_code, access_level) values (x.r, x.o, x.l);
        end;
    end register_data_rule;

    ----------------------------------------------------------------------------
    -- Release 96: the security model
    ----------------------------------------------------------------------------
    function app_code(p_application_code in varchar2) return varchar2 is
        l_code varchar2(30);
    begin
        -- XXFND_APPLICATION_PKG is installed after this package (09d): called by name
        execute immediate 'begin :r := xxfnd_application_pkg.registered_code(:c); end;' using out l_code, in p_application_code;
        if xxfnd_privilege_pkg.can_change(l_code) = 'N' then
            raise_application_error(-20077, 'You may change only the security of the applications you administer ('
                || l_code || ').');
        end if;
        return l_code;
    end app_code;

    procedure assert_owner(p_what in varchar2, p_key in varchar2, p_row_app in varchar2, p_app in varchar2) is
    begin
        if p_row_app is not null and p_row_app <> p_app then
            xxfnd_error_pkg.raise_error('XXFND_REG_OTHER_APP', apex_t_varchar2(p_what, p_key, p_row_app));
        end if;
    end assert_owner;

    procedure register_dimension(p_application_code  in varchar2,
                                 p_dimension_code    in varchar2,
                                 p_dimension_name    in varchar2,
                                 p_value_source      in varchar2 default 'ORGANIZATION',
                                 p_organization_type in varchar2 default null,
                                 p_lookup_type       in varchar2 default null,
                                 p_description       in varchar2 default null) is
        l_app varchar2(30) := app_code(p_application_code);
        l_row varchar2(30);
    begin
        select max(application_code) into l_row from xxfnd_data_dimensions where dimension_code = upper(p_dimension_code);
        assert_owner('Dimension', upper(p_dimension_code), l_row, l_app);
        merge into xxfnd_data_dimensions t
        using (select upper(p_dimension_code) c from dual) x on (t.dimension_code = x.c)
         when matched then update set t.dimension_name = p_dimension_name, t.value_source = upper(p_value_source),
              t.organization_type = upper(p_organization_type), t.lookup_type = upper(p_lookup_type),
              t.description = nvl(p_description, t.description)
         when not matched then insert (dimension_code, dimension_name, application_code, value_source, organization_type,
                                       lookup_type, description)
              values (x.c, p_dimension_name, l_app, upper(nvl(p_value_source, 'ORGANIZATION')), upper(p_organization_type),
                      upper(p_lookup_type), p_description);
    end register_dimension;

    procedure save_organization(p_application_code  in varchar2,
                                p_organization_type in varchar2,
                                p_organization_code in varchar2,
                                p_organization_name in varchar2,
                                p_parent_code       in varchar2 default null,
                                p_enabled_flag      in varchar2 default 'Y',
                                p_source_type       in varchar2 default 'LOCAL',
                                p_fusion_id         in varchar2 default null) is
        l_app    varchar2(30) := app_code(p_application_code);
        l_row    varchar2(30);
        l_parent number;
    begin
        select max(application_code) into l_row from xxhr_organizations
         where organization_type = upper(p_organization_type) and organization_code = upper(p_organization_code);
        assert_owner('Organization', upper(p_organization_code), l_row, l_app);
        if p_parent_code is not null then
            select max(organization_id) into l_parent from xxhr_organizations
             where organization_type = upper(p_organization_type) and organization_code = upper(p_parent_code);
        end if;
        merge into xxhr_organizations t
        using (select upper(p_organization_type) ty, upper(p_organization_code) c from dual) x
           on (t.organization_type = x.ty and t.organization_code = x.c)
         when matched then update set t.organization_name = p_organization_name, t.parent_organization_id = l_parent,
              t.enabled_flag = nvl(p_enabled_flag, 'Y'), t.source_type = nvl(upper(p_source_type), 'LOCAL'),
              t.fusion_organization_id = nvl(p_fusion_id, t.fusion_organization_id)
         when not matched then insert (organization_type, organization_code, organization_name, parent_organization_id,
                                       application_code, source_type, fusion_organization_id, enabled_flag)
              values (x.ty, x.c, p_organization_name, l_parent, l_app, nvl(upper(p_source_type), 'LOCAL'), p_fusion_id,
                      nvl(p_enabled_flag, 'Y'));
    end save_organization;

    procedure register_data_object(p_application_code in varchar2,
                                   p_data_object_code in varchar2,
                                   p_object_name      in varchar2,
                                   p_table_name       in varchar2,
                                   p_dimension_code   in varchar2 default null,
                                   p_dimension_column in varchar2 default null,
                                   p_owner_column     in varchar2 default null,
                                   p_description      in varchar2 default null,
                                   p_dimension_value_type in varchar2 default null) is
        l_app  varchar2(30) := app_code(p_application_code);
        l_row  varchar2(30);
        l_type varchar2(10) := upper(p_dimension_value_type);
        l_src  varchar2(20);
    begin
        select max(application_code) into l_row from xxfnd_data_objects
         where data_object_code = upper(p_data_object_code) or table_name = upper(p_table_name);
        assert_owner('Data object', upper(p_data_object_code), l_row, l_app);
        -- release 102: an ID column only for a dimension whose values are organizations
        if l_type is not null and l_type not in ('CODE', 'ID') then
            raise_application_error(-20083, 'Dimension value type ' || l_type || ' is not CODE or ID.');
        end if;
        if l_type = 'ID' then
            select max(value_source) into l_src from xxfnd_data_dimensions where dimension_code = upper(p_dimension_code);
            if nvl(l_src, '-') <> 'ORGANIZATION' then
                raise_application_error(-20083, 'Dimension value type ID needs a dimension of organizations ('
                                                || upper(p_dimension_code) || ').');
            end if;
        end if;
        merge into xxfnd_data_objects t
        using (select upper(p_data_object_code) c from dual) x on (t.data_object_code = x.c)
         when matched then update set t.object_name = p_object_name, t.dimension_code = upper(p_dimension_code),
              t.dimension_column = upper(p_dimension_column), t.owner_column = upper(p_owner_column),
              t.description = nvl(p_description, t.description),
              t.dimension_value_type = case when p_dimension_code is null then 'CODE'
                                            else nvl(l_type, t.dimension_value_type) end
         when not matched then insert (data_object_code, object_name, application_code, table_name, dimension_code,
                                       dimension_column, owner_column, description, dimension_value_type)
              values (x.c, p_object_name, l_app, upper(p_table_name), upper(p_dimension_code), upper(p_dimension_column),
                      upper(p_owner_column), p_description,
                      case when p_dimension_code is null then 'CODE' else nvl(l_type, 'CODE') end);
        clear_cache;
    end register_data_object;

    procedure grant_data_access(p_application_code in varchar2, p_role_code in varchar2,
                                p_data_object_code in varchar2, p_access_level in varchar2) is
        l_app  varchar2(30) := app_code(p_application_code);
        l_role varchar2(30);
        l_obj  varchar2(30);
    begin
        select max(application_code) into l_role from xxfnd_roles where role_code = upper(p_role_code);
        select max(application_code) into l_obj from xxfnd_data_objects where data_object_code = upper(p_data_object_code);
        if l_role is null or l_obj is null then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Role or data object',
                                        upper(p_role_code) || ' / ' || upper(p_data_object_code)));
        end if;
        assert_owner('Role', upper(p_role_code), l_role, l_app);
        if l_obj not in (l_app, 'COMMON') then
            raise_application_error(-20079, 'A role may reach only data objects of its own application or COMMON''s.');
        end if;
        if upper(p_access_level) not in ('ALL', 'VALUES', 'OWN') then
            raise_application_error(-20075, 'The level is ALL, VALUES or OWN.');
        end if;
        merge into xxfnd_role_data_access t
        using (select upper(p_role_code) r, upper(p_data_object_code) o, upper(p_access_level) l from dual) x
           on (t.role_code = x.r and t.data_object_code = x.o and t.access_level = x.l)
         when not matched then insert (role_code, data_object_code, access_level) values (x.r, x.o, x.l);
        clear_cache;
    end grant_data_access;

    procedure revoke_data_access(p_application_code in varchar2, p_role_code in varchar2,
                                 p_data_object_code in varchar2, p_access_level in varchar2 default null) is
        l_app  varchar2(30) := app_code(p_application_code);
        l_role varchar2(30);
    begin
        select max(application_code) into l_role from xxfnd_roles where role_code = upper(p_role_code);
        assert_owner('Role', upper(p_role_code), l_role, l_app);
        delete from xxfnd_role_data_access
         where role_code = upper(p_role_code) and data_object_code = upper(p_data_object_code)
           and (p_access_level is null or access_level = upper(p_access_level));
        clear_cache;
    end revoke_data_access;

    procedure set_assignment_values(p_user_role_id     in number,
                                    p_dimension_code   in varchar2,
                                    p_data_object_code in varchar2 default null,
                                    p_values           in varchar2 default null) is
        l_app varchar2(30);
        l_chk varchar2(30);
    begin
        select max(r.application_code) into l_app
          from xxfnd_user_roles ur join xxfnd_roles r on r.role_code = ur.role_code
         where ur.user_role_id = p_user_role_id;
        if l_app is null then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Role assignment', to_char(p_user_role_id)));
        end if;
        l_chk := app_code(l_app);
        delete from xxfnd_assignment_values
         where user_role_id = p_user_role_id and dimension_code = upper(p_dimension_code)
           and nvl(data_object_code, '#') = nvl(upper(p_data_object_code), '#');
        insert into xxfnd_assignment_values (user_role_id, dimension_code, data_object_code, value_code)
        select distinct p_user_role_id, upper(p_dimension_code), upper(p_data_object_code), upper(trim(column_value))
          from table(apex_string.split(p_values, ','))
         where trim(column_value) is not null;
        clear_cache;
    end set_assignment_values;

    function assignment_values(p_user_role_id in number, p_dimension_code in varchar2,
                               p_data_object_code in varchar2 default null) return varchar2 is
        l_list varchar2(4000);
    begin
        select listagg(value_code, ',') within group (order by value_code) into l_list
          from xxfnd_assignment_values
         where user_role_id = p_user_role_id and dimension_code = upper(p_dimension_code)
           and nvl(data_object_code, '#') = nvl(upper(p_data_object_code), '#');
        return l_list;
    end assignment_values;

    procedure unregister_application(p_application_code in varchar2) is
        l_app varchar2(30) := upper(p_application_code);
    begin
        delete from xxfnd_data_objects where application_code = l_app;        -- with its role access (cascade)
        delete from xxfnd_assignment_values
         where dimension_code in (select dimension_code from xxfnd_data_dimensions where application_code = l_app);
        delete from xxfnd_data_dimensions where application_code = l_app;
        update xxhr_organizations set parent_organization_id = null
         where parent_organization_id in (select organization_id from xxhr_organizations where application_code = l_app);
        delete from xxhr_organizations where application_code = l_app;
        clear_cache;
    end unregister_application;

end xxfnd_vpd_pkg;
/
