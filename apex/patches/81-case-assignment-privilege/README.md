# Patch 81 - Case Assignment privilege; console grants kept (release 76)

## What changes
- New privilege Case Assignment - Manage: Assign Case (205, 211) and the investigation task's administrators use it
  (first install: given to the roles holding Cases - Manage).
- The default role grants run only on the first install: a privilege removed in the console is not given back by an
  upgrade.
- Request package: departments check, Assign Case at request level; case package: approval required, approval check
  on Submit, Case Assignment.

## Files
- `db/18b-security-framework-seed.sql`
- `db/18e-kyc-requests-cases.sql`
- `db/16b-kyc-requests-cases.sql`
- `db/16r-request-pkg.sql`
- `db/16s-case-pkg.sql`

Files shared with other release 76 parts are listed once, in the patch of their latest change.

## Deploy (release 76, COMMON + KYC)
The release zips carry every patch of release 76 (78-82); deploy them once, not patch by patch. No SQL install script
from this release on.
1. COMMON: import `COMMON-Application-APEXlang_76.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
   Wait until it has finished.
2. KYC: import `KYC-Compliance-Platform-APEXlang_76.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   KYC stops with ORA-20904 (nothing changed) when COMMON 76 is not installed yet: finish step 1, then run KYC again.
3. QD only, once: run `apex/db/admin/qd-users-and-roles.sql` connected as XXFUSION (users, Requesting Entity roles,
   request approval by Level 1, Contributors without Case Assignment / Create Request). Re-running it changes nothing.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
