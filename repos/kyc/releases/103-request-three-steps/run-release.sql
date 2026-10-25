-- KYC 103 Create Request in 3 steps: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0390-package-spec-xxcmp_request_pkg.pks
@@db/0670-package-body-xxcmp_request_pkg.pkb
