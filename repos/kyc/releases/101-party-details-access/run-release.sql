-- KYC 101 party details access in the party package: runs this release's steps in order (SQLcl / SQL Developer: @run-release.sql)
set define off
@@db/0230-package-spec-xxcmp_party_pkg.pks
@@db/0550-package-body-xxcmp_party_pkg.pkb
