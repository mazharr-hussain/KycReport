begin
    xxfnd_schema_pkg.create_who_trigger('XXFND_SERVERS');
    -- release 93 (UI issue 9): a FUSION server reads its Remote Server and Web Credential from the workspace's Fusion
    -- integration application (APEX "Create Fusion Integration", same identity domain) instead of its own
    xxfnd_ddl_pkg.add_column('XXFND_SERVERS', 'SOURCE_APPLICATION_ID', 'number');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_servers.source_application_id is 'Release 93: FUSION - the APEX application (the Fusion integration app of the workspace) whose REST Data Sources give the server URL and Web Credential; read when used, never copied.'~');
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
