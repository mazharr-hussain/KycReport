# Patch 59 - APEX application ID filled at install and registration (release 73, issue 3)

## What changes
- Every registered application gets its APEX application ID at install, at registration and at any sign-in.

## Files
- `db/09b-security-framework-objects.sql`
- `db/09d-application-functions.sql`
- `db/21b-application-functions.sql`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
