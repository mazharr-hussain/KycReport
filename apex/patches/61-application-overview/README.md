# Patch 61 - application overview from Home (release 73, issue 5)

## What changes
- Home: the application code opens the application's page: its setup overview (every setup type it may use, with a
  count, a link to the filtered list and Add) and every setup row of the application (Edit), 50 per page.

## Files
- `app/COMMON/p00001-home.apx`
- `app/COMMON/p00161-application.apx`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
