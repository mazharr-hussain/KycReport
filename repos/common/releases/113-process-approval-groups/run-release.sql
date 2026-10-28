-- COMMON 113 Process catalogue, approval groups, page fixes: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/1740-table-xxfnd_approval_groups.sql
@@db/1750-table-xxfnd_approval_group_members.sql
@@db/1760-15d-approval-setup-21-add_constraint-xxfnd_approval_rule_steps-group.sql
@@db/1800-package-spec-xxfnd_approval_rule_pkg.pks
@@db/1810-package-body-xxfnd_approval_rule_pkg.pkb
@@db/2570-41d-approval-groups-01-register-process-pages.sql
exec dbms_utility.compile_schema(schema => user, compile_all => false)
