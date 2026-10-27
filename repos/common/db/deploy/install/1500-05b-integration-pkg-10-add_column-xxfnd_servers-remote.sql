--------------------------------------------------------------------------------
-- 05b step 10 (release 112): XXFND_SERVERS.REMOTE_SERVER_CODE - the APEX Remote Server the server is linked to (its
-- name and URL are read from it); empty = the Remote Server whose static ID is SERVER_CODE (servers before 112).
-- Idempotent: the column is added only when missing.
--------------------------------------------------------------------------------
begin
    xxfnd_ddl_pkg.add_column('XXFND_SERVERS', 'REMOTE_SERVER_CODE', 'varchar2(255)');
    execute immediate q'~comment on column xxfnd_servers.remote_server_code is 'Release 112: static ID of the APEX Remote Server the server is linked to (name and URL are read from it); empty = SERVER_CODE.'~';
end;
/
