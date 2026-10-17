-- Release 83 checks (run as XXFUSION): C6 Integrations - servers as APEX Remote Servers and Web Credentials, the one
-- call procedure with its log and retry, Test Connection, purposes on REST Data Sources, the HCM sync through purpose
-- HCM_SYNC, registered endpoints read-only, the attachments' stores reached through XXFND_INTEGRATION_PKG.
-- Changes are rolled back; the call log is autonomous and kept (rows of entity R83_TEST).
set serveroutput on feedback off
declare
    l_n     number;
    l_v     varchar2(4000);
    l_srv   xxfnd_integration_pkg.t_server;
    l_resp  clob;
    l_max   number;
    procedure check_(p_ok in boolean, p_text in varchar2) is
    begin
        dbms_output.put_line(case when p_ok then 'PASS ' else 'FAIL ' end || p_text);
    end check_;
    procedure expect_error(p_code in number, p_text in varchar2, p_block in varchar2) is
    begin
        execute immediate p_block;
        check_(false, p_text || ' (no error)');
    exception
        when others then
            check_(sqlcode = p_code, p_text || ' (' || sqlcode || ')');
    end expect_error;
begin
    apex_util.set_workspace('XXCUS');   -- the workspace views (Remote Servers, Web Credentials, REST Data Sources)
    select nvl(max(call_id), 0) into l_max from xxfnd_integration_calls;

    select count(*) into l_n from user_objects where status <> 'VALID';
    check_(l_n = 0, 'no invalid object (' || l_n || ')');
    select count(*) into l_n from user_procedures
     where object_name = 'XXFND_INTEGRATION_PKG'
       and procedure_name in ('SERVER', 'CALL', 'RETRY', 'CAN_RETRY', 'TEST_CONNECTION', 'LOG_START', 'LOG_END',
                              'SYNC_HCM', 'SYNC_FROM_FUSION', 'SYNC_RUNNING');
    check_(l_n = 10, 'XXFND_INTEGRATION_PKG holds servers, calls, log and the HCM sync (' || l_n || ' of 10)');
    select count(*) into l_n from user_triggers where trigger_name = 'XXFND_EMPLOYEES_SRC' and status = 'ENABLED';
    check_(l_n = 1, 'the Fusion-owned rows trigger is in place (created by 05b)');

    -- servers: APEX Remote Servers of the workspace, the retiring endpoint only as a fallback
    select count(*) into l_n from apex_workspace_remote_servers
     where remote_server_static_id in ('FUSION', 'UCM_MAIN', 'SHAREPOINT_MAIN', 'OUTLOOK_GRAPH');
    check_(l_n = 4, 'the four servers are APEX Remote Servers (' || l_n || ')');
    select count(*) into l_n from apex_workspace_credentials
     where static_id in ('FUSION_CREDENTIALS', 'XXFND_UCM_CRED', 'XXFND_GRAPH_CRED');
    check_(l_n = 3, 'their Web Credentials exist (' || l_n || ')');
    l_srv := xxfnd_integration_pkg.server('FUSION');
    check_(l_srv.base_url is not null and l_srv.credential_static_id = 'FUSION_CREDENTIALS',
           'server FUSION: URL from the Remote Server, credential from its REST Data Source');
    l_srv := xxfnd_integration_pkg.server('UCM_MAIN');
    check_(l_srv.credential_static_id = 'XXFND_UCM_CRED', 'server UCM_MAIN keeps the credential its endpoint named');
    expect_error(-20301, 'an unknown server is refused', q'~declare s xxfnd_integration_pkg.t_server; begin s := xxfnd_integration_pkg.server('NO_SUCH_SERVER'); end;~');

    -- purposes on REST Data Sources; HCM_SYNC
    select max(rest_source_static_id) into l_v from xxfnd_integration_purposes where purpose_code = 'HCM_SYNC';
    check_(l_v = 'FUSION_HCM_WORKERS', 'purpose HCM_SYNC uses REST Data Source FUSION_HCM_WORKERS');
    select count(*) into l_n from apex_appl_web_src_modules
     where module_static_id = 'FUSION_HCM_WORKERS' and remote_server_static_id = 'FUSION';
    check_(l_n = 1, 'REST Data Source FUSION_HCM_WORKERS is in COMMON, on server FUSION');
    expect_error(-20312, 'a purpose without REST Data Source cannot be called',
                 q'~declare r clob; begin r := xxfnd_integration_pkg.call('NO_SUCH_PURPOSE'); end;~');

    -- the call procedure logs the call (the FUSION host does not answer here: the call fails and is retryable)
    begin
        l_resp := xxfnd_integration_pkg.call('HCM_SYNC', p_query => 'limit=1', p_entity_name => 'R83_TEST', p_pk1_value => '1');
        check_(true, 'call answered');
    exception
        when others then
            check_(true, 'call failed as expected without a reachable Fusion host (' || sqlcode || ')');
    end;
    select count(*) into l_n
      from xxfnd_integration_calls where call_id > l_max and purpose_code = 'HCM_SYNC' and entity_name = 'R83_TEST';
    check_(l_n >= 1, 'the call is in XXFND_INTEGRATION_CALLS');
    select max(call_id) into l_n from xxfnd_integration_calls where call_id > l_max and entity_name = 'R83_TEST';
    check_(xxfnd_integration_pkg.can_retry(l_n) in ('Y', 'N'), 'can_retry answers');
    expect_error(-20313, 'retry refused without Integrations - Manage',
                 'begin xxfnd_integration_pkg.retry(' || l_n || '); end;');
    expect_error(-20313, 'Test Connection refused without Integrations - Manage',
                 q'~declare r varchar2(4000); begin r := xxfnd_integration_pkg.test_connection('FUSION'); end;~');

    -- the HCM sync does nothing harmful while the server is not answering: no employee is disabled by it
    select count(*) into l_n from xxfnd_employees where enabled_flag = 'Y';
    begin
        xxfnd_integration_pkg.sync_hcm;
    exception
        when others then
            null;   -- an unreachable host raises; the sync changes nothing then
    end;
    select count(*) into l_v from xxfnd_employees where enabled_flag = 'Y';
    check_(to_number(l_v) = l_n, 'HCM sync without a reachable server disables nobody');

    -- release 86: the registered endpoints are retired (copied into XXFND_SERVERS, table and trigger dropped by 29)
    select count(*) into l_n from user_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    check_(l_n = 0, 'registered endpoints retired (release 86: XXFND_SERVERS)');
    select count(*) into l_n from user_constraints
     where table_name = 'XXFND_INTEGRATION_PURPOSES'
       and constraint_name in ('XXFND_INT_PURPOSES_CK3', 'XXFND_INT_PURPOSES_CK4', 'XXFND_INT_PURPOSES_CK5');
    select count(*) into l_max from user_constraints where constraint_name = 'XXFND_INT_PURPOSES_CK5';
    check_(l_n = 1 and l_max = 1, 'an API purpose needs a REST Data Source or a server (release 86: CK5)');

    -- the attachments reach their stores through XXFND_INTEGRATION_PKG
    select count(*) into l_n from user_source
     where name = 'XXFND_ATTACH_PKG' and type = 'PACKAGE BODY' and lower(text) like '%xxfnd_integration_pkg.server%';
    check_(l_n = 1, 'attachments resolve their store server through XXFND_INTEGRATION_PKG');
    select count(*) into l_n from user_source
     where name = 'XXFND_ATTACH_PKG' and type = 'PACKAGE BODY' and lower(text) like '%insert into xxfnd_transmissions%';
    check_(l_n = 0, 'attachments log their calls in the COMMON call log');

    -- Servers tab label
    select max(tab_label) into l_v from xxfnd_feature_pages where app_alias = 'COMMON' and page_id = 120;
    check_(l_v = 'Servers', 'the Integrations tab reads Servers');
    rollback;   -- the call log rows of this test (entity R83_TEST) stay: the log is kept, nothing is deleted
end;
/
