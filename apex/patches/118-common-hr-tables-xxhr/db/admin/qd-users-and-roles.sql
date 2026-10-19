--------------------------------------------------------------------------------
-- QD users and roles (release 76; release 79: department access per user; release 98: the security model of COMMON 96).
-- Run once per environment, after COMMON release 98 (and KYC installed), connected as XXFUSION
-- (SQL Developer Web: sign in as XXFUSION, or as ADMIN after "alter session set current_schema = XXFUSION").
-- Only COMMON routines are called (as on the Users and Roles screens), in an APEX session of a user who holds
-- USERS_ACCESS.MANAGE. A re-run gives the same result.
--
--   1. Roles (KYC): Requesting Entity1 (Finance) and Requesting Entity2 (Procurement). Each holds the Requester role
--      inside it (same privileges) and reaches KYC Requests by the values of the assignment (Department).
--   2. Users (local accounts, first password &default_password - changed at first sign-in). A user that exists (the
--      format before release 96: Requester with department rules) is recreated: every role it holds is ended (the
--      rows stay for the audit; COMMON has no routine to delete a user and its requests and tasks keep its name), its
--      password is set to the first password again, then it gets the roles below.
--        TEST1  QD Requesting Entity 1        Requesting Entity1, Department = Finance
--        TEST2  QD Requesting Entity 2        Requesting Entity2, Department = Procurement
--        TEST3  External Requesting Entity 1  Requesting Entity1, Department = Finance
--        TEST4  External Requesting Entity 2  Requesting Entity2, Department = Procurement
--        CFERREIRA          Contributor (Compliance Officer), Level 1 (Compliance Manager), Level 2 (Head of Compliance)
--        LBUZWAIR           Contributor, Level 1
--        SSADASIVAN_DORSCH  Contributor
--        HALSAHLAWI         Contributor
-- Release 98: the one-time changes of release 79 (Contributor privileges, request approval by Level 1) are no longer
-- in this script; they were direct changes and are already applied where the release 79 script ran.
--------------------------------------------------------------------------------
set serveroutput on size unlimited
set define on
set verify off
define default_password = 'Welcome#2026'

declare
    l_admin varchar2(255);
    l_app   number;
    l_n     pls_integer;

    procedure entity_role(p_role varchar2, p_name varchar2, p_dept varchar2) is
    begin
        xxfnd_privilege_pkg.register_role('KYC', p_role, p_name,
            'Release 98: a requesting entity (' || initcap(p_dept) || '): the Requester role, requests of the department '
            || 'given on the assignment.');
        xxfnd_privilege_pkg.add_role_member('KYC', p_role, 'REQUESTER');
        xxfnd_vpd_pkg.grant_data_access('KYC', p_role, 'XXCMP_REQUESTS', 'VALUES');
        dbms_output.put_line('role    ' || p_role);
    end entity_role;

    procedure usr(p_user varchar2, p_name varchar2, p_email varchar2, p_roles varchar2, p_dept varchar2 default null) is
        l_id number;
        l_ur number;
    begin
        select max(user_id) into l_id from xxfnd_users where user_name = upper(p_user);
        if l_id is null then
            l_id := xxfnd_user_pkg.create_local_user(p_user, p_name, p_email, '&default_password');
            dbms_output.put_line('created   ' || upper(p_user));
        else
            -- recreate: the old roles end, the first password again
            for r in (select user_role_id from xxfnd_user_roles where user_id = l_id and enabled_flag = 'Y') loop
                xxfnd_user_pkg.unassign_role(r.user_role_id);
            end loop;
            if xxfnd_user_pkg.is_local(upper(p_user)) = 'Y' then
                xxfnd_user_pkg.reset_password(l_id, '&default_password');
            end if;
            dbms_output.put_line('recreated ' || upper(p_user));
        end if;
        for r in (select column_value role_code from table(apex_string.split(p_roles, ','))) loop
            xxfnd_user_pkg.assign_role(l_id, r.role_code);
            if p_dept is not null then
                select max(user_role_id) into l_ur from xxfnd_user_roles
                 where user_id = l_id and role_code = r.role_code and enabled_flag = 'Y';
                xxfnd_vpd_pkg.set_assignment_values(l_ur, 'DEPARTMENT', null, p_dept);
            end if;
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
    select count(*) into l_n from xxfnd_data_objects where data_object_code = 'XXCMP_REQUESTS' and dimension_code = 'DEPARTMENT';
    if l_n = 0 then
        raise_application_error(-20002, 'KYC Requests is not a data object on Department: install COMMON release 96 first.');
    end if;
    apex_session.create_session(l_app, 1, l_admin);
    xxfnd_vpd_pkg.begin_trusted;

    -- the two entities (departments)
    for d in (select 'FINANCE' c, 'Finance' n from dual union all select 'PROCUREMENT', 'Procurement' from dual) loop
        select count(*) into l_n from xxhr_organizations where organization_type = 'DEPARTMENT' and organization_code = d.c;
        if l_n = 0 then
            xxfnd_vpd_pkg.save_organization('COMMON', 'DEPARTMENT', d.c, d.n);
        end if;
    end loop;
    entity_role('REQUESTING_ENTITY_1', 'Requesting Entity1', 'FINANCE');
    entity_role('REQUESTING_ENTITY_2', 'Requesting Entity2', 'PROCUREMENT');

    usr('TEST1', 'QD Requesting Entity 1', 'test1@qataridiar.com', 'REQUESTING_ENTITY_1', 'FINANCE');
    usr('TEST2', 'QD Requesting Entity 2', 'test2@qataridiar.com', 'REQUESTING_ENTITY_2', 'PROCUREMENT');
    usr('TEST3', 'External Requesting Entity 1', null, 'REQUESTING_ENTITY_1', 'FINANCE');
    usr('TEST4', 'External Requesting Entity 2', null, 'REQUESTING_ENTITY_2', 'PROCUREMENT');
    usr('CFERREIRA', 'Carlos Ferreira', 'cferreira@qataridiar.com', 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER,HEAD_OF_COMPLIANCE');
    usr('LBUZWAIR', 'Latifa Buzwair', 'lbuzwair@qataridiar.com', 'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER');
    usr('SSADASIVAN_DORSCH', 'Sandeep Sadasivan', 'ssadasivan_dorsch@qataridiar.com', 'COMPLIANCE_OFFICER');
    usr('HALSAHLAWI', 'Hissa AlSahlawi', 'halsahlawi@qataridiar.com', 'COMPLIANCE_OFFICER');

    xxfnd_vpd_pkg.clear_cache;
    xxfnd_vpd_pkg.end_trusted;
    commit;
    apex_session.delete_session;
exception
    when others then
        rollback;
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
