# Patch 78 - Approval rules: messages on Submit, no-approval rule, System, impact preview (release 76)

## What changes
- No matching Approval Setup rule: Submit stops with "No approval rule applies ..." (request and case).
- A step whose role no active user holds: Submit stops with "The approval step ... has no approver ..." instead of a
  workflow that faults later.
- A rule without approvers is the deliberate "no approval" rule: the request / case is approved at once (workflow
  KYC_CASE version 1.3 skips the levels; running cases keep version 1.2).
- Work done in the background shows as "System", not "nobody".
- The approval rule screen (COMMON 149) shows how many approvals in progress use the rule; a rule may have no approver.

## Files
- `db/15d-approval-setup.sql`
- `db/16h-ui-helpers.sql`
- `app/KYC/shared-components/workflows/KYC-CASE.apx`
- `app/COMMON/pages/p00149-approval-rule.apx`
- `tests/r76_kyc_test.sql`

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
