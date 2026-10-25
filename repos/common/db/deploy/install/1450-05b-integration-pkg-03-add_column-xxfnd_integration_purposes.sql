begin
    -- a purpose is served by a REST Data Source of COMMON (its Remote Server and Web Credential)
    xxfnd_ddl_pkg.add_column('XXFND_INTEGRATION_PURPOSES', 'REST_SOURCE_STATIC_ID', 'varchar2(255)');
    xxfnd_ddl_pkg.run(q'~comment on column xxfnd_integration_purposes.rest_source_static_id is 'Release 83: the REST Data Source of the COMMON application that serves the purpose (static ID); its Remote Server and Web Credential are kept by the workspace administrator.'~');

end;
/
