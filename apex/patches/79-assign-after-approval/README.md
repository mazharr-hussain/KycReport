# Patch 79 - Assign Case after the approval (release 76)

## What changes
- The common Approve dialog (206) no longer asks for the case officer.
- When the approval opens the case, the approver lands on the request (205) with Assign Case open (default: themselves);
  the case is created for the officer chosen, or reassigned when it already exists.

## Files
- `app/KYC/pages/p00205-kyc-request.apx`
- `app/KYC/pages/p00206-kyc-request-approval.apx`
- `app/KYC/shared-components/static-files/js/kyc-app.js`
- `tests/r75_ui.py`

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
