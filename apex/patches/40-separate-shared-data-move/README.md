# Patch 40 – the shared-data move is a separate step (release 55)

## Why
In release 54 the KYC import also moved KYC's shared data to XXFUSION. The move is now a **separate, one-time step**,
so the KYC import only installs the application.

## What changes
- New `migrate/move-kyc-shared-data-to-xxfusion.sql` (in the KYC install pack). It holds the move:
  - copies the shared data to XXFUSION, keeping all IDs;
  - checks that every column exists and that the row counts match;
  - only then drops the XXCUS copy, creates the synonyms, re-creates the foreign keys on XXFUSION and re-points the
    data-security policies.
  - Safe to re-run; on an already moved schema it only refreshes synonyms.
- KYC script `03` no longer moves data. If XXCUS still has its own copy it reports **ORA-20903 ACTION NEEDED** (run the
  move script, then come back) and nothing else is installed.

## Deploy (two separate steps after COMMON)
1. Import COMMON from `COMMON-Install-Pack_55.zip` (parsing schema XXFUSION, Install Supporting Objects: Yes).
2. **Existing KYC only, once:** SQL Workshop → SQL Scripts (schema XXCUS) → Upload
   `migrate/move-kyc-shared-data-to-xxfusion.sql` → Run.
3. Import KYC from `KYC-Install-Pack_55.zip` over app 134 (Install Supporting Objects: Yes).

If release 54 was already installed with the move done, step 2 is not needed.
