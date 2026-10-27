--------------------------------------------------------------------------------
-- 05b step 7 (release 109): XXFND_SERVERS.AUTH_SERVER_CODE - the APEX Remote Server of type Authentication whose URL
-- is the OAuth token URL (SharePoint / Outlook), so the token URL is kept in APEX, not typed in COMMON.
-- Idempotent: the column is added only when missing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_SERVERS', 'AUTH_SERVER_CODE', 'varchar2(255)');
    execute immediate q'~comment on column xxfnd_servers.auth_server_code is 'Release 109: static ID of the APEX Remote Server (type Authentication) that holds the OAuth token URL; OAUTH_TOKEN_URL is only the fallback of older servers.'~';
end;
/
