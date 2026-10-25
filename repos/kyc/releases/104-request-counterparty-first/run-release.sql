-- KYC 104 Create Request - counterparty first: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0390-package-spec-xxcmp_request_pkg.pks
@@db/0670-package-body-xxcmp_request_pkg.pkb
@@db/0880-18h-register-with-common-01-release_applied-r10.sql
