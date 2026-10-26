-- KYC 105 Request stages, stage 1 Assign, requester KPIs: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0390-package-spec-xxcmp_request_pkg.pks
@@db/0470-view-xxcmp_watchlist_v.sql
@@db/0500-package-body-xxcmp_monitor_pkg.pkb
@@db/0560-16f-party-request-redesign-01-xxcmp_parties-jurisdiction.sql
@@db/0620-package-body-xxcmp_request_ui_pkg.pkb
@@db/0640-16z-request-stages-01-add_column-xxcmp_requests.sql
@@db/0650-16z-request-stages-02-drop_constraint-xxcmp_requests_ck3.sql
@@db/0660-16z-request-stages-03-update-xxcmp_requests.sql
@@db/0670-16z-request-stages-04-add_constraint-xxcmp_requests_ck3.sql
@@db/0710-package-body-xxcmp_request_pkg.pkb
@@db/0770-package-body-xxcmp_case_pkg.pkb
@@db/0920-18h-register-with-common-01-release_applied-r10.sql
exec dbms_utility.compile_schema(schema => user, compile_all => false)
