# Patch 70 - Request component: own package body, one CREATE_CASE, no HTML (release 74)

## What changes
- The request package body is its own script (16r) and the case package body too (16s).
- One CREATE_CASE (case package); the KYC_REQUEST workflow step is XXCMP_REQUEST_PKG.OPEN_CASE.
- Document rules are XXCMP_DOC_RULE_PKG (XXCMP_KYC_PKG dropped); XXCMP_APPROVAL_PKG is request approval only.
- Request header, details and answers are standard reports (no HTML from PL/SQL).

## Files
- `db/16-kyc-rules.sql`
- `db/16g-approval-paths.sql`
- `db/16g0-approval-pkg-spec.sql`
- `app/KYC/pages/p00000-global-page.apx`
- `app/KYC/pages/p00021-party.apx`
- `app/KYC/pages/p00205-kyc-request.apx`
- `app/KYC/pages/p00206-kyc-request-approval.apx`
- `app/KYC/shared-components/workflows/KYC-REQUEST.apx`

Files shared with other release 74 parts are listed once, in the patch of their latest change.

## Deploy (release 74, in this order)
The release zips carry every patch of release 74 (65-75); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_74.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_74.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
   Or, instead of both imports, run `COMMON-Application-SQL-Install_74.sql` then
   `KYC-Compliance-Platform-SQL-Install_74.sql` as ADMIN in SQL Developer Web (see each `install/<app>/INSTALL.md`).
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
