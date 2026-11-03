--------------------------------------------------------------------------------
-- Validation database bootstrap (#192). Run as ADMIN by db/run.sh setup (step 3.2), only when the environment is
-- missing (needs-bootstrap.sql) or this file changed in the pull request.
-- Creates only what is missing - an existing user, grant, workspace or APEX user is left as it is - so a re-run
-- changes nothing.
-- Substitution variables (passed on stdin by lib/sql.sh, never echoed): ci_user, ci_pw (random, this job's - db/run.sh),
-- xxcus_pw (secret VAL_DB_PASSWORD, App Builder user only).
--   1. XXCUS (workspace main schema) and XXFUSION (COMMON objects): random passwords nobody knows
--   2. the pipeline user (ci_user): least privilege for the pipeline -
--        create session / create table with admin option (the backup schema gets them from it)
--        create user, alter user, drop user (backup schema of the upgrade test)
--        APEX_ADMINISTRATOR_ROLE (remove / export the application)
--        connect through XXCUS and XXFUSION (proxy: ci_user[XXFUSION]); ADMIN no longer connects through them
--   3. workspace XXCUS: primary schema XXCUS, XXFUSION added
--   4. workspace admin user XXCUS (App Builder)
--   5. both schemas REST-enabled (App Builder installs APEXlang apps only into a REST-enabled parsing schema)
--------------------------------------------------------------------------------
set define on verify off feedback off serveroutput on
declare
    e_password_reused exception;
    pragma exception_init(e_password_reused, -28007);
    procedure ensure_user(p_user varchar2, p_password varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from dba_users where username = p_user;
        if l_n = 0 then
            execute immediate 'create user ' || dbms_assert.simple_sql_name(p_user) || ' identified by "'
                || p_password || '" default tablespace data quota unlimited on data';
            dbms_output.put_line('created user ' || p_user);
        elsif p_user = upper('&ci_user') then
            begin
                execute immediate 'alter user ' || dbms_assert.simple_sql_name(p_user) || ' identified by "'
                    || p_password || '"';
                dbms_output.put_line('user ' || p_user || ' exists - password set for this job');
            exception
                when e_password_reused then   -- ORA-28007: it already has this password
                    dbms_output.put_line('user ' || p_user || ' exists - password already set');
            end;
        else
            dbms_output.put_line('user ' || p_user || ' exists - left as it is');
        end if;
    end ensure_user;
begin
    ensure_user('XXCUS', 'Rv' || dbms_random.string('x', 20) || '#7k');
    ensure_user('XXFUSION', 'Rv' || dbms_random.string('x', 20) || '#7k');
    ensure_user(upper('&ci_user'), q'[&ci_pw]');
end;
/
grant create session, create table, create view, create sequence, create procedure, create trigger, create type,
      create synonym, create job, create materialized view to xxcus, xxfusion;
grant execute on sys.dbms_rls to xxcus, xxfusion;
grant execute on sys.dbms_crypto to xxcus, xxfusion;
grant create session, create table to &ci_user with admin option;
grant create user, alter user, drop user to &ci_user;
grant apex_administrator_role to &ci_user;
alter user xxcus grant connect through &ci_user;
alter user xxfusion grant connect through &ci_user;
declare
    procedure revoke_admin_proxy(p_user varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from proxy_users where proxy = 'ADMIN' and client = p_user;
        if l_n > 0 then
            execute immediate 'alter user ' || dbms_assert.simple_sql_name(p_user) || ' revoke connect through admin';
            dbms_output.put_line('ADMIN no longer connects through ' || p_user);
        end if;
    end revoke_admin_proxy;
begin
    revoke_admin_proxy('XXCUS');
    revoke_admin_proxy('XXFUSION');
end;
/
declare
    l_n pls_integer;
begin
    select count(*) into l_n from apex_workspaces where workspace = 'XXCUS';
    if l_n = 0 then
        apex_instance_admin.add_workspace(p_workspace => 'XXCUS', p_primary_schema => 'XXCUS');
        dbms_output.put_line('created workspace XXCUS');
    end if;
    select count(*) into l_n from apex_workspace_schemas where workspace_name = 'XXCUS' and schema = 'XXFUSION';
    if l_n = 0 then
        apex_instance_admin.add_schema(p_workspace => 'XXCUS', p_schema => 'XXFUSION');
        dbms_output.put_line('added XXFUSION to workspace XXCUS');
    end if;
    commit;
end;
/
declare
    l_n pls_integer;
begin
    apex_util.set_security_group_id(apex_util.find_security_group_id(p_workspace => 'XXCUS'));
    select count(*) into l_n from apex_workspace_apex_users where workspace_name = 'XXCUS' and user_name = 'XXCUS';
    if l_n = 0 then
        apex_util.create_user(
            p_user_name                    => 'XXCUS',
            p_web_password                 => q'[&xxcus_pw]',
            p_developer_privs              => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
            p_default_schema               => 'XXCUS',
            p_allow_access_to_schemas      => 'XXCUS:XXFUSION',
            p_change_password_on_first_use => 'N');
        dbms_output.put_line('created workspace admin user XXCUS');
    end if;
    commit;
end;
/
begin
    ords_admin.enable_schema(p_enabled => true, p_schema => 'XXCUS', p_url_mapping_type => 'BASE_PATH',
                             p_url_mapping_pattern => 'xxcus', p_auto_rest_auth => true);
    ords_admin.enable_schema(p_enabled => true, p_schema => 'XXFUSION', p_url_mapping_type => 'BASE_PATH',
                             p_url_mapping_pattern => 'xxfusion', p_auto_rest_auth => true);
    commit;
end;
/
