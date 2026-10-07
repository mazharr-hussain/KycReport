# Patch 35 – self-contained installation packs with a prerequisites check (release 50)

## What changes
- Each release zip carries everything needed:
  - `INSTALL.md` in both zips;
  - the ADMIN script `admin/create-xxfus-schema.sql` in the COMMON zip.
- New first script **00a Prerequisites check** (install and upgrade, both applications) checks the parsing
  schema's privileges:
  - system privileges: create table, view, sequence, procedure, trigger, type, synonym, job, materialized view;
  - direct execute on DBMS_RLS and DBMS_CRYPTO;
  - tablespace quota.

  When something is missing it stops with **ORA-20900 ACTION NEEDED**. The message gives the exact statements
  to run as ADMIN and where to come back (Utilities → Supporting Objects → Install Supporting Objects).
- APEX's generic system-privilege prerequisite was removed so this clearer check is what you see.
  The failure and confirmation messages point to it.

## Deploy – application import only
1. Import `COMMON-Application-APEXlang_50.zip` over COMMON (parsing schema XXFUS) → Install Supporting Objects: Yes.
2. Import `KYC-Compliance-Platform-APEXlang_50.zip` over 134 → Install Supporting Objects: Yes.

If either install reports ORA-20900, run the listed statements as ADMIN, then re-run Supporting Objects.

## Tested (local)
- XXFUS without CREATE TYPE and DBMS_CRYPTO: the check lists exactly those two grants. After granting them it passes.
- Both applications validate and import, including from the zip with the extra files.
- KYC upgrade scripts: 0 errors.
- `common_ui.py`: ADMIN gets in; REQ2 is refused.
