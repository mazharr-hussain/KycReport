# Patch 62 - Managed in the Application: delegated administration (release 73, issue 6)

## What changes
- The "Available" switches and their enforcement are removed.
- IT can set a common function to "Managed in the Application" (COMMON > Applications > the application). That
  application's administrators who hold the function's privilege then find it in their own Administration menu as
  "<function> (shared setup)". It opens the same COMMON screen in a dialog inside their application (shared
  sign-in, no COMMON login), limited to their application's rows; instance rows are read-only.

## Files
- `db/16j-auth-pkg.sql`
- `db/11-flexfield-runtime-part-2-of-2.sql`
- `db/14-attachments.sql`
- `app/COMMON/application.apx`
- `app/COMMON/p00099-open-setup.apx`
- `app/KYC/lists.apx`
- `app/KYC/p00098-setup.apx`
- `app/KYC/p00000-global-page.apx`
- `app/KYC/p00031-request-for-information.apx`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
