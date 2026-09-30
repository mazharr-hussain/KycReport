comment on table xxcus.xxfnd_integration_endpoints is
    'Non-Oracle external systems. Secrets live only in APEX Web Credentials (Shared Components); this table stores the credential static ID. Oracle Fusion uses APEX''s native Fusion integration instead.'
    ;

comment on column xxcus.xxfnd_integration_endpoints.endpoint_type is
    'Lookup ENDPOINT_TYPE: UCM, SHAREPOINT, SCREENING_PROVIDER, REGISTRY_PROVIDER, DOC_AUTH_PROVIDER, OTHER.';

comment on column xxcus.xxfnd_integration_endpoints.oauth_token_url is
    'OAuth2 client-credentials token URL (not a secret), e.g. https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token for SharePoint via Microsoft Graph.'
    ;


-- sqlcl_snapshot {"hash":"046beda92b47a19802bee30bf438853e118fd5d9","type":"COMMENT","name":"xxfnd_integration_endpoints","schemaName":"xxcus","sxml":""}