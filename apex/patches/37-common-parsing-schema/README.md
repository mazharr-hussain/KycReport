# Patch 37 – COMMON installs only in XXFUSION (release 52)

## What changes
- The COMMON export names parsing schema **XXFUSION**, so the import wizard preselects it. The workspace default
  XXCUS is for the business applications.
- Every COMMON supporting-object script except the checks now has a server-side condition: it runs only when the
  current schema is XXFUSION. Added by `tools/build.py` (`REQUIRED_SCHEMA`).
- New script **00b COMMON parsing schema check** (COMMON only, install and upgrade). With another parsing schema it
  reports **ORA-20901 ACTION NEEDED** and the steps to fix it:
  - App Builder → COMMON → Edit Application Definition → Security → Parsing Schema = XXFUSION;
  - then Utilities → Supporting Objects → Install Supporting Objects.

  Nothing is installed into the wrong schema.
- INSTALL.md explains the Parsing Schema choice. KYC unchanged.

## Deploy
Import `COMMON-Application-APEXlang_52.zip` (Parsing Schema = XXFUSION, Install Supporting Objects: Yes).

## Tested (local, supporting objects really run through an APEX install)
- Installed with parsing schema XXFUS: no object in XXFUS changed (all scripts skipped). 00b shows the ORA-20901
  message.
- Installed with parsing schema XXFUSION: every script ran, 0 invalid objects.
- SQLcl `apex validate` and import successful; the test apps were removed afterwards.
