# Patch 77 - Assign the case at request level (release 75)

## What changes
- Approve on the approval screen (206) asks **Assign the Case to** when this approval opens the case; the default is
  the approver. The choice is kept in the new column XXCMP_REQUESTS.CASE_ASSIGNEE (16w, checked ADD_COLUMN) and the
  case is created for that officer.
- **Assign Case** on the approved request (205) for whoever may assign the case (Cases managers, the assignee).
- One officer list (shared LOV Case Officers: active Compliance officers, managers, heads of Compliance) on 205, 206
  and 211; another user is refused (message KYC_CASE_OFFICER_INVALID).
- Fix: reassigning a case now moves the case and its investigation task together. Before, when the user was not a
  business administrator of the task, APEX refused the task change, the whole change was rolled back silently, and
  only the note "Assigned to ..." was kept. The task's business administrators are now the workflow administrators,
  the Cases managers and the assignee. Open investigation tasks created before release 75 keep their administrators;
  for them Assign shows for the workflow administrators only.
- Release 75 page changes of the Field Grid (patch 76) on 205, 206 and 211 are in this patch (their latest change).

## Files
- `db/16b-kyc-requests-cases.sql`
- `db/16g0-approval-pkg-spec.sql`
- `db/16g-approval-paths.sql`
- `db/16r-request-pkg.sql`
- `db/16s-case-pkg.sql`
- `db/16w-case-assignment.sql`
- `db/18e-kyc-requests-cases.sql`
- `db/manifest.json`
- `app/KYC/pages/p00205-kyc-request.apx`
- `app/KYC/pages/p00206-kyc-request-approval.apx`
- `app/KYC/pages/p00211-case.apx`
- `app/KYC/shared-components/lovs.apx`
- `app/KYC/shared-components/static-files/js/kyc-app.js`
- `app/KYC/shared-components/task-definitions/CASE-INVESTIGATION.apx`

Files shared with other release 75 parts are listed once, in the patch of their latest change.

## Tests
- `tests/r75_ui.py` (browser: layout and both assignment flows)
- `tests/r75_kyc_test.sql` (database)

## Deploy (release 75, KYC only)
The release zip carries both patches of release 75 (76-77); deploy it once, not patch by patch. COMMON is not changed
(release 74 COMMON must already be installed).
1. KYC: import `KYC-Compliance-Platform-APEXlang_75.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or run `KYC-Compliance-Platform-SQL-Install_75.sql` as ADMIN in SQL Developer Web (see `install/KYC/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
