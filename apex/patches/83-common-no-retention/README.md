# Patch 83 - COMMON: no retention policy (release 77, COMMON only)

## What changes
- No retention policy is seeded any more: the business keeps every record and nothing is deleted.
- The error-log policy seeded by release 76 (1 year, flag for review) is removed when nobody changed it since
  (OBJECT_VERSION_NUMBER = 1); a policy someone created or edited stays.
- No code ever acted on retention policies (they are records only); no data was ever deleted.

## Files
- `db/09f-error-handling.sql`

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_77.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
Independent of KYC 77: either can be installed first. A re-run changes nothing.
