-- Release 93 (COMMON UI issue 9): a FUSION server reads its URL and Web Credential from the chosen APEX application's
-- REST Data Sources (the workspace's Fusion integration app). Run as XXFUSION; the change is rolled back.
-- APP_ID: an application of the workspace with REST Data Sources that have a Web Credential (default 135).
set serveroutput on
define app_id = '&1'
declare
    l_pass pls_integer := 0; l_fail pls_integer := 0;
    l_app  number := to_number(nvl('&app_id', '135'));
    l_srv  xxfnd_servers_v%rowtype;
    l_cred varchar2(255); l_url varchar2(4000);
    procedure ok(p_label varchar2, p_cond boolean) is
    begin
        if p_cond then l_pass := l_pass + 1; dbms_output.put_line('PASS ' || p_label);
        else l_fail := l_fail + 1; dbms_output.put_line('FAIL ' || p_label); end if;
    end;
begin
    select max(m.credential_static_id), max(w.base_url) into l_cred, l_url
      from apex_appl_web_src_modules m
      left join apex_workspace_remote_servers w on w.remote_server_static_id = m.remote_server_static_id
     where m.application_id = l_app;
    xxfnd_integration_pkg.save_server(p_server_code => 'FUSION', p_server_name => 'Oracle Fusion Cloud',
        p_server_type => 'FUSION', p_credential_static_id => 'SOMETHING_TYPED', p_source_application_id => l_app);
    select * into l_srv from xxfnd_servers_v where server_code = 'FUSION';
    ok('source application kept: ' || l_srv.source_application, l_srv.source_application_id = l_app);
    ok('Web Credential read from the application: ' || l_srv.credential_static_id, l_srv.credential_static_id = l_cred);
    ok('URL read from the application''s Remote Server: ' || l_srv.base_url, l_srv.base_url = l_url);
    ok('server() used by the Fusion calls gives the same', xxfnd_integration_pkg.server('FUSION').credential_static_id = l_cred);
    xxfnd_integration_pkg.save_server(p_server_code => 'OUTLOOK_GRAPH', p_server_name => 'Outlook', p_server_type => 'OUTLOOK',
        p_credential_static_id => 'XXFND_GRAPH_CRED', p_source_application_id => l_app);
    select * into l_srv from xxfnd_servers_v where server_code = 'OUTLOOK_GRAPH';
    ok('a non-Fusion server keeps its own credential', l_srv.source_application_id is null and l_srv.credential_static_id = 'XXFND_GRAPH_CRED');
    rollback;
    dbms_output.put_line(l_pass || ' pass, ' || l_fail || ' fail');
end;
/
exit
