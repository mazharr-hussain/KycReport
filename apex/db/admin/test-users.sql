--------------------------------------------------------------------------------
-- Three KYC test users (release 101). Run as ADMIN in SQL Developer Web (or as XXFUSION without the first line).
-- Local users through COMMON's user routines, password Welcome#2026, NOT changed at first sign-in:
--   TESTREQ      Requester - role Requesting Entity1, department Finance
--   TESTCONTRIB  Contributor - role Compliance Officer
--   TESTL1       Level 1 approver - role Compliance Manager
-- A re-run keeps existing users and only adds missing roles and a missing APEX account; the password is set again.
--------------------------------------------------------------------------------
alter session set current_schema = XXFUSION;
set serveroutput on size unlimited
set define off

declare
    c_password constant varchar2(30) := 'Welcome#2026';
    l_admin varchar2(255);
    l_app   number;

    -- the APEX account of a test user: its name, the password, not changed at first sign-in, unlocked. Set after the
    -- APEX session (APEX_UTIL.FETCH_USER is refused inside it); a test user has nothing else to keep (no e-mail, no
    -- developer or administrator rights), so EDIT_USER is given every attribute it needs.
    procedure keep_password(p_user in varchar2, p_name in varchar2) is
        l_id number := apex_util.get_user_id(p_user);
    begin
        if l_id is null then
            raise_application_error(-20001, p_user || ' has no APEX account in workspace XXCUS.');
        end if;
        apex_util.edit_user(p_user_id => l_id, p_user_name => p_user,
            p_first_name => regexp_substr(p_name, '^\S+'), p_last_name => regexp_replace(p_name, '^\S+\s*'),
            p_web_password => c_password, p_new_password => c_password,
            p_account_locked => 'N', p_failed_access_attempts => 0,
            p_change_password_on_first_use => 'N', p_first_password_use_occurred => 'Y');
    end keep_password;

    procedure usr(p_user varchar2, p_name varchar2, p_role varchar2, p_dept varchar2 default null) is
        l_id number;
        l_ur number;
    begin
        select max(user_id) into l_id from xxfnd_users where user_name = p_user;
        if l_id is null then
            l_id := xxfnd_user_pkg.create_local_user(p_user, p_name, null, c_password);
            dbms_output.put_line('created  ' || p_user);
        else
            dbms_output.put_line('exists   ' || p_user);
            -- a user kept from an earlier attempt may have no APEX account yet (COMMON's routine creates it)
            if xxfnd_user_pkg.ensure_apex_account(l_id, c_password) = 'Y' then
                dbms_output.put_line('         APEX account created');
            end if;
        end if;
        xxfnd_user_pkg.assign_role(l_id, p_role);
        if p_dept is not null then
            select max(user_role_id) into l_ur from xxfnd_user_roles
             where user_id = l_id and role_code = p_role and enabled_flag = 'Y';
            xxfnd_vpd_pkg.set_assignment_values(l_ur, 'DEPARTMENT', null, p_dept);
        end if;
        dbms_output.put_line('         ' || p_role || nvl2(p_dept, ' (' || p_dept || ')', ''));
    end usr;
begin
    apex_util.set_workspace('XXCUS');
    select max(application_id) into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'COMMON';
    select min(column_value) into l_admin
      from table(apex_string.split(xxfnd_workflow_pkg.users_with_privilege('USERS_ACCESS', 'MANAGE'), ','));
    apex_session.create_session(l_app, 1, l_admin);   -- an access administrator, as on the User page
    xxfnd_vpd_pkg.begin_trusted;

    usr('TESTREQ',     'Test Requester',   'REQUESTING_ENTITY_1', 'FINANCE');
    usr('TESTCONTRIB', 'Test Contributor', 'COMPLIANCE_OFFICER');
    usr('TESTL1',      'Test Level 1',     'COMPLIANCE_MANAGER');

    xxfnd_vpd_pkg.clear_cache;
    xxfnd_vpd_pkg.end_trusted;
    commit;
    apex_session.delete_session;

    -- the passwords, outside the APEX session
    apex_util.set_workspace('XXCUS');
    keep_password('TESTREQ',     'Test Requester');
    keep_password('TESTCONTRIB', 'Test Contributor');
    keep_password('TESTL1',      'Test Level 1');
    commit;
    dbms_output.put_line('password ' || c_password || ' (not changed at first sign-in) for TESTREQ, TESTCONTRIB, TESTL1');
exception
    when others then
        rollback;
        xxfnd_vpd_pkg.end_trusted;
        raise;
end;
/
