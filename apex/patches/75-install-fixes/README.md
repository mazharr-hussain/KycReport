# Patch 75 - Install and upgrade fixes found by the release 74 test cycle (release 74)

## What changes
- Fresh install of COMMON: the Common Administrator's data security rules on RFIs and e-mails are seeded with
  the role (XXFND_SHARE_PKG.SEED_COMMON, 19c) instead of before it (15c, 15e).
- Fresh install of KYC: the grants to XXFUSION (19a) also run before the seed (the flexfield and approval checks
  read the KYC tables); the KYC approval rules (16l) are created after the seed of the approval matrix, paths and
  roles, so the case approval has its levels on a new database.
- Upgrade of a KYC installed before release 54: the one-time ADMIN move script accepts XXFND_CONFIG_APPROVAL_PKG,
  retired in release 74 (replaced by XXFND_APPROVAL_PKG).
- Every install ends with no invalid object: script 19 also recompiles invalid synonyms (a COMMON upgrade re-creates
  the shared objects they point to).
- Verified: fresh install, install over existing objects, re-run of every script, upgrade from the pre-move
  baseline with the move script, both SQL Developer Web scripts, and the App Builder import - 0 errors, 0 invalid.

## Files
- `db/15c-rfi-workflow.sql`
- `db/15e-communications.sql`
- `db/16l-kyc-approval-setup.sql`
- `db/19-reporting-views-and-recompile.sql`
- `db/19c-share-with-applications.sql`
- `admin/move-kyc-shared-data-to-xxfusion.sql`

Files shared with other release 74 parts are listed once, in the patch of their latest change.

## Deploy (release 74, in this order)
The release zips carry every patch of release 74 (65-75); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_74.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_74.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or, instead of both imports, run `COMMON-Application-SQL-Install_74.sql` then
   `KYC-Compliance-Platform-SQL-Install_74.sql` as ADMIN in SQL Developer Web (see each `install/<app>/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
