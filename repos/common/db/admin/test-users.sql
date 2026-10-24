--------------------------------------------------------------------------------
-- Test users for live validation (COMMON, from release 106). Run as ADMIN in SQL Developer Web (or as XXFUSION
-- without the first line), after COMMON (and, for the application users, the application) is installed.
-- Local users through COMMON's user routines, default password Welcome#2026, NOT changed at first sign-in.
-- A user whose role does not exist in this database (its application is not installed) is skipped with a message.
-- A re-run keeps existing users, adds only missing roles and a missing APEX account, and sets the password again.
--
--   COMMON
--     TCOM_ADMIN      Common Administrator (COMMON_ADMIN): every COMMON screen, every application's setup
--     TALL_ACCESS     Full access: COMMON_ADMIN and every enabled role of every registered application
--                     (department-scoped roles with every department)
--   KYC
--     TKYC_REQ1       Requesting user, Finance       (REQUESTING_ENTITY_1, department FINANCE)
--     TKYC_REQ2       Requesting user, Procurement   (REQUESTING_ENTITY_2, department PROCUREMENT)
--     TKYC_APPROVER   Request approver and case assignment (COMPLIANCE_OFFICER, COMPLIANCE_MANAGER: approves the
--                     request whichever role the KYC_REQUEST rule names, assigns the case)
--     TKYC_CONTRIB1   Contributor working on cases   (COMPLIANCE_OFFICER)
--     TKYC_CONTRIB2   Contributor working on cases   (COMPLIANCE_OFFICER)
--     TKYC_L1         Case approval level 1          (COMPLIANCE_MANAGER)
--     TKYC_L2         Case approval level 2          (HEAD_OF_COMPLIANCE)
--     TKYC_ADMIN      KYC administrator              (SYSTEM_ADMIN, KYC_ADMIN)
--------------------------------------------------------------------------------
alter session set current_schema = XXFUSION;
set serveroutput on size unlimited
set define off

