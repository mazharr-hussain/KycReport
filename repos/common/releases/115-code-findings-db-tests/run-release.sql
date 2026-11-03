-- COMMON 115 Code findings and DB tests: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0960-package-spec-xxfnd_application_pkg.pks
@@db/0970-package-body-xxfnd_application_pkg.pkb
@@db/1240-package-body-xxfnd_integration_pkg.pkb
@@db/1580-package-body-xxfnd_approval_pkg.pkb
@@db/1810-package-body-xxfnd_approval_rule_pkg.pkb
@@db/1900-package-body-xxfnd_rfi_pkg.pkb
exec dbms_utility.compile_schema(schema => user, compile_all => false)
