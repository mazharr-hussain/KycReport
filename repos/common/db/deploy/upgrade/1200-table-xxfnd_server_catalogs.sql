-- release 112: the APEX REST Source Catalogs of a server (one server, many catalogs): a purpose on the server picks
-- its endpoint from the services of these catalogs
begin
    if xxfnd_ddl_pkg.create_table('XXFND_SERVER_CATALOGS', q'~create table xxfnd_server_catalogs (
    server_code            varchar2(255)  not null,
    catalog_id             number         not null,
    created_by             varchar2(255)  not null,
    creation_date          timestamp      default systimestamp not null,
    constraint xxfnd_server_catalogs_pk primary key (server_code, catalog_id),
    constraint xxfnd_server_catalogs_fk1 foreign key (server_code) references xxfnd_servers (server_code) on delete cascade
)~') then
        xxfnd_ddl_pkg.run(q'~comment on table xxfnd_server_catalogs is 'Release 112: the APEX REST Source Catalogs (APEX_REST_CATALOGS.CATALOG_ID) of a server; a purpose on the server takes its endpoint from their services. Kept by XXFND_INTEGRATION_PKG.SET_SERVER_CATALOGS.'~');
    end if;
end;
/
