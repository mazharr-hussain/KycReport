--------------------------------------------------------------------------------
-- C02 Security framework (release R10)
-- Features -> privileges (VIEW / CREATE / MANAGE) -> roles, maintained in the
-- application. Pages map to features, so rebuilding a screen only changes the
-- mapping. Row-level data security: typed rules enforced by one generic VPD
-- policy. Idempotent: safe on install and on every upgrade.
--------------------------------------------------------------------------------
create table if not exists xxfnd_features (
    feature_code           varchar2(30)   not null,
    feature_name           varchar2(240)  not null,
    feature_group          varchar2(30)   not null,
    display_sequence       number         default 100 not null,
    admin_flag             varchar2(1)    default 'N' not null,
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_features_pk primary key (feature_code),
    constraint xxfnd_features_ck1 check (admin_flag in ('Y','N')),
    constraint xxfnd_features_ck2 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_features is 'Application features (one menu entry each). Privileges are granted per feature and action.';

-- release 46: a feature belongs to one application (shared access module)
declare
begin
    xxfnd_ddl_pkg.add_column('XXFND_FEATURES', 'APPLICATION_ID', 'number');
    begin
        execute immediate 'alter table xxfnd_features add constraint xxfnd_features_fk1 foreign key (application_id) references xxfnd_applications (application_id)';
    exception when others then if sqlcode not in (-2275, -2264) then raise; end if;
    end;
end;
/
comment on column xxfnd_features.application_id is 'The application (XXFND_APPLICATIONS) the feature belongs to; its privileges and page mappings follow it.';

create table if not exists xxfnd_privileges (
    privilege_code         varchar2(61)   not null,
    feature_code           varchar2(30)   not null,
    action_code            varchar2(20)   not null,
    privilege_name         varchar2(240)  not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_privileges_pk primary key (privilege_code),
    constraint xxfnd_privileges_uk1 unique (feature_code, action_code),
    constraint xxfnd_privileges_fk1 foreign key (feature_code) references xxfnd_features (feature_code),
    constraint xxfnd_privileges_ck1 check (action_code in ('VIEW','CREATE','MANAGE')),
    constraint xxfnd_privileges_ck2 check (privilege_code = feature_code || '.' || action_code)
);
comment on table xxfnd_privileges is 'VIEW = open and read; CREATE = new records; MANAGE = change existing records (edit, delete, actions).';

create table if not exists xxfnd_feature_pages (
    app_alias              varchar2(255)  not null,
    page_id                number         not null,
    feature_code           varchar2(30)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_feature_pages_pk primary key (app_alias, page_id),
    constraint xxfnd_feature_pages_fk1 foreign key (feature_code) references xxfnd_features (feature_code)
);
comment on table xxfnd_feature_pages is 'Which feature an APEX page belongs to. Page authorization checks the privilege of this feature.';

create table if not exists xxfnd_role_privileges (
    role_code              varchar2(30)   not null,
    privilege_code         varchar2(61)   not null,
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_role_privileges_pk primary key (role_code, privilege_code),
    constraint xxfnd_role_privileges_fk1 foreign key (role_code) references xxfnd_roles (role_code) on delete cascade,
    constraint xxfnd_role_privileges_fk2 foreign key (privilege_code) references xxfnd_privileges (privilege_code) on delete cascade
);
comment on table xxfnd_role_privileges is 'Privileges granted to a role. Maintained on the Roles and Privileges screen.';

create table if not exists xxfnd_data_security_rules (
    rule_id                number generated by default on null as identity,
    role_code              varchar2(30)   not null,
    table_name             varchar2(128)  not null,
    rule_type              varchar2(20)   not null,
    column_name            varchar2(128),
    value_list             varchar2(4000),
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_data_security_rules_pk primary key (rule_id),
    constraint xxfnd_data_security_rules_fk1 foreign key (role_code) references xxfnd_roles (role_code) on delete cascade,
    constraint xxfnd_data_security_rules_ck1 check (rule_type in ('ALL_ROWS','OWN_RECORDS','COLUMN_IN_LIST')),
    constraint xxfnd_data_security_rules_ck2 check (
        (rule_type = 'ALL_ROWS'       and column_name is null     and value_list is null) or
        (rule_type = 'OWN_RECORDS'    and column_name is not null and value_list is null) or
        (rule_type = 'COLUMN_IN_LIST' and column_name is not null and value_list is not null)),
    constraint xxfnd_data_security_rules_ck3 check (enabled_flag in ('Y','N'))
);
comment on table xxfnd_data_security_rules is 'Row access per role and table. A user sees the union of the rows allowed by the enabled rules of their active roles; no rule = no rows (enforced by XXFND_VPD_PKG).';
comment on column xxfnd_data_security_rules.value_list is 'COLUMN_IN_LIST: comma-separated values, e.g. AE,SA.';

begin
    for t in (select table_name from user_tables
               where table_name in ('XXFND_FEATURES','XXFND_PRIVILEGES','XXFND_FEATURE_PAGES',
                                    'XXFND_ROLE_PRIVILEGES','XXFND_DATA_SECURITY_RULES')) loop
        xxfnd_util_pkg.create_who_trigger(t.table_name);
    end loop;
    -- Security configuration is audited like every other setup table.
    xxfnd_audit_pkg.create_audit_trigger('XXFND_ROLE_PRIVILEGES');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_DATA_SECURITY_RULES');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_FEATURE_PAGES');
