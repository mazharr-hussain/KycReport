# Patch 71 - Case screen without HTML, screening provider fields, Source of Funds, FIU reports, message catalogue (release 74)

## What changes
- Case sections are a dynamic list (Links List); header and summary are standard reports.
- Home tiles are a Cards report; the person card is built from JSON.
- Screenings keep the provider data (endpoint, original response, reviewed by / date, changed by a person).
- Source of Funds / Wealth (XXCMP_CASE_FUNDS, drawer 218) and FIU / goAML reports (XXCMP_FIU_REPORTS, drawer 219).
- The party, request and case packages raise catalogue messages (KYC_PARTY_*, KYC_REQUEST_*, KYC_CASE_*).

## Files
- `db/09f-error-handling.sql`
- `db/16b-kyc-requests-cases.sql`
- `db/16e-party-pkg.sql`
- `db/16h-ui-helpers.sql`
- `db/16i-request-ui.sql`
- `db/16r-request-pkg.sql`
- `app/KYC/pages/p00001-home.apx`
- `app/KYC/pages/p00213-screening.apx`
- `app/KYC/pages/p00218-source-of-funds.apx`
- `app/KYC/pages/p00219-fiu-report.apx`
- `app/KYC/shared-components/app-processes.apx`
- `app/KYC/shared-components/lists.apx`
- `app/KYC/shared-components/static-files/css/kyc-app.css`
- `app/KYC/shared-components/static-files/js/kyc-app.js`

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
