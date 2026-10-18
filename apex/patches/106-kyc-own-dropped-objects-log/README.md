# Patch 106 - KYC 94: 16g installs on COMMON 88 or later (KYC's own dropped-objects log)

Build: `KYC-Compliance-Platform-APEXlang_94.zip` (application version "Release 94"). KYC only; COMMON is not changed.

## The problem
16g (request approval paths) failed:
`ORA-41900: missing INSERT privilege on "XXFUSION"."XXFND_DROPPED_OBJECTS"` at `XXCUS.XXFND_DDL_PKG` line 146.
- KYC's script 03 (runs first) made a synonym in XXCUS for every XXFND_ object of COMMON, including
  XXFND_DROPPED_OBJECTS (the log of the deployment framework).
- Script 00 then skipped XXCUS's own log table (`create table if not exists` saw the synonym's name).
- So DROP_OBJECT in 16g wrote its log row into COMMON's table, which COMMON 88 and later refuse to applications.
- Running it as ADMIN with CURRENT_SCHEMA = XXFUSION is not a workaround (ORA-06598, and it would look for the
  package in XXFUSION, not in XXCUS).

## The fix (script 03 only)
- XXFND_DROPPED_OBJECTS is no longer given a synonym (as COMMON's generic 00c already does).
- An existing synonym of it is dropped, so script 00 creates KYC's own log table.

## Files
- `db/03-use-shared-schema.sql`
- `app/application.apx` (Release 94)

## Deploy
App Builder > Import `KYC-Compliance-Platform-APEXlang_94.zip` over KYC (134), Parsing Schema XXCUS, Install Supporting
Objects: Yes (Upgrade). Nothing to do by hand. (If you already ran the manual step - drop the synonym and create the
table as XXCUS - this release changes nothing more.)

## Tests (local database, COMMON 91 with KYC 93 -> 94)
- Before: with the synonym in XXCUS and a package XXCMP_APPROVAL_PKG to drop, 16g failed with the same ORA-41900.
- After: 03, 00, 16g - the synonym is gone, XXCUS has its own XXFND_DROPPED_OBJECTS, 16g dropped XXCMP_APPROVAL_PKG and
  logged it there. A second run of 03, 00, 16g: no error. No invalid objects after recompile.
- Nothing else in KYC was changed or re-tested.
