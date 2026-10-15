--------------------------------------------------------------------------------
-- QD users and roles (release 76; release 79: department access per user). Run once per environment, after COMMON
-- release 79 and KYC release 76, connected as XXFUSION
-- (SQL Developer Web: sign in as XXFUSION, or as ADMIN after "alter session set current_schema = XXFUSION").
-- Idempotent: a re-run adds only what is missing; existing users keep their password. Needs COMMON release 76
-- (index XXFND_USER_ROLES_U1 dropped, so several local users can hold the same role).
--
--   1. Release 79: one Requester role; the department is a data access rule assigned to each user
--      (XXCMP_REQUESTS.REQUESTING_DEPARTMENT in FINANCE / PROCUREMENT): a user sees and raises requests only for the
--      departments of their rules. The release 76 roles REQUESTING_FINANCE and REQUESTING_PROCUREMENT are disabled
--      (kept, not deleted).
--   2. Users (local accounts, first password &default_password - changed at first sign-in):
--        TEST1, TEST2 (QD e-mail), TEST3, TEST4 (external)  Requester, departments Finance and Procurement
--        CFERREIRA   Compliance Officer (Contributor), Compliance Manager (Level 1), Head of Compliance (Level 2)
--        LBUZWAIR    Compliance Officer (Contributor), Compliance Manager (Level 1)
--        SSADASIVAN_DORSCH, HALSAHLAWI  Compliance Officer (Contributor)
--   3. Contributors (Compliance Officer) lose Case Assignment and KYC Requests - Create (Level 1 assigns cases and
--      raises requests on behalf of any department).
--   4. KYC request approval (Approval Setup, KYC_REQUEST): the Compliance review step goes to Level 1
--      (Compliance Manager) instead of the Compliance Officer.
-- The users are created through XXFND_USER_PKG (as on the Users screen) in an APEX session of a user who holds
-- USERS_ACCESS.MANAGE.
--------------------------------------------------------------------------------
set serveroutput on size unlimited
set define on
set verify off
define default_password = 'Welcome#2026'

declare
    l_admin varchar2(255);
    l_app   number;
    l_id    number;

    -- release 79: a department rule (not tied to a role), assigned to users
    function dept_rule(p_dept varchar2) return number is
        l_rule number;
    begin
        select max(rule_id) into l_rule from xxfnd_data_security_rules
         where role_code is null and table_name = 'XXCMP_REQUESTS' and rule_type = 'COLUMN_IN_LIST'
           and column_name = 'REQUESTING_DEPARTMENT' and value_list = p_dept;
        if l_rule is null then
            insert into xxfnd_data_security_rules (table_name, rule_type, column_name, value_list, description)
            values ('XXCMP_REQUESTS', 'COLUMN_IN_LIST', 'REQUESTING_DEPARTMENT', p_dept,
                    'Requests of the ' || p_dept || ' department.')
            returning rule_id into l_rule;
        end if;
        return l_rule;
    end dept_rule;

    procedure usr(p_user varchar2, p_name varchar2, p_email varchar2, p_roles varchar2, p_depts varchar2 default null) is
    begin
        select max(user_id) into l_id from xxfnd_users where user_name = upper(p_user);
        if l_id is null and apex_util.get_user_id(upper(p_user)) is not null then
            -- the APEX account is there (an earlier run stopped half-way: APEX commits the account): the user record only
            insert into xxfnd_users (user_name, user_type, full_name, email_address)
            values (upper(p_user), 'LOCAL', p_name, lower(p_email)) returning user_id into l_id;
            dbms_output.put_line('linked  ' || upper(p_user));
        elsif l_id is null then
            l_id := xxfnd_user_pkg.create_local_user(p_user, p_name, p_email, '&default_password');
            dbms_output.put_line('created ' || upper(p_user));
        else
            dbms_output.put_line('exists  ' || upper(p_user));
        end if;
        -- release 79: through the Security packages (the same calls as the User screen)
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            xxfnd_user_pkg.assign_role(l_id, r.role_code);
        end loop;
        for d in (select column_value dept from table(apex_string.split(p_depts, ',')) where column_value is not null) loop
            xxfnd_vpd_pkg.assign_rule(dept_rule(d.dept), p_user_id => l_id);
        end loop;
    end usr;
begin
    apex_util.set_workspace('XXCUS');
    select max(application_id) into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'COMMON';
    select min(column_value) into l_admin
      from table(apex_string.split(xxfnd_workflow_pkg.users_with_privilege('USERS_ACCESS', 'MANAGE'), ','));
    if l_admin is null then
        raise_application_error(-20001, 'No user holds USERS_ACCESS.MANAGE: give the access administrator role first.');
    end if;
    apex_session.create_session(l_app, 1, l_admin);
    xxfnd_vpd_pkg.begin_trusted;

    -- release 79: the department roles of release 76 are no longer used (kept, disabled)
    update xxfnd_roles set enabled_flag = 'N'
     where role_code in ('REQUESTING_FINANCE', 'REQUESTING_PROCUREMENT') and enabled_flag = 'Y';
    dbms_output.put_line('department roles disabled: ' || sql%rowcount);

    usr('TEST1', 'QD Requesting Entity 1', 'test1@qataridiar.com', 'REQUESTER', 'FINANCE,PROCUREMENT');
    usr('TEST2', 'QD Requesting Entity 2', 'test2@qataridiar.com', 'REQUESTER', 'FINANCE,PROCUREMENT');
    usr('TEST3', 'External Requesting Entity 1', null, 'REQUESTER', 'FINANCE,PROCUREMENT');
    usr('TEST4', 'External Requesting Entity 2', null, 'REQUESTER', 'FINANCE,PROCUREMENT');
    usr('CFERREIRA', 'Carlos Ferreira', 'cferreira@qataridiar.com', 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE');
    usr('LBUZWAIR', 'Latifa Buzwair', 'lbuzwair@qataridiar.com', 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER');
    usr('SSADASIVAN_DORSCH', 'Sandeep Sadasivan', 'ssadasivan_dorsch@qataridiar.com', 'COMPLIANCE_OFFICER');
    usr('HALSAHLAWI', 'Hissa AlSahlawi', 'halsahlawi@qataridiar.com', 'COMPLIANCE_OFFICER');

    -- Contributors (Compliance Officer) neither assign cases nor raise requests: Level 1 does (a privilege can be given
    -- back to a role or user in the console later; upgrades do not re-grant it)
    delete from xxfnd_role_privileges
     where role_code = 'COMPLIANCE_OFFICER' and privilege_code in ('CASE_ASSIGNMENT.MANAGE', 'KYC_REQUESTS.CREATE');
    dbms_output.put_line('privileges removed from the Contributor role: ' || sql%rowcount);

    -- request approval by Level 1 (Compliance Manager)
    update xxfnd_approval_rule_steps s
       set s.role_code = 'COMPLIANCE_MANAGER'
     where s.approver_type = 'ROLE' and s.role_code = 'COMPLIANCE_OFFICER'
       and s.rule_id in (select rule_id from xxfnd_approval_rules where approval_type_code = 'KYC_REQUEST');
    dbms_output.put_line('request approval steps moved to Level 1: ' || sql%rowcount);

    xxfnd_vpd_pkg.end_trusted;
    commit;
    xxfnd_vpd_pkg.apply_policies;
    apex_session.delete_session;
exception
    when others then
        rollback;
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
