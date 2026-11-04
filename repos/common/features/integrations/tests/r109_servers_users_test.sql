-- COMMON 109: servers read the OCI region / namespace from the Remote Server URL and the OAuth token URL from an
-- Authentication Remote Server; the user account status and lock / unlock. Run as XXFUSION in an APEX session of
-- an administrator with Integrations - Manage and Users & Access - Manage. Everything is rolled back.
-- Schema: ADMIN
-- (as ADMIN in COMMON's schema: reading and locking an APEX account outside a browser needs APEX admin rights)
alter session set current_schema = XXFUSION;
set serveroutput on size unlimited feedback off
declare
    l_srv xxfnd_integration_pkg.t_server;
    l_rs  varchar2(255);
    l_usr number;
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        dbms_output.put_line(case when p_cond then 'PASS ' else 'FAIL ' end || p_label);
    end;
begin
    -- I-059: the APEX session of the tests' administrator ADMIN (tests/setup/03_common_test_fixture.sql)
    apex_util.set_workspace('XXCUS');
    apex_session.create_session(p_app_id => 135, p_page_id => 1, p_username => 'ADMIN');
    -- an Object Storage server on an existing Remote Server whose URL ends with /n/<namespace>, if the workspace has one
    select max(remote_server_static_id) into l_rs from apex_workspace_remote_servers
     where base_url like 'https://objectstorage.%/n/%';
    if l_rs is null then
        dbms_output.put_line('SKIP no Remote Server https://objectstorage.<region>.oraclecloud.com/n/<namespace> in the workspace');
    else
        xxfnd_integration_pkg.save_server(l_rs, 'R109 storage', 'OBJECT_STORAGE');
        l_srv := xxfnd_integration_pkg.server(l_rs);
        ok('region read from the Remote Server URL: ' || l_srv.oci_region, l_srv.oci_region is not null);
        ok('namespace read from the Remote Server URL: ' || l_srv.oci_namespace, l_srv.oci_namespace is not null);
    end if;
    -- the account status of a local user - outside the APEX session (APEX refuses reading an account inside one, outside
    -- a browser); the database user ADMIN is the tests' administrator ADMIN (Users & Access - Manage) there (I-059)
    apex_session.delete_session;
    apex_util.set_workspace('XXCUS');
    select min(user_id) into l_usr from xxfnd_users where user_type = 'LOCAL' and enabled_flag = 'Y';
    if l_usr is not null then
        for u in (select user_name from xxfnd_users where user_id = l_usr) loop
            ok('account status of ' || u.user_name || ': ' || xxfnd_user_pkg.account_status(u.user_name),
               xxfnd_user_pkg.account_status(u.user_name) in ('Active', 'Locked'));
            xxfnd_user_pkg.lock_account(l_usr, 'Y');
            ok('Lock Account locks', xxfnd_user_pkg.account_status(u.user_name) = 'Locked');
            xxfnd_user_pkg.lock_account(l_usr, 'N');
            ok('Unlock Account unlocks', xxfnd_user_pkg.account_status(u.user_name) = 'Active');
        end loop;
    end if;
    rollback;
exception
    when others then
        rollback;
        dbms_output.put_line('FAIL ' || sqlerrm);
end;
/
