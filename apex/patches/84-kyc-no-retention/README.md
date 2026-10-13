# Patch 84 - KYC: no retention policy (release 77, KYC only)

## What changes
- No retention policy is seeded any more for KYC tables: the business keeps every record and nothing is deleted.
- The policies seeded by earlier releases (5 years, flag for review: parties, e-mails, ID verifications, registry
  checks, source of funds, FIU reports) are removed when nobody changed them since (OBJECT_VERSION_NUMBER = 1);
  a policy someone created or edited stays.

## Files
- `db/18-seed-data-and-administrator-part-2-of-2.sql`

## Deploy (KYC only)
Import `KYC-Compliance-Platform-APEXlang_77.zip` over app 134 (Replace), **Install Supporting Objects: Yes**.
Needs COMMON 76 or later; independent of COMMON 77. A re-run changes nothing.
