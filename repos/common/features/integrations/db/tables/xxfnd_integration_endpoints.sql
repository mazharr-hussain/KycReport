
--==============================================================================
-- 0.4  INTEGRATION HUB  (created before attachments, which reference endpoints)
--==============================================================================
begin
    if xxfnd_ddl_pkg.create_table('XXFND_INTEGRATION_ENDPOINTS', q'~create table xxfnd_integration_endpoints (
    endpoint_code          varchar2(30)   not null,
    endpoint_name          varchar2(200)  not null,
    endpoint_type          varchar2(30)   not null,
    base_url               varchar2(1000) not null,
    web_credential_static_id varchar2(255),
    oauth_token_url        varchar2(1000),
    oauth_scope            varchar2(1000),
    status_code            varchar2(20)   default 'REGISTERED' not null,
    description            varchar2(1000),
    -- standard WHO columns
    created_by               varchar2(255)  not null,
    creation_date            timestamp      not null,
    last_updated_by          varchar2(255)  not null,
    last_update_date         timestamp      not null,
    last_update_login        varchar2(255),
    object_version_number    number         default 1 not null,
    constraint xxfnd_int_endpoints_pk primary key (endpoint_code),
    constraint xxfnd_int_endpoints_ck1 check (status_code in ('REGISTERED','ACTIVE','INACTIVE'))
)~') then
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_integration_endpoints.oauth_token_url is 'OAuth2 client-credentials token URL (not a secret), e.g. https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token for SharePoint via Microsoft Graph.'~');
        xxfnd_ddl_pkg.run(q'~comment on table  xxfnd_integration_endpoints is 'Non-Oracle external systems. Secrets live only in APEX Web Credentials (Shared Components); this table stores the credential static ID. Oracle Fusion uses APEX''s native Fusion integration instead.'~');
        xxfnd_ddl_pkg.run(q'~comment on column xxfnd_integration_endpoints.endpoint_type is 'Lookup ENDPOINT_TYPE: UCM, SHAREPOINT, SCREENING_PROVIDER, REGISTRY_PROVIDER, DOC_AUTH_PROVIDER, OTHER.'~');
    end if;
end;
/

-- the registered endpoints are read-only (retiring): the servers are APEX Remote Servers now
-- (release 86: only while the table exists - 29 copies it into XXFND_SERVERS and drops it)
declare
    l_n pls_integer;
begin
    select count(*) into l_n from user_tables where table_name = 'XXFND_INTEGRATION_ENDPOINTS';
    if l_n > 0 then
        execute immediate q'~create or replace trigger xxfnd_int_endpoints_ro
    before insert or update or delete on xxfnd_integration_endpoints
begin
    if xxfnd_util_pkg.in_apex_session then
        raise_application_error(-20316, 'Registered endpoints are read-only: servers are APEX Remote Servers, kept by '
            || 'the workspace administrator in Workspace Utilities.');
    end if;
end;~';
    end if;
end;
/
