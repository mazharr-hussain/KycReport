# Patch 68 - Request Information and Add Approver on the request and case approvals (R26) (release 74)

## What changes
- The request approval (206) and the case approval (211) offer Request Information and Add Approver.
- KYC 16m: case status Pending Information (a checked change of XXCMP_CASES_CK1); the requester answers on the
  request screen 206; the request status Information needed reads Pending Information.
- My Tasks (40) and Home (1) open these tasks on the right screen.

## Files
- `db/16c-monitoring.sql`
- `db/16m-case-pending-information.sql`
- `app/KYC/application.apx`
- `app/KYC/pages/p00040-my-tasks.apx`
- `app/KYC/pages/p00230-executive-dashboard.apx`
- `app/KYC/shared-components/task-definitions/CASE-APPROVAL.apx`
- `app/KYC/shared-components/task-definitions/DOC-CHECKLIST-REVIEW.apx`
- `app/COMMON/application.apx`

Files shared with other release 74 parts are listed once, in the patch of their latest change.

## Deploy (release 74, in this order)
The release zips carry every patch of release 74 (65-74); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_74.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_74.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or, instead of both imports, run `COMMON-Application-SQL-Install_74.sql` then
   `KYC-Compliance-Platform-SQL-Install_74.sql` as ADMIN in SQL Developer Web (see each `install/<app>/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
