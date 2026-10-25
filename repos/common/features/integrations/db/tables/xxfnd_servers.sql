
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
end;
/
