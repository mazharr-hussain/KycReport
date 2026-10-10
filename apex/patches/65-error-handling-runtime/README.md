# Patch 65 - Central error handling, release version, common workflow runtime, session state check (release 74)

## What changes
- COMMON 09f: central error handling - message catalogue (XXFND_MESSAGES), error log (XXFND_ERROR_LOG) and
  XXFND_ERROR_PKG.APEX_ERROR_HANDLER on both applications (a user sees a clear message and a reference; the details
  are logged).
- The release number is shown in both applications (build version).
- COMMON 15b XXFND_WORKFLOW_PKG: start / state / end of a workflow, used by every component.
- Session state check: pages that lost an item value in the session are fixed (contacts, relationships, employee).
- Netlify builds are skipped (`netlify.toml`); GitHub checks validate the APEXlang sources.

## Files
- `db/15b-workflow-runtime.sql`
- `app/KYC/pages/p00022-party-contact.apx`
- `app/COMMON/pages/p00104-employee.apx`

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
