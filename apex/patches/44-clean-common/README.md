# Patch 44 – clean XXFUSION / COMMON; COMMON installs with zero errors (release 60, COMMON only)

## What changes
- New ADMIN script `admin/clean-common.sql` (also `apex/db/admin/`): removes the COMMON application and every object it
  created in XXFUSION (XXFND_ objects, flexfield _DFV views, XXFND_ jobs, data security policies). Other objects in
  XXFUSION are kept. It previews first, and stops with ORA-20905 (nothing changed) if another schema still uses the
  objects (synonyms / foreign keys from an application whose data was already moved).
- Script 05 (`xxfnd_schema_pkg`, `xxfnd_security_pkg`) no longer needs objects that script 09b creates later: a fresh
  install of COMMON on an empty XXFUSION compiled with errors before (and then scripts 07, 17, 20 failed).

## Verified locally
clean → import COMMON → Install Supporting Objects (fresh): 0 errors, 0 invalid objects; then upgrade scripts again:
0 errors; clean again: 0 errors.

## Deploy
1. As ADMIN (Database Actions → SQL, Run Script F5): `clean-common.sql`. Check the preview lists, then the last
   query returns no rows.
2. Import `COMMON-Application-APEXlang_60.zip` with Parsing Schema = XXCUS, Install Supporting Objects: No.
3. COMMON → Edit Application Definition → Security → Parsing Schema = XXFUSION → Apply Changes.
4. COMMON → Utilities → Supporting Objects → Install Supporting Objects.
