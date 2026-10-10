# Patch 69 - Party component: its own logic, card as data, ID verification and registry checks (release 74)

## What changes
- XXCMP_PARTY_PKG holds the party directory and the matching (moved from the request and KYC packages).
- The party card is data (CARD_JSON) shown by a standard Value Attribute Pairs report.
- New: identity document checks (XXCMP_PARTY_ID_VERIFICATIONS, drawer 26) and company registry checks
  (XXCMP_PARTY_REGISTRY_CHECKS, drawer 27), on the party (21) and the case (211); merging parties moves them.

## Files
- `db/11-flexfield-runtime-part-2-of-2.sql`
- `db/16e0-party-pkg-spec.sql`
- `app/KYC/pages/p00023-party-relationship.apx`
- `app/KYC/pages/p00026-id-verification.apx`
- `app/KYC/pages/p00027-registry-check.apx`
- `app/KYC/pages/p00201-create-request.apx`
- `app/KYC/pages/p00222-reassessment.apx`

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
