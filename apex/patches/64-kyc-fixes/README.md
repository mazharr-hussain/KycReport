# Patch 64 - KYC fixes (release 73, issues 10-16)

## What changes
- Party relationship: a party cannot be its own owner / officer (ORA-02290 XXCMP_PARTY_REL_CK1).
- Beneficial owner: marked on the relationship (Owners and Officers) with its basis required; the separate
  Beneficial Owners section of the case is removed (existing determinations are moved to the relationships).
- Request details show the Status.
- Request Information on the approval screen also when the approver is the requester (APEX cannot ask the requester
  from the requester): the question is recorded, the request returns to the requester (Information needed) and
  goes through approval again when submitted. The comment stays required.
- Screening: PEP / Sanctions / Adverse Media on one row; a screening added appears in the list at once.
- Case: opening a case again from the breadcrumb no longer fails with ORA-01403 (the case is kept in the session).

## Files
- `db/16b-kyc-requests-cases.sql`
- `db/16e-party-pkg.sql`
- `db/16g-approval-paths.sql`
- `db/16i-request-ui.sql`
- `app/KYC/p00023-party-relationship.apx`
- `app/KYC/p00203-create-request-submit.apx`
- `app/KYC/p00206-kyc-request-approval.apx`
- `app/KYC/p00211-case.apx`
- `app/KYC/p00213-screening.apx`

Files shared with other release 73 issues are listed once, in the patch where they changed most.

## Deploy (release 73, in this order)
The release zips carry every patch of release 73 (58-64); deploy them once, not patch by patch.
1. COMMON: import `COMMON-Application-APEXlang_73.zip` over COMMON with **Parsing Schema = XXCUS** and
   **Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
   Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
2. KYC: import `KYC-Compliance-Platform-APEXlang_73.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Every script is idempotent: a re-run does nothing, a database that has part of it gets only what it is missing.
