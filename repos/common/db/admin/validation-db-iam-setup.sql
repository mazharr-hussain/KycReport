--------------------------------------------------------------------------------
-- Validation database, IDCS (IAM) login (#195). Run ONCE as ADMIN in Database Actions > SQL (Run Script, F5),
-- after the IDCS setup (service user github-ci-svc, group github-ci, policy on autonomous-database-family).
-- Creates only what is missing; a re-run changes nothing. No password is stored anywhere:
--   1. IAM login switched on for the database
--   2. CI_IAM: global user mapped to the IDCS service user github-ci-svc (the GitHub workflow signs in with a token)
--   3. XXCUS (workspace main schema) and XXFUSION (COMMON objects): schema-only accounts (no password), with the
--      privileges 00a checks; CI_IAM may connect through them (proxy), so installs run as the schema owner
--   4. workspace XXCUS (primary XXCUS, XXFUSION added), both schemas REST-enabled
--   5. workspace admin user XXCUS for App Builder - initial password Change#Me2026, changed at first sign-in
-- Change the name below when the service user has another name or lives in another identity domain
-- ('<domain>/<user>').
--------------------------------------------------------------------------------
begin
    dbms_cloud_admin.enable_external_authentication(type => 'OCI_IAM', force => true);
end;
/
declare
    procedure ensure(p_user varchar2, p_ddl varchar2) is
        l_n pls_integer;
    begin
        select count(*) into l_n from dba_users where username = p_user;
        if l_n = 0 then
            execute immediate p_ddl;
        end if;
    end;
begin
    ensure('CI_IAM', q'[create user ci_iam identified globally as 'IAM_PRINCIPAL_NAME=github-ci-svc']');
    ensure('XXCUS', 'create user xxcus no authentication default tablespace data quota unlimited on data');
    ensure('XXFUSION', 'create user xxfusion no authentication default tablespace data quota unlimited on data');
end;
/
grant create session to ci_iam;
grant create session, create table, create view, create sequence, create procedure, create trigger, create type,
      create synonym, create job, create materialized view to xxcus, xxfusion;
grant execute on sys.dbms_rls to xxcus, xxfusion;
grant execute on sys.dbms_crypto to xxcus, xxfusion;
alter user xxcus grant connect through ci_iam;
alter user xxfusion grant connect through ci_iam;
declare
    l_n pls_integer;
begin
    select count(*) into l_n from apex_workspaces where workspace = 'XXCUS';
    if l_n = 0 then
        apex_instance_admin.add_workspace(p_workspace => 'XXCUS', p_primary_schema => 'XXCUS');
    end if;
    select count(*) into l_n from apex_workspace_schemas where workspace_name = 'XXCUS' and schema = 'XXFUSION';
    if l_n = 0 then
        apex_instance_admin.add_schema(p_workspace => 'XXCUS', p_schema => 'XXFUSION');
    end if;
    commit;
    apex_util.set_security_group_id(apex_util.find_security_group_id(p_workspace => 'XXCUS'));
    select count(*) into l_n from apex_workspace_apex_users where workspace_name = 'XXCUS' and user_name = 'XXCUS';
    if l_n = 0 then
        apex_util.create_user(
            p_user_name                    => 'XXCUS',
            p_web_password                 => 'Change#Me2026',
            p_developer_privs              => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
            p_default_schema               => 'XXCUS',
            p_allow_access_to_schemas      => 'XXCUS:XXFUSION',
            p_change_password_on_first_use => 'Y');
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
select username, authentication_type from dba_users where username in ('CI_IAM', 'XXCUS', 'XXFUSION');