declare
    c_password constant varchar2(30) := 'Welcome#2026';
    type t_names is table of varchar2(255) index by pls_integer;
    l_users t_names;
    l_full  t_names;
    l_admin varchar2(255);
    l_app   number;
    l_all   varchar2(32767);

    -- the APEX account of a test user: its name, the password, not changed at first sign-in, unlocked. Set after the
    -- APEX session (APEX_UTIL.FETCH_USER is refused inside it); a test user has nothing else to keep.
    procedure keep_password(p_user in varchar2, p_name in varchar2) is
        l_id number := apex_util.get_user_id(p_user);
    begin
        if l_id is null then
            dbms_output.put_line('no APEX account for ' || p_user);
            return;
        end if;
        apex_util.edit_user(p_user_id => l_id, p_user_name => p_user,
            p_first_name => regexp_substr(p_name, '^\S+'), p_last_name => regexp_replace(p_name, '^\S+\s*'),
            p_web_password => c_password, p_new_password => c_password,
            p_account_locked => 'N', p_failed_access_attempts => 0,
            p_change_password_on_first_use => 'N', p_first_password_use_occurred => 'Y');
    end keep_password;

    -- department values of a role assignment: the department organization codes (the data access view turns them into
    -- the IDs the requests hold); all departments when null
    function departments(p_codes in varchar2) return varchar2 is
        l_list varchar2(32767);
    begin
        select listagg(organization_code, ',') within group (order by organization_code) into l_list
          from xxhr_organizations
         where organization_type = 'DEPARTMENT'
           and (p_codes is null
                or organization_code in (select upper(trim(column_value)) from table(apex_string.split(p_codes, ','))));
        return l_list;
    end departments;

    -- P_ROLES: comma-separated; ROLE:DEPT1|DEPT2 gives the assignment those departments (ROLE:* every department)
    procedure usr(p_user in varchar2, p_name in varchar2, p_roles in varchar2) is
        l_id   number;
        l_ur   number;
        l_n    pls_integer;
        l_role varchar2(60);
        l_dept varchar2(4000);
    begin
        select max(user_id) into l_id from xxfnd_users where user_name = p_user;
        if l_id is null then
            l_id := xxfnd_user_pkg.create_local_user(p_user, p_name, null, c_password);
            dbms_output.put_line('created  ' || p_user);
        else
            dbms_output.put_line('exists   ' || p_user);
            if xxfnd_user_pkg.ensure_apex_account(l_id, c_password) = 'Y' then
                dbms_output.put_line('         APEX account created');
            end if;
        end if;
        l_users(l_users.count + 1) := p_user;
        l_full(l_users.count) := p_name;
        for r in (select trim(column_value) item from table(apex_string.split(p_roles, ','))
                   where trim(column_value) is not null) loop
            l_role := upper(regexp_substr(r.item, '^[^:]+'));
            l_dept := regexp_substr(r.item, ':(.*)$', 1, 1, null, 1);
            select count(*) into l_n from xxfnd_roles where role_code = l_role and enabled_flag = 'Y';
            if l_n = 0 then
                dbms_output.put_line('         skipped ' || l_role || ' (not in this database)');
                continue;
            end if;
            select count(*) into l_n from xxfnd_user_roles
             where user_id = l_id and role_code = l_role and enabled_flag = 'Y';
            if l_n = 0 then
                xxfnd_user_pkg.assign_role(l_id, l_role);
            end if;
            if l_dept is not null then
                select max(user_role_id) into l_ur from xxfnd_user_roles
                 where user_id = l_id and role_code = l_role and enabled_flag = 'Y';
                xxfnd_vpd_pkg.set_assignment_values(l_ur, 'DEPARTMENT', null,
                    departments(case when l_dept = '*' then null else replace(l_dept, '|', ',') end));
            end if;
            dbms_output.put_line('         ' || l_role || nvl2(l_dept, ' (' || l_dept || ')', ''));
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
    apex_session.create_session(l_app, 1, l_admin);   -- an access administrator, as on the User page
    xxfnd_vpd_pkg.begin_trusted;

    -- COMMON
    usr('TCOM_ADMIN', 'Test Common Admin', 'COMMON_ADMIN');
    -- full access: COMMON_ADMIN and every enabled role of every registered application; a role that reaches its
    -- requests by department (data access VALUES) gets every department
    select listagg(r.role_code
                   || case when exists (select 1 from xxfnd_role_data_access a
                                         where a.role_code = r.role_code and a.access_level = 'VALUES')
                           then ':*' end, ',') within group (order by r.role_code)
      into l_all
      from xxfnd_roles r
     where r.enabled_flag = 'Y' and r.role_code <> 'COMMON_ADMIN';
    usr('TALL_ACCESS', 'Test Full Access', 'COMMON_ADMIN,' || l_all);

    -- KYC (skipped role by role when KYC is not installed)
    usr('TKYC_REQ1',     'Test Requester Finance',     'REQUESTING_ENTITY_1:FINANCE');
    usr('TKYC_REQ2',     'Test Requester Procurement', 'REQUESTING_ENTITY_2:PROCUREMENT');
    usr('TKYC_APPROVER', 'Test Request Approver',      'COMPLIANCE_OFFICER,COMPLIANCE_MANAGER');
    usr('TKYC_CONTRIB1', 'Test Contributor One',       'COMPLIANCE_OFFICER');
    usr('TKYC_CONTRIB2', 'Test Contributor Two',       'COMPLIANCE_OFFICER');
    usr('TKYC_L1',       'Test Case Approver L1',      'COMPLIANCE_MANAGER');
    usr('TKYC_L2',       'Test Case Approver L2',      'HEAD_OF_COMPLIANCE');
    usr('TKYC_ADMIN',    'Test KYC Admin',             'SYSTEM_ADMIN,KYC_ADMIN');

    xxfnd_vpd_pkg.clear_cache;
    xxfnd_vpd_pkg.end_trusted;
    commit;
    apex_session.delete_session;

    -- the passwords, outside the APEX session: the default password, not changed at first sign-in
    apex_util.set_workspace('XXCUS');
    for i in 1 .. l_users.count loop
        keep_password(l_users(i), l_full(i));
    end loop;
    commit;
    dbms_output.put_line('password ' || c_password || ' (not changed at first sign-in) for every test user above');
exception
    when others then
        rollback;
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
