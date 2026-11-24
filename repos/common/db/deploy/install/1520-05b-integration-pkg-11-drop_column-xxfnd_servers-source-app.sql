--------------------------------------------------------------------------------
-- 05b step 11 (release 112): XXFND_SERVERS.SOURCE_APPLICATION_ID is dropped - the Fusion Integration Application route
-- (release 93) is replaced by the server's own APEX Remote Server link (REMOTE_SERVER_CODE).
-- Idempotent: the column is dropped only while it exists.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.drop_column('XXFND_SERVERS', 'SOURCE_APPLICATION_ID');
end;
/
