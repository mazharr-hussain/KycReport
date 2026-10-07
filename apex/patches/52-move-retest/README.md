# Patch 52 – one-time move of KYC's shared data, retested on the final COMMON (ADMIN script)

## What changes (`admin/move-kyc-shared-data-to-xxfusion.sql`, also `apex/db/admin/`)
- After the move it grants XXFUSION the access to XXCUS's own objects (XXCMP_ tables, views, packages) that the KYC
  import also grants, so KYC keeps working before its next import (approvals, flexfields, user renames).
- It recompiles XXFUSION as well as XXCUS: the move's table changes invalidated some shared code.
- The move re-applies COMMON's own setup (base seed and administration seed, release 67).

## Verified locally (XXCUS with its own copy, XXFUSION with COMMON release 67)
- Validation first; then: KYC's data in XXFUSION (224 lookup values, 9 user roles), XXCUS keeps only its release
  tracking, 82 synonyms, 8 foreign keys and 4 data security policies on XXFUSION, 0 invalid objects in both schemas.
- COMMON keeps its 44 page mappings; the Common Administrator holds every admin privilege (46).
- Running it again changes nothing. `clean-common.sql` now stops with ORA-20905 (KYC depends on XXFUSION).
- KYC workflow test passes.

## Deploy (once, after COMMON 67 is installed)
As ADMIN (Database Actions → SQL, Run Script F5): `move-kyc-shared-data-to-xxfusion.sql`. It ends with
"Done: the shared data is in XXFUSION; XXCUS uses synonyms."
