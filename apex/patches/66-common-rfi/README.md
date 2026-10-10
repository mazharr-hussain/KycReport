# Patch 66 - Request for information in COMMON with rounds (release 74)

## What changes
- COMMON 15c: one request-for-information process for every application (XXFND_RFIS, XXFND_RFI_ROUNDS,
  XXFND_RFI_PKG). Providers come from the Approval Setup and answer in turn; asking again starts a new round.
- KYC 16k copies the KYC RFIs to the common tables (the KYC table XXCMP_RFIS is left as it is).
- KYC pages 30-33 and the RFI tasks use the common RFI; a case raises its RFIs through it.

## Files
- `db/16k-rfi-to-common.sql`
- `db/17-seed-data-and-administrator-part-1-of-2.sql`
- `app/KYC/pages/p00030-requests-for-information.apx`
- `app/KYC/pages/p00032-raise-request-for-information.apx`
- `app/KYC/pages/p00033-provide-information.apx`
- `app/KYC/shared-components/task-definitions/RFI-RESPONSE.apx`
- `app/KYC/shared-components/task-definitions/RFI-REVIEW.apx`

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
