# Patch 82 - Error log for IT, retention defaults, KYC waits for COMMON, tests (release 76)

## What changes
- The error log is no longer granted to the application schemas; retention 1 year, flagged for review.
- Retention 5 years, flagged for review, for e-mails, ID / registry checks, source of funds and FIU reports.
- KYC stops (ORA-20904, nothing changed) when COMMON is older than this release or still installing.
- Tests: shared test_users.sql, run_all.sh (order and warm-up), kyc_flow_test fixed.

## Files
- `db/03-use-shared-schema.sql`
- `db/09f-error-handling.sql`
- `db/19c-share-with-applications.sql`
- `db/18-seed-data-and-administrator-part-2-of-2.sql`
- `tests/test_users.sql`
- `tests/run_all.sh`
- `tests/kyc_flow_test.sql`
- `tests/r74_kyc_test.sql`
- `tests/security_test.sql`
- `tests/workflow_test.sql`

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
