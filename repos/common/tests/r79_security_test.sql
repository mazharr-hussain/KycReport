-- Release 79 checks (run as XXFUSION): the Security module - package merges, rule assignments to users and roles,
-- VPD per user and per role (access adds up), effective access, allowed values, language, Super Administrator.
-- Runs in an APEX session of a Common Administrator; every change is rolled back at the end.
set serveroutput on feedback off
declare
    l_app   number;
    l_admin varchar2(255);
    l_n     number;
    l_v     varchar2(4000);
    l_user  number;
    l_rule1 number;
    l_rule2 number;
    l_role  varchar2(30) := 'R79_TEST_ROLE';
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
begin
    -- package merges: the old packages are gone, the new procedures exist
    select count(*) into l_n from user_objects where object_name in ('XXFND_SECURITY_PKG', 'XXFND_AUTH_PKG');
    check_(l_n = 0, 'XXFND_SECURITY_PKG and XXFND_AUTH_PKG are dropped');
    select count(*) into l_n from user_procedures
     where (object_name = 'XXFND_USER_PKG' and procedure_name in ('MAP_LOGIN_USER', 'POST_AUTH_LOCAL', 'POST_AUTH_SSO',
                                                                 'AUTHORIZED', 'RENAME_USER', 'BOOTSTRAP_ADMIN', 'ASSIGN_ROLE'))
        or (object_name = 'XXFND_PRIVILEGE_PKG' and procedure_name in ('HAS_ROLE', 'SOD_CONFLICT', 'CAN_VIEW_SENSITIVE'))
        or (object_name = 'XXFND_INTEGRATION_PKG' and procedure_name in ('SYNC_FROM_FUSION', 'SYNC_RUNNING'))
        or (object_name = 'XXFND_VPD_PKG' and procedure_name in ('ASSIGN_RULE', 'UNASSIGN_RULE'));
    check_(l_n = 14, 'merged procedures in XXFND_USER_PKG / PRIVILEGE_PKG / INTEGRATION_PKG / VPD_PKG (' || l_n || ')');
    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');

    -- every rule has an assignment (its old role became the first one)
    select count(*) into l_n from xxfnd_data_security_rules d
     where d.role_code is not null
       and not exists (select 1 from xxfnd_data_rule_assignments a where a.rule_id = d.rule_id and a.role_code = d.role_code);
    check_(l_n = 0, 'each rule''s role is one of its assignments (' || l_n || ' missing)');

    -- an APEX session of a Common Administrator
    apex_util.set_workspace('XXCUS');
    select max(application_id) into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'COMMON';
    select min(column_value) into l_admin
      from table(apex_string.split(xxfnd_workflow_pkg.users_with_privilege('DATA_SECURITY', 'MANAGE'), ','))
     where column_value in (select user_name from xxfnd_user_roles_v where role_code = 'COMMON_ADMIN' and active_flag = 'Y');
    apex_session.create_session(l_app, 1, l_admin);
    xxfnd_vpd_pkg.begin_trusted;

    -- a local user (no APEX account needed for the test), a role and two rules on a protected table
    insert into xxfnd_users (user_name, user_type, full_name, email_address)
    values ('R79_TEST_USER', 'LOCAL', 'R79 Test', 'r79@example.invalid') returning user_id into l_user;
    insert into xxfnd_roles (role_code, application_code, role_name, description)
    select l_role, min(application_code), 'R79 Test Role', 'test' from xxfnd_applications where application_code <> 'COMMON';
    insert into xxfnd_data_security_rules (table_name, rule_type, column_name, value_list, description)
    values ('XXFND_RFIS', 'COLUMN_IN_LIST', 'RFI_STATUS', 'OPEN', 'r79 user rule') returning rule_id into l_rule1;
    insert into xxfnd_data_security_rules (table_name, rule_type, column_name, value_list, description)
    values ('XXFND_RFIS', 'COLUMN_IN_LIST', 'RFI_STATUS', 'ANSWERED', 'r79 role rule') returning rule_id into l_rule2;
    xxfnd_vpd_pkg.end_trusted;

    -- nothing assigned: no rows, no values
    check_(xxfnd_vpd_pkg.allowed_values('XXFND_RFIS', 'RFI_STATUS', 'R79_TEST_USER') = '#NONE', 'no rule: no values');

    -- a rule assigned to the user (from the User screen), and again (nothing changes)
    xxfnd_vpd_pkg.assign_rule(l_rule1, p_user_id => l_user);
    xxfnd_vpd_pkg.assign_rule(l_rule1, p_user_id => l_user);
    select count(*) into l_n from xxfnd_data_rule_assignments where rule_id = l_rule1 and user_id = l_user;
    check_(l_n = 1, 'user rule assigned once (re-assign does nothing)');
    check_(xxfnd_vpd_pkg.allowed_values('XXFND_RFIS', 'RFI_STATUS', 'R79_TEST_USER') = 'OPEN', 'user rule gives its values');

    -- a rule assigned to a role (from the Data access rule screen), the role assigned to the user (from the Role screen)
    xxfnd_vpd_pkg.assign_rule(l_rule2, p_role_code => l_role);
    xxfnd_user_pkg.assign_role(l_user, l_role);
    xxfnd_user_pkg.assign_role(l_user, l_role);
    select count(*) into l_n from xxfnd_user_roles where user_id = l_user and role_code = l_role and enabled_flag = 'Y';
    check_(l_n = 1, 'role assigned once (re-assign does nothing)');
    l_v := xxfnd_vpd_pkg.allowed_values('XXFND_RFIS', 'RFI_STATUS', 'R79_TEST_USER');
    check_(instr(l_v, 'OPEN') > 0 and instr(l_v, 'ANSWERED') > 0, 'access adds up: direct and role rules (' || l_v || ')');
    select count(*) into l_n from xxfnd_effective_access_v where user_id = l_user and table_name = 'XXFND_RFIS';
    check_(l_n = 2, 'effective access lists both rules (' || l_n || ')');
    select count(*) into l_n from xxfnd_effective_access_v
     where user_id = l_user and granted_through = 'Role R79 Test Role';
    check_(l_n = 1, 'effective access names the role a rule comes through');

    -- own records do not hide the list values (a create list uses them)
    xxfnd_vpd_pkg.begin_trusted;
    insert into xxfnd_data_security_rules (table_name, rule_type, column_name, description)
    values ('XXFND_RFIS', 'OWN_RECORDS', 'CREATED_BY', 'r79 own') returning rule_id into l_rule1;
    xxfnd_vpd_pkg.end_trusted;
    xxfnd_vpd_pkg.assign_rule(l_rule1, p_user_id => l_user);
    l_v := xxfnd_vpd_pkg.allowed_values('XXFND_RFIS', 'RFI_STATUS', 'R79_TEST_USER');
    check_(l_v is not null and l_v <> '#NONE', 'own records + list: the list values are offered (' || l_v || ')');

    -- removing the role takes its rule away
    select max(user_role_id) into l_n from xxfnd_user_roles where user_id = l_user and role_code = l_role and enabled_flag = 'Y';
    xxfnd_user_pkg.unassign_role(l_n);
    select count(*) into l_n from xxfnd_effective_access_v where user_id = l_user and granted_through like 'Role%';
    check_(l_n = 0, 'role removed: its rule no longer applies');

    -- a rule created with a role (seeds, scripts) is assigned to that role (trigger)
    xxfnd_vpd_pkg.begin_trusted;
    insert into xxfnd_data_security_rules (role_code, table_name, rule_type, description)
    values (l_role, 'XXFND_COMMUNICATIONS', 'ALL_ROWS', 'r79 seeded') returning rule_id into l_rule2;
    xxfnd_vpd_pkg.end_trusted;
    select count(*) into l_n from xxfnd_data_rule_assignments where rule_id = l_rule2 and role_code = l_role;
    check_(l_n = 1, 'a rule created with a role is assigned to the role');

    -- language preference and Super Administrator
    select language_code into l_v from xxfnd_users where user_id = l_user;
    check_(l_v = 'en', 'a new user''s language is English');
    select count(*) into l_n from xxfnd_role_privileges where role_code = 'SUPER_ADMIN' and privilege_code = 'WORKFLOW_MONITOR.MANAGE';
    check_(l_n = 1, 'Super Administrator holds WORKFLOW_MONITOR.MANAGE (business administrator of every task)');
    select count(*) into l_n from xxfnd_user_roles where role_code = 'SUPER_ADMIN' and enabled_flag = 'Y';   -- a removed grant stays, disabled
    check_(l_n = 0, 'nobody holds Super Administrator after the install (granted from the console only)');

    rollback;
    apex_session.delete_session;
exception
    when others then
        rollback;
        xxfnd_vpd_pkg.end_trusted;
        dbms_output.put_line('FAIL unexpected: ' || sqlerrm);
end;
/