end;
/

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

end xxfnd_privilege_pkg;
/

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
    procedure end_trusted;
end xxfnd_vpd_pkg;
/

create or replace package body xxfnd_vpd_pkg as
    g_trusted pls_integer := 0;
    c_policy  constant varchar2(30) := 'XXFND_DATA_SECURITY';

    procedure begin_trusted is begin g_trusted := g_trusted + 1; end begin_trusted;
    procedure end_trusted   is begin g_trusted := greatest(g_trusted - 1, 0); end end_trusted;

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

    function policy(p_schema in varchar2, p_object in varchar2) return varchar2 is
        l_user      varchar2(255) := upper(sys_context('APEX$SESSION', 'APP_USER'));
        l_predicate varchar2(32767);
        l_part      varchar2(4000);
    begin
        -- Install scripts, scheduler jobs and developer sessions run without an APEX user. APEX runs
        -- workflow activities and automations in scheduler background jobs (as NOBODY): system work too.
        -- Browser requests through ORDS never run in a scheduler job.
        if l_user is null or g_trusted > 0 or sys_context('USERENV', 'BG_JOB_ID') is not null then
            return null;
        end if;
        for r in (select distinct d.rule_type, d.column_name, d.value_list
                    from xxfnd_data_security_rules d
                    join xxfnd_user_roles_v ur on ur.role_code = d.role_code
                   where ur.user_name = l_user and ur.active_flag = 'Y'
                     and d.enabled_flag = 'Y' and d.table_name = upper(p_object)) loop
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
    end policy;

    procedure apply_policies is
        l_count pls_integer;
    begin
        for t in (select distinct d.table_name from xxfnd_data_security_rules d
                    join user_tables u on u.table_name = d.table_name) loop
            select count(*) into l_count from user_policies
             where object_name = t.table_name and policy_name = c_policy;
            if l_count = 0 then
                dbms_rls.add_policy(
                    object_schema   => sys_context('USERENV', 'CURRENT_SCHEMA'),
                    object_name     => t.table_name,
                    policy_name     => c_policy,
                    function_schema => sys_context('USERENV', 'CURRENT_SCHEMA'),
                    policy_function => 'XXFND_VPD_PKG.POLICY',
                    statement_types => 'SELECT,INSERT,UPDATE,DELETE',
                    update_check    => true,
                    policy_type     => dbms_rls.dynamic);
            end if;
        end loop;
    end apply_policies;

end xxfnd_vpd_pkg;
/
