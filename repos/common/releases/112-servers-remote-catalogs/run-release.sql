-- COMMON 112 Servers linked to APEX Remote Servers, REST Source Catalogs, Fusion Objects removed: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/1170-05b-integration-pkg-10-add_column-xxfnd_servers-remote.sql
@@db/1180-05b-integration-pkg-11-drop_column-xxfnd_servers-source-app.sql
@@db/1190-table-xxfnd_server_catalogs.sql
@@db/1210-view-xxfnd_servers_v.sql
@@db/1230-package-spec-xxfnd_integration_pkg.pks
@@db/1240-package-body-xxfnd_integration_pkg.pkb
@@db/2530-41c-fusion-objects-removal-01-remove-fusion-objects.sql
exec dbms_utility.compile_schema(schema => user, compile_all => false)
