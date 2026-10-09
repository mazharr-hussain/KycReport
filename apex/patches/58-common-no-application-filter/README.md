# Patch 58 - COMMON without the application filter (release 73, issues 1 and 2)

## What changes
- The Application selector at the top of COMMON and its "Leave site?" warning are gone. IT sees every application;
  the lists keep their Application column.
- Feature Configuration and Application Settings list every registered application.

## Files
- `db/16i-admin-scope.sql`
- `app/COMMON/p00000-global-page.apx`
- `app/COMMON/app-items.apx`
- `app/COMMON/app-processes.apx`
- `app/COMMON/p10020-feature-configuration.apx`
- `app/COMMON/p10021-feature.apx`
- `app/COMMON/p10022-application-settings.apx`
- `app/COMMON/p10023-application-setting.apx`
- `app/COMMON/p00160-applications.apx`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
