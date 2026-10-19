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

    -- Release 96: roles inside roles. P_MEMBER_ROLE_CODE (a role of the same application or a COMMON role) becomes
    -- part of P_ROLE_CODE (a role of P_APPLICATION_CODE); a loop is refused (ORA-20076). The caller administers the
    -- application (XXFND_APPLICATION_PKG.CAN_ADMINISTER; ORA-20077 otherwise).
    procedure add_role_member(p_application_code in varchar2, p_role_code in varchar2, p_member_role_code in varchar2);
    procedure remove_role_member(p_application_code in varchar2, p_role_code in varchar2, p_member_role_code in varchar2);
    -- Y when the user may change the security rows of the application (COMMON administrator: every application).
    function can_change(p_application_code in varchar2) return varchar2;
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
          from xxfnd_user_role_tree_v ur
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
          from xxfnd_user_role_tree_v ur
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
          from xxfnd_user_role_tree_v ur
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
          from xxfnd_user_role_tree_v v
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
          from xxfnd_user_role_tree_v v
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
          from xxfnd_user_role_tree_v v
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
          join xxfnd_user_role_tree_v v
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

    ----------------------------------------------------------------------------
    -- Release 96: roles inside roles
    ----------------------------------------------------------------------------
    -- XXFND_VPD_PKG is created after this package (below): called by name
    procedure vpd_clear is
    begin
        execute immediate 'begin xxfnd_vpd_pkg.clear_cache; end;';
    end vpd_clear;

    function vpd_trusted return boolean is
        l_t varchar2(1);
    begin
        execute immediate q'[begin :t := case when xxfnd_vpd_pkg.is_trusted then 'Y' else 'N' end; end;]' using out l_t;
        return l_t = 'Y';
    end vpd_trusted;

    function can_change(p_application_code in varchar2) return varchar2 is
        l_y varchar2(1);
    begin
        if not xxfnd_util_pkg.in_apex_session or vpd_trusted then
            return 'Y';     -- install, registration and server code (checked by their own callers)
        end if;
        -- the administration scope is XXFND_APPLICATION_PKG's, installed after this package (09d): called by name
        execute immediate 'begin :y := xxfnd_application_pkg.can_administer(:a); end;'
            using out l_y, in upper(p_application_code);
        return nvl(l_y, 'N');
    end can_change;

    procedure check_change(p_application_code in varchar2) is
    begin
        if can_change(p_application_code) = 'N' then
            raise_application_error(-20077, 'You may change only the security of the applications you administer ('
                || upper(p_application_code) || ').');
        end if;
    end check_change;

    procedure add_role_member(p_application_code in varchar2, p_role_code in varchar2, p_member_role_code in varchar2) is
        l_role   xxfnd_roles.application_code%type;
        l_member xxfnd_roles.application_code%type;
        l_n      pls_integer;
    begin
        select max(application_code) into l_role from xxfnd_roles where role_code = upper(p_role_code);
        select max(application_code) into l_member from xxfnd_roles where role_code = upper(p_member_role_code);
        if l_role is null or l_member is null then
            xxfnd_error_pkg.raise_error('XXFND_REG_UNKNOWN', apex_t_varchar2('Role', upper(nvl(l_role, p_member_role_code))));
        end if;
        if l_role <> upper(p_application_code) then
            raise_application_error(-20078, 'Role ' || upper(p_role_code) || ' belongs to ' || l_role || '.');
        end if;
        if l_member not in (l_role, 'COMMON') then
            raise_application_error(-20079, 'A role may contain only roles of its own application or COMMON roles.');
        end if;
        check_change(l_role);
        -- no loop: the role may not already be inside the member (at any depth)
        select count(*) into l_n from xxfnd_role_members
         where member_role_code = upper(p_role_code)
         start with role_code = upper(p_member_role_code)
         connect by nocycle prior member_role_code = role_code;
        if l_n > 0 or upper(p_role_code) = upper(p_member_role_code) then
            raise_application_error(-20076, 'Role ' || upper(p_member_role_code) || ' already contains '
                || upper(p_role_code) || ': a role cannot contain itself.');
        end if;
        merge into xxfnd_role_members t
        using (select upper(p_role_code) r, upper(p_member_role_code) m from dual) s
           on (t.role_code = s.r and t.member_role_code = s.m)
         when not matched then insert (role_code, member_role_code) values (s.r, s.m);
        xxfnd_vpd_pkg.clear_cache;
    end add_role_member;

    procedure remove_role_member(p_application_code in varchar2, p_role_code in varchar2, p_member_role_code in varchar2) is
        l_role xxfnd_roles.application_code%type;
    begin
        select max(application_code) into l_role from xxfnd_roles where role_code = upper(p_role_code);
        if l_role <> upper(p_application_code) then
            raise_application_error(-20078, 'Role ' || upper(p_role_code) || ' belongs to ' || l_role || '.');
        end if;
        check_change(l_role);
        delete from xxfnd_role_members where role_code = upper(p_role_code) and member_role_code = upper(p_member_role_code);
        xxfnd_vpd_pkg.clear_cache;
    end remove_role_member;

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
