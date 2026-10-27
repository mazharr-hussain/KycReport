-- COMMON 110 Endpoints from REST Source Catalogs: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/1160-05b-integration-pkg-09-add_column-xxfnd_integration_purposes-catalog.sql
@@db/1200-package-spec-xxfnd_integration_pkg.pks
@@db/1210-package-body-xxfnd_integration_pkg.pkb
exec dbms_utility.compile_schema(schema => user, compile_all => false)
