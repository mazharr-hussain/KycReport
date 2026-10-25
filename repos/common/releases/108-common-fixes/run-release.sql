-- COMMON 108 review fixes: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0240-package-spec-xxfnd_util_pkg.pks
@@db/0250-package-body-xxfnd_util_pkg.pkb
@@db/0260-package-spec-xxfnd_audit_pkg.pks
@@db/0270-package-body-xxfnd_audit_pkg.pkb
@@db/0290-package-spec-xxfnd_approval_pkg.pks
@@db/0840-package-spec-xxfnd_vpd_pkg.pks
@@db/0850-package-body-xxfnd_vpd_pkg.pkb
@@db/1010-package-spec-xxfnd_dff_pkg.pks
@@db/1250-package-body-xxfnd_attach_pkg.pkb
@@db/1880-package-spec-xxfnd_user_pkg.pks
@@db/1890-package-body-xxfnd_user_pkg.pkb
@@db/2640-41a-common-108-cleanup-01-drop_object-xxfnd_transmissions.sql
exec dbms_utility.compile_schema(schema => user, compile_all => false)
