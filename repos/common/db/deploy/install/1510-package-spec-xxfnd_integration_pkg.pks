
create or replace package xxfnd_integration_pkg authid definer as
    -- Upserts one Fusion worker (JSON object from the HCM publicWorkers resource).
    procedure upsert_fusion_worker(p_worker in json_object_t);
    -- Pages through Fusion HCM publicWorkers with the given web credential and refreshes the FUSION employees;
    -- workers no longer returned are disabled, not deleted.
    procedure sync_from_fusion(p_base_url              in varchar2,
                               p_credential_static_id  in varchar2,
                               p_page_size             in pls_integer default 200);
    -- True while SYNC_FROM_FUSION runs; lets the Fusion-owned-row trigger (XXHR_EMPLOYEES_SRC) tell the sync
    -- apart from a user edit.
    function sync_running return boolean;
    -- Sets each Fusion employee's user name and Fusion user id from their Fusion / identity-domain user account
    -- (HCM userAccounts: Username, UserId by PersonId); the user name is what single sign-on returns. Called by
    -- SYNC_FROM_FUSION; a worker without a user account keeps the work e-mail.
    procedure sync_user_names(p_base_url             in varchar2,
                              p_credential_static_id in varchar2,
                              p_page_size            in pls_integer default 200);

    ---------------------------------------------------------------- release 83: servers, calls, log
    type t_server is record (
        static_id            varchar2(255),
        server_name          varchar2(255),
        base_url             varchar2(4000),
        credential_static_id varchar2(255),
        -- release 86: from XXFND_SERVERS (empty for a Remote Server the administrator has not defined there)
        server_type          varchar2(30),
        oauth_token_url      varchar2(1000),
        oci_region           varchar2(100),
        oci_namespace        varchar2(200));
    -- A server by static ID. Release 86: the server the COMMON administrator defined (XXFND_SERVERS_V: URL of its
    -- APEX Remote Server, else the copied URL; its Web Credential, else of a COMMON REST Data Source on it, else
    -- <static ID>_CREDENTIALS); else an APEX Remote Server of that static ID not defined yet (the same credential rule).
    -- ORA-20301 when neither exists.
    function server(p_static_id in varchar2) return t_server;
    -- Release 86: the Servers screen (121). Saves one server: SERVER_CODE = an APEX Remote Server static ID; the type
    -- decides which details are kept (OBJECT_STORAGE: region, namespace; SHAREPOINT / OUTLOOK: OAuth token URL); the
    -- other details are cleared. P_BASE_URL (kept when empty): used only while no APEX Remote Server of that static ID
    -- exists. ORA-20341 for an unknown type.
    procedure save_server(p_server_code          in varchar2,
                          p_server_name          in varchar2,
                          p_server_type          in varchar2,
                          p_credential_static_id in varchar2 default null,
                          p_oauth_token_url      in varchar2 default null,
                          p_oci_region           in varchar2 default null,
                          p_oci_namespace        in varchar2 default null,
                          p_enabled_flag         in varchar2 default 'Y',
                          p_description          in varchar2 default null,
                          p_base_url             in varchar2 default null,
                          -- release 93: FUSION - the workspace's Fusion integration application
                          p_source_application_id in number  default null);
    -- Deletes a server nothing uses; ORA-20342 when a storage rule or a purpose uses it (disable it instead).
    procedure delete_server(p_server_code in varchar2);
    -- Release 86: the Purposes screen (123). P_NEW = Y creates (ORA-20343 when the code exists), N changes the purpose
    -- (the maker-checker trigger sends a changed approved purpose back for approval).
    procedure save_purpose(p_purpose_code          in varchar2,
                           p_purpose_name          in varchar2,
                           p_application_code      in varchar2,
                           p_capture_method        in varchar2,
                           p_server_code           in varchar2,
                           p_rest_source_static_id in varchar2,
                           p_new                   in varchar2 default 'N');
    -- ORA-20344 when calls or transmissions refer to it.
    procedure delete_purpose(p_purpose_code in varchar2);
    -- The one call procedure: the purpose's REST Data Source on its Remote Server, with its Web Credential; p_path and
    -- p_query are added to the REST Data Source URL. Logged (XXFND_INTEGRATION_CALLS) and retryable. Raises ORA-20311
    -- with the HTTP status when the call fails; ORA-20312 when the purpose has no REST Data Source.
    function call(p_purpose_code in varchar2,
                  p_http_method  in varchar2 default 'GET',
                  p_path         in varchar2 default null,
                  p_query        in varchar2 default null,
                  p_body         in clob     default null,
                  p_entity_name  in varchar2 default null,
                  p_pk1_value    in varchar2 default null) return clob;
    -- Repeats a failed call made through CALL (a new log row points to it). INTEGRATIONS - Manage (ORA-20313).
    procedure retry(p_call_id in number);
    -- Y when the call failed and was made through CALL (the Retry button of the log).
    function can_retry(p_call_id in number) return varchar2;
    -- One GET to the server's base URL; any HTTP answer below 500 is REACHABLE. Kept in XXFND_SERVER_TESTS.
    -- INTEGRATIONS - Manage. Returns the result shown on the screen.
    function test_connection(p_server_static_id in varchar2) return varchar2;
    -- Log of calls made outside CALL (e.g. file transfers of the attachments), not retryable.
    function log_start(p_server_static_id in varchar2, p_http_method in varchar2, p_url in varchar2,
                       p_entity_name in varchar2 default null, p_pk1_value in varchar2 default null,
                       p_purpose_code in varchar2 default null) return number;
    procedure log_end(p_call_id in number, p_http_status in number, p_error in varchar2 default null);
    -- The Fusion HCM worker sync through purpose HCM_SYNC (Remote Server FUSION). Does nothing while the purpose
    -- has no REST Data Source or the server is not set up.
    procedure sync_hcm;

    ---------------------------------------------------------------- release 86 (part A): registration
    -- An integration purpose of the application, added when missing (an administrator's change is kept). Approved
    -- when a script registers it; from an APEX session it waits for the second person (maker-checker).
    -- ORA-20180 when the application is not registered; ORA-20186 when the purpose is another application's.
    procedure register_purpose(p_application_code      in varchar2,
                               p_purpose_code          in varchar2,
                               p_purpose_name          in varchar2,
                               p_capture_method        in varchar2 default 'MANUAL',
                               p_rest_source_static_id in varchar2 default null);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    procedure unregister_purpose(p_application_code in varchar2, p_purpose_code in varchar2);
    procedure unregister_application(p_application_code in varchar2);
end xxfnd_integration_pkg;
/
