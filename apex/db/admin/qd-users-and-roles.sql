--------------------------------------------------------------------------------
-- QD users and roles (release 76). Run once per environment, after COMMON and KYC release 76, connected as XXFUSION
-- (SQL Developer Web: sign in as XXFUSION, or as ADMIN after "alter session set current_schema = XXFUSION").
-- Idempotent: a re-run adds only what is missing; existing users keep their password. Needs COMMON release 76
-- (index XXFND_USER_ROLES_U1 dropped, so several local users can hold the same role).
--
--   1. Requesting Entity roles per department, with data security on the requesting department
--      (XXCMP_REQUESTS.REQUESTING_DEPARTMENT): a user sees and raises requests only for the departments of their roles.
--        REQUESTING_FINANCE      Requesting Entity - Finance
--        REQUESTING_PROCUREMENT  Requesting Entity - Procurement
--      Same privileges as Requester; the RFIs addressed to the user (own records).
--   2. Users (local accounts, first password &default_password - changed at first sign-in):
--        TEST1, TEST2 (QD e-mail), TEST3, TEST4 (external)  Requesting Entity - Finance and - Procurement
--        CFERREIRA   Compliance Officer (Contributor), Compliance Manager (Level 1), Head of Compliance (Level 2)
--        LBUZWAIR    Compliance Officer (Contributor), Compliance Manager (Level 1)
--        SSADASIVAN_DORSCH, HALSAHLAWI  Compliance Officer (Contributor)
--   3. KYC request approval (Approval Setup, KYC_REQUEST): the Compliance review step goes to Level 1
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

    procedure role(p_code varchar2, p_name varchar2, p_dept varchar2) is
        l_r xxfnd_roles%rowtype;
    begin
        select * into l_r from xxfnd_roles where role_code = 'REQUESTER';
        merge into xxfnd_roles t
        using (select p_code role_code from dual) s on (t.role_code = s.role_code)
         when not matched then
            insert (role_code, application_code, role_name, description, view_sensitive_flag, enabled_flag, application_id)
            values (p_code, l_r.application_code, p_name,
                    'Raises KYC requests for ' || p_dept || ' (data security on the requesting department).',
                    l_r.view_sensitive_flag, 'Y', l_r.application_id);
        -- the requester's privileges
        insert into xxfnd_role_privileges (role_code, privilege_code)
        select p_code, rp.privilege_code from xxfnd_role_privileges rp
         where rp.role_code = 'REQUESTER'
           and not exists (select 1 from xxfnd_role_privileges x where x.role_code = p_code and x.privilege_code = rp.privilege_code);
        -- data security: the department's requests; the RFIs addressed to the user (as Requester)
        insert into xxfnd_data_security_rules (role_code, table_name, rule_type, column_name, value_list, description)
        select p_code, 'XXCMP_REQUESTS', 'COLUMN_IN_LIST', 'REQUESTING_DEPARTMENT', p_dept,
               'Requests of the ' || p_dept || ' department.' from dual
         where not exists (select 1 from xxfnd_data_security_rules
                            where role_code = p_code and table_name = 'XXCMP_REQUESTS');
        insert into xxfnd_data_security_rules (role_code, table_name, rule_type, column_name, description)
        select p_code, d.table_name, d.rule_type, d.column_name, d.description
          from xxfnd_data_security_rules d
         where d.role_code = 'REQUESTER' and d.table_name <> 'XXCMP_REQUESTS'
           and not exists (select 1 from xxfnd_data_security_rules x where x.role_code = p_code and x.table_name = d.table_name);
        -- segregation of duties as for the requester
        insert into xxfnd_sod_rules (role_code_1, role_code_2, conflict_scope, description, enabled_flag)
        select case when s.role_code_1 = 'REQUESTER' then p_code else s.role_code_1 end,
               case when s.role_code_2 = 'REQUESTER' then p_code else s.role_code_2 end,
               s.conflict_scope, s.description, s.enabled_flag
          from xxfnd_sod_rules s
         where 'REQUESTER' in (s.role_code_1, s.role_code_2)
           and not exists (select 1 from xxfnd_sod_rules x
                            where x.conflict_scope = s.conflict_scope
                              and x.role_code_1 = case when s.role_code_1 = 'REQUESTER' then p_code else s.role_code_1 end
                              and x.role_code_2 = case when s.role_code_2 = 'REQUESTER' then p_code else s.role_code_2 end);
    end role;

    procedure usr(p_user varchar2, p_name varchar2, p_email varchar2, p_roles varchar2) is
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
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            insert into xxfnd_user_roles (user_id, role_code)
            select l_id, r.role_code from dual
             where not exists (select 1 from xxfnd_user_roles
                                where user_id = l_id and role_code = r.role_code and end_date_active is null);
        end loop;
    end usr;
begin
    apex_util.set_workspace('XXCUS');
    select max(application_id) into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'COMMON';
    select min(column_value) into l_admin
      from table(apex_string.split(xxfnd_task_pkg.users_with_privilege('USERS_ACCESS', 'MANAGE'), ','));
    if l_admin is null then
        raise_application_error(-20001, 'No user holds USERS_ACCESS.MANAGE: give the access administrator role first.');
    end if;
    apex_session.create_session(l_app, 1, l_admin);
    xxfnd_vpd_pkg.begin_trusted;

    role('REQUESTING_FINANCE', 'Requesting Entity - Finance', 'FINANCE');
    role('REQUESTING_PROCUREMENT', 'Requesting Entity - Procurement', 'PROCUREMENT');

    usr('TEST1', 'QD Requesting Entity 1', 'test1@qataridiar.com', 'REQUESTING_FINANCE,REQUESTING_PROCUREMENT');
    usr('TEST2', 'QD Requesting Entity 2', 'test2@qataridiar.com', 'REQUESTING_FINANCE,REQUESTING_PROCUREMENT');
    usr('TEST3', 'External Requesting Entity 1', null, 'REQUESTING_FINANCE,REQUESTING_PROCUREMENT');
    usr('TEST4', 'External Requesting Entity 2', null, 'REQUESTING_FINANCE,REQUESTING_PROCUREMENT');
    usr('CFERREIRA', 'Carlos Ferreira', 'cferreira@qataridiar.com', 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE');
    usr('LBUZWAIR', 'Latifa Buzwair', 'lbuzwair@qataridiar.com', 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER');
    usr('SSADASIVAN_DORSCH', 'Sandeep Sadasivan', 'ssadasivan_dorsch@qataridiar.com', 'COMPLIANCE_OFFICER');
    usr('HALSAHLAWI', 'Hissa AlSahlawi', 'halsahlawi@qataridiar.com', 'COMPLIANCE_OFFICER');

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
