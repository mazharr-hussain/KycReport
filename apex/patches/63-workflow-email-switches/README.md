# Patch 63 - workflow and e-mail switches (release 73, issue 7)

## What changes
- Workflow on / off per process (COMMON > Workflow Processes): off = the record is approved automatically and its
  history shows "Auto-approved (workflow disabled)" (KYC request approval; KYC case approval levels).
- E-mail on / off for the instance, each application and each process: an e-mail is sent only when all three are
  on. Tasks and in-application notifications are not affected.

## Files
- `db/09e-workflow-switches.sql`
- `db/15-workflow.sql`
- `app/COMMON/p00147-process-catalogue.apx`
- `app/KYC/KYC-CASE.apx`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
