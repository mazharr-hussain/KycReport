# Patch 42 – one-time schema changes as an ADMIN script (release 57)

## Why
Dropping the shared objects from XXCUS and moving their data into XXFUSION happens once. It is no longer part of
any application package: it is an ADMIN script that validates everything first and only then performs.

## What changes
- New `apex/db/admin/move-kyc-shared-data-to-xxfusion.sql` (run once as ADMIN):
  - **A. Validate (changes nothing).** COMMON installed in XXFUSION; every shared table and column of XXCUS exists in
    XXFUSION; every object it would drop has its replacement in XXFUSION; foreign-key targets exist. Any failure:
    **ORA-20904** listing every problem, nothing changed.
  - **B. Perform.** Keeps the XXCMP_ foreign keys → moves the data (all IDs kept, row counts compared) → only then
    drops XXCUS's copy → synonyms → foreign keys on `xxfusion.*` → data security on XXFUSION's policy function →
    flexfield views regenerated → XXCUS recompiled.
  - Safe to re-run; on a moved XXCUS it changes nothing.
- KYC script `03` keeps only what every install needs (synonyms for new shared objects, data security). While XXCUS
  still has its own copy it reports **ORA-20903** (run the ADMIN script first) and nothing else is installed.

## Deploy
1. Import `COMMON-Application-APEXlang_57.zip`: parsing schema **XXFUSION**, Install Supporting Objects: Yes.
2. **Once, existing KYC only:** as ADMIN (Database Actions → SQL) run `move-kyc-shared-data-to-xxfusion.sql`
   (in this patch under `admin/`, or `apex/db/admin/`). It must end with
   `Done: the shared data is in XXFUSION; XXCUS uses synonyms. Now import KYC.`
3. Import `KYC-Compliance-Platform-APEXlang_57.zip` over app 134: Install Supporting Objects: Yes.
