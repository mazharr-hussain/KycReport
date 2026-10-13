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

-- release 79: a data access rule is assigned to users and to roles (any number of each). The rule's own ROLE_CODE
-- was its only assignment until now: it becomes the rule's first assignment and is no longer required.
begin
    if xxfnd_ddl_pkg.create_table('XXFND_DATA_RULE_ASSIGNMENTS', q'~create table xxfnd_data_rule_assignments (
    assignment_id          number generated by default on null as identity,
    rule_id                number         not null,
    user_id                number,
    role_code              varchar2(30),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_data_rule_assign_pk primary key (assignment_id),
    constraint xxfnd_data_rule_assign_fk1 foreign key (rule_id) references xxfnd_data_security_rules (rule_id) on delete cascade,
    constraint xxfnd_data_rule_assign_fk2 foreign key (user_id) references xxfnd_users (user_id) on delete cascade,
    constraint xxfnd_data_rule_assign_fk3 foreign key (role_code) references xxfnd_roles (role_code) on delete cascade,
    constraint xxfnd_data_rule_assign_ck1 check ((user_id is null and role_code is not null) or (user_id is not null and role_code is null))
)~') then
        xxfnd_ddl_pkg.run(q'~create unique index xxfnd_data_rule_assign_u1 on xxfnd_data_rule_assignments (rule_id, nvl(to_char(user_id), '#'), nvl(role_code, '#'))~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_data_rule_assign_n1 on xxfnd_data_rule_assignments (user_id)~');
        xxfnd_ddl_pkg.run(q'~create index xxfnd_data_rule_assign_n2 on xxfnd_data_rule_assignments (role_code)~');
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_data_rule_assignments is 'Who a data access rule applies to: a user or a role per row. A user sees the rows of every enabled rule assigned to them or to one of their active roles (access adds up).'~');
    end if;
    xxfnd_ddl_pkg.set_nullable('XXFND_DATA_SECURITY_RULES', 'ROLE_CODE');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_data_security_rules.role_code is 'Until release 78 the only role of the rule; since release 79 the rule is assigned in XXFND_DATA_RULE_ASSIGNMENTS (this role became its first assignment).'~');
end;
/

-- each rule's own role is its first assignment (once; a re-run adds nothing)
merge into xxfnd_data_rule_assignments t
using (select rule_id, role_code from xxfnd_data_security_rules where role_code is not null) s
   on (t.rule_id = s.rule_id and t.role_code = s.role_code)
 when not matched then insert (rule_id, role_code, created_by, creation_date, last_updated_by, last_update_date)
                       values (s.rule_id, s.role_code, 'INSTALL', systimestamp, 'INSTALL', systimestamp);
commit;

-- release 79: Effective access - per user, every enabled rule that applies, assigned directly or through an active
-- role (the User screen's Data access tab; access adds up: the widest rule of a table wins)
create or replace view xxfnd_effective_access_v as
select u.user_id,
       u.user_name,
       d.rule_id,
       d.table_name,
       d.rule_type,
       d.column_name,
       d.value_list,
       a.assignment_id,
       case when a.user_id is not null then 'Direct' else 'Role ' || r.role_name end as granted_through,
       a.role_code
  from xxfnd_users u
  join xxfnd_data_rule_assignments a
    on a.user_id = u.user_id
    or a.role_code in (select ur.role_code from xxfnd_user_roles_v ur where ur.user_id = u.user_id and ur.active_flag = 'Y')
  join xxfnd_data_security_rules d on d.rule_id = a.rule_id and d.enabled_flag = 'Y'
  left join xxfnd_roles r on r.role_code = a.role_code;

comment on table xxfnd_effective_access_v is 'The data access rules that apply to each user, directly or through an active role.';

-- a rule created or changed with a role (seeds, scripts) is assigned to that role as well
create or replace trigger xxfnd_data_rules_assign
    after insert or update of role_code on xxfnd_data_security_rules
    for each row
    when (new.role_code is not null)
begin
    merge into xxfnd_data_rule_assignments t
    using (select :new.rule_id rule_id, :new.role_code role_code from dual) s
       on (t.rule_id = s.rule_id and t.role_code = s.role_code)
     when not matched then insert (rule_id, role_code) values (s.rule_id, s.role_code);
end;
/

begin
    for t in (select table_name from user_tables
               where table_name in ('XXFND_FEATURES','XXFND_PRIVILEGES','XXFND_FEATURE_PAGES',
                                    'XXFND_ROLE_PRIVILEGES','XXFND_DATA_SECURITY_RULES',
                                    'XXFND_DATA_RULE_ASSIGNMENTS')) loop
        xxfnd_util_pkg.create_who_trigger(t.table_name);
    end loop;
    -- Security configuration is audited like every other setup table.
    xxfnd_audit_pkg.create_audit_trigger('XXFND_ROLE_PRIVILEGES');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_DATA_SECURITY_RULES');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_DATA_RULE_ASSIGNMENTS');
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

end xxfnd_vpd_pkg;
/
