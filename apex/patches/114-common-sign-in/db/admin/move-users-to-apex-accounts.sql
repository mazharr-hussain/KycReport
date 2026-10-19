--------------------------------------------------------------------------------
-- Users to Oracle APEX accounts (release 99). Run once per environment, after COMMON release 99, connected as XXFUSION,
-- after ADMIN ran: grant apex_administrator_role to xxfusion;
-- Every enabled user of COMMON without an Oracle APEX account (e.g. a user that signed in with a database account)
-- gets one, through XXFND_USER_PKG.ENSURE_APEX_ACCOUNT: the same user name, name and e-mail; roles, data access and
-- history do not change. Passwords cannot be copied from the database: each account gets the first password
-- &default_password, changed at first sign-in - tell the users. The users can also sign in with the company account
-- (SSO): the identity-domain user name or e-mail is matched to the user.
-- A re-run creates only what is missing. The old database users stay; ADMIN locks or drops them afterwards, e.g.
--   alter user "SHUSSAIN@QATARIDIAR.COM" account lock;
--------------------------------------------------------------------------------
set serveroutput on size unlimited
set define on
set verify off
define default_password = 'Welcome#2026'

declare
    l_admin varchar2(255);
    l_app   number;
    l_n     pls_integer := 0;
begin
    apex_util.set_workspace('XXCUS');
    select max(application_id) into l_app from apex_applications where workspace = 'XXCUS' and upper(alias) = 'COMMON';
    select min(column_value) into l_admin
      from table(apex_string.split(xxfnd_workflow_pkg.users_with_privilege('USERS_ACCESS', 'MANAGE'), ','));
    if l_admin is null then
        raise_application_error(-20001, 'No user holds USERS_ACCESS.MANAGE: give the access administrator role first.');
    end if;
    apex_session.create_session(l_app, 1, l_admin);
    for u in (select user_id, user_name from xxfnd_users where enabled_flag = 'Y' order by user_name) loop
        if xxfnd_user_pkg.ensure_apex_account(u.user_id, '&default_password') = 'Y' then
            l_n := l_n + 1;
            dbms_output.put_line('APEX account created: ' || u.user_name);
        end if;
    end loop;
    dbms_output.put_line(l_n || ' account(s) created; first password &default_password (changed at first sign-in).');
    commit;
    apex_session.delete_session;
exception
    when others then
        rollback;
        raise;
end;
/
