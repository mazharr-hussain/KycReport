
-- release 86 (part B): the workspace servers, defined once by the COMMON administrator
begin
    if xxfnd_ddl_pkg.create_table('XXFND_SERVERS', q'~create table xxfnd_servers (
    server_code            varchar2(255)  not null,
    server_name            varchar2(200)  not null,
    server_type            varchar2(30)   not null,
    base_url               varchar2(1000),
    credential_static_id   varchar2(255),
    oauth_token_url        varchar2(1000),
    oci_region             varchar2(100),
    oci_namespace          varchar2(200),
    enabled_flag           varchar2(1)    default 'Y' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_servers_pk primary key (server_code),
    constraint xxfnd_servers_ck1 check (server_type in ('OBJECT_STORAGE','SHAREPOINT','UCM','FUSION','REST','OUTLOOK')),
    constraint xxfnd_servers_ck2 check (enabled_flag in ('Y','N')),
    constraint xxfnd_servers_ck3 check (server_code <> 'DATABASE')
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_servers is 'Release 86: the servers of the workspace, defined once by the COMMON administrator. SERVER_CODE = the static ID of the APEX Remote Server (workspace component); its secret is the APEX Web Credential CREDENTIAL_STATIC_ID. Storage servers: OBJECT_STORAGE (OCI region, namespace), SHAREPOINT (Microsoft Graph, OAuth token URL), UCM (WebCenter Content); integration servers: FUSION, REST, OUTLOOK (Microsoft Graph). The database needs no server.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_servers.base_url is 'Used only while no APEX Remote Server of SERVER_CODE exists (copied from the retired XXFND_INTEGRATION_ENDPOINTS); the Remote Server URL wins.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_servers.credential_static_id is 'Static ID of the APEX Web Credential; empty = of a COMMON REST Data Source on the Remote Server, else <SERVER_CODE>_CREDENTIALS.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_servers.oauth_token_url is 'SHAREPOINT / OUTLOOK (Microsoft Graph): OAuth2 client-credentials token URL (not a secret).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_servers.oci_region is 'OBJECT_STORAGE: OCI region, e.g. eu-frankfurt-1 (URL https://objectstorage.<region>.oraclecloud.com when there is no Remote Server).'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_servers.oci_namespace is 'OBJECT_STORAGE: the Object Storage namespace of the tenancy.'~');
    end if;
    xxfnd_schema_pkg.create_who_trigger('XXFND_SERVERS');
    -- a purpose may name the server it uses
    xxfnd_ddl_pkg.add_column('XXFND_INTEGRATION_PURPOSES', 'SERVER_CODE', 'varchar2(255)');
    xxfnd_ddl_pkg.add_constraint('XXFND_INTEGRATION_PURPOSES', 'XXFND_INT_PURPOSES_FK2',
        'foreign key (server_code) references xxfnd_servers (server_code)');
    xxfnd_ddl_pkg.ensure_index('XXFND_INT_PURPOSES_N2',
        'create index xxfnd_int_purposes_n2 on xxfnd_integration_purposes (server_code)');
    xxfnd_audit_pkg.create_audit_trigger('XXFND_INTEGRATION_PURPOSES');   -- audit the new column too
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_integration_purposes.server_code is 'Release 86: the server (XXFND_SERVERS) the purpose uses; a REST Data Source, when set, keeps its own Remote Server.'~');
end;
/

-- 2. the servers: the retired endpoints (dynamic SQL - the table is gone after the first run), then the servers
-- COMMON ships as workspace components
declare
    l_n pls_integer;
    procedure srv(p_code in varchar2, p_name in varchar2, p_type in varchar2, p_cred in varchar2, p_desc in varchar2) is
    begin
        merge into xxfnd_servers t using (select p_code server_code from dual) s
           on (t.server_code = s.server_code)
         when not matched then insert (server_code, server_name, server_type, credential_static_id, enabled_flag, description)
                               values (s.server_code, p_name, p_type, p_cred, 'Y', p_desc);
    end srv;
begin
    xxfnd_util_pkg.set_install_mode(true);
    select count(*) into l_n from user_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    if l_n > 0 then
        execute immediate q'~
        merge into xxfnd_servers t
        using (select e.endpoint_code, e.endpoint_name, e.base_url, e.web_credential_static_id, e.oauth_token_url,
                      e.description,
                      case when e.endpoint_type in ('UCM', 'SHAREPOINT') then e.endpoint_type
                           when e.endpoint_code = 'FUSION' then 'FUSION'
                           when e.endpoint_code like 'OUTLOOK%' then 'OUTLOOK'
                           else 'REST' end                                       as server_type,
                      case when e.status_code = 'INACTIVE' then 'N' else 'Y' end as enabled_flag
                 from xxfnd_integration_endpoints e
                where e.endpoint_code <> 'DATABASE') s
           on (t.server_code = s.endpoint_code)
         when not matched then insert (server_code, server_name, server_type, base_url, credential_static_id,
                                       oauth_token_url, enabled_flag, description)
                               values (s.endpoint_code, s.endpoint_name, s.server_type, s.base_url,
                                       s.web_credential_static_id,
                                       case when s.server_type in ('SHAREPOINT', 'OUTLOOK') then s.oauth_token_url end,
                                       s.enabled_flag, s.description)~';
    end if;
    srv('FUSION', 'Oracle Fusion Cloud', 'FUSION', 'FUSION_CREDENTIALS',
        'Oracle Fusion Cloud Applications (HCM workers for the user sync).');
    srv('UCM_MAIN', 'Oracle WebCenter Content', 'UCM', 'XXFND_UCM_CRED', 'Document store UCM (attachments).');
    srv('SHAREPOINT_MAIN', 'Microsoft SharePoint (Graph)', 'SHAREPOINT', 'XXFND_GRAPH_CRED',
        'Document store SharePoint through Microsoft Graph (attachments). Needs the OAuth token URL of the tenant.');
    xxfnd_util_pkg.set_install_mode(false);
    commit;
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
