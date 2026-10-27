-- COMMON 109 Servers from APEX, user account lock: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/1150-05b-integration-pkg-07-add_column-xxfnd_servers-auth.sql
@@db/1170-view-xxfnd_servers_v.sql
@@db/1190-package-spec-xxfnd_integration_pkg.pks
@@db/1200-package-body-xxfnd_integration_pkg.pkb
@@db/1260-package-body-xxfnd_attach_pkg.pkb
@@db/1890-package-spec-xxfnd_user_pkg.pks
@@db/1900-package-body-xxfnd_user_pkg.pkb
exec dbms_utility.compile_schema(schema => user, compile_all => false)
