-- KYC 100 no duplicate counterparty: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0230-package-spec-xxcmp_party_pkg.pks
@@db/0390-package-spec-xxcmp_request_pkg.pks
@@db/0550-package-body-xxcmp_party_pkg.pkb
@@db/0670-package-body-xxcmp_request_pkg.pkb
