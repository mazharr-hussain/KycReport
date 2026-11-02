--------------------------------------------------------------------------------
-- Validation database bootstrap (#192). Run as ADMIN on the validation ADB by repos/common/deployment/db/run.sh
-- (COMMON pipeline, every run).
-- Creates only what is missing - an existing user, grant, workspace or APEX user is left as it is - so a re-run
-- does nothing. Substitution variable (defined by the workflow, never echoed): xxcus_pw (App Builder user only).
--   1. XXCUS (workspace main schema) and XXFUSION (COMMON objects) users with the privileges 00a checks and a random
--      password nobody knows; ADMIN may connect through them (proxy: ADMIN[XXFUSION]), so no schema password is needed
--   2. workspace XXCUS: primary schema XXCUS, XXFUSION added
--   3. workspace admin user XXCUS (password: secret VAL_DB_PASSWORD) for App Builder
--   4. both schemas REST-enabled (App Builder installs APEXlang apps only into a REST-enabled parsing schema)
--------------------------------------------------------------------------------
set define off verify off feedback off serveroutput on
declare
    procedure ensure_user(p_user varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from dba_users where username = p_user;
        if l_n = 0 then
            execute immediate 'create user ' || p_user || ' identified by "Rv' || dbms_random.string('x', 20)
                || '#7k" default tablespace data quota unlimited on data';
            dbms_output.put_line('created user ' || p_user);
        else
            dbms_output.put_line('user ' || p_user || ' exists - left as it is');
        end if;
    end;
begin
    ensure_user('XXCUS');
    ensure_user('XXFUSION');
end;
/
set define off
grant create session, create table, create view, create sequence, create procedure, create trigger, create type,
      create synonym, create job, create materialized view to xxcus, xxfusion;
grant execute on sys.dbms_rls to xxcus, xxfusion;
grant execute on sys.dbms_crypto to xxcus, xxfusion;
alter user xxcus grant connect through admin;
alter user xxfusion grant connect through admin;
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
set define on
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
set define off
begin
    ords_admin.enable_schema(p_enabled => true, p_schema => 'XXCUS', p_url_mapping_type => 'BASE_PATH',
                             p_url_mapping_pattern => 'xxcus', p_auto_rest_auth => true);
    ords_admin.enable_schema(p_enabled => true, p_schema => 'XXFUSION', p_url_mapping_type => 'BASE_PATH',
                             p_url_mapping_pattern => 'xxfusion', p_auto_rest_auth => true);
    commit;
end;
/
