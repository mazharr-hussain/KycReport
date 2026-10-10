# Patch 73 - Configurable risk model with the FATF lists and impact preview (R16, R24) (release 74)

## What changes
- KYC 16u0 / 16u: risk factors, country lists (FATF black and grey lists seeded, June 2025), tiers with review
  months, kept case breakdowns (XXCMP_RISK_PKG). Changes are maker-checker: the approved model stays in use while a
  change waits.
- Page 167 Risk Model: grids, the impact of pending changes on open cases, Submit Changes for Approval.
- Case 211 Risk Assessment shows the score, the suggested tier and how it is made up; the review date uses the model.

## Files
- `db/15-workflow.sql`
- `db/16s-case-pkg.sql`
- `db/16u-risk-model.sql`
- `db/16u0-risk-pkg-spec.sql`
- `db/18b-security-framework-seed.sql`
- `db/18c-admin-console.sql`
- `db/18e-kyc-requests-cases.sql`
- `app/KYC/pages/p00167-risk-model.apx`
- `app/KYC/pages/p00211-case.apx`
- `app/KYC/shared-components/breadcrumbs.apx`

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
