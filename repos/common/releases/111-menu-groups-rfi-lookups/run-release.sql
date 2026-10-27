-- COMMON 111 Menu group page, RFI lookups, install fix: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0960-package-spec-xxfnd_application_pkg.pks
@@db/0970-package-body-xxfnd_application_pkg.pkb
@@db/1180-view-xxfnd_servers_v.sql
@@db/1900-package-spec-xxfnd_user_pkg.pks
@@db/1910-package-body-xxfnd_user_pkg.pkb
@@db/2390-view-xxfnd_nav_menu_v.sql
@@db/2670-41b-rfi-lookups-01-register-rfi-lookups.sql
exec dbms_utility.compile_schema(schema => user, compile_all => false)
