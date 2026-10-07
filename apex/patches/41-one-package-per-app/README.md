# Patch 41 – one package per application (release 56)

## Why
Each application had two zips (the APEXlang zip and an install pack around it). There is now **one package per
application**, the zip you import:
- `COMMON-Application-APEXlang_56.zip`
- `KYC-Compliance-Platform-APEXlang_56.zip`

## What changes
- No more `*-Install-Pack_*.zip`. Install steps stay in `apex/install/<APP>/INSTALL.md`, the ADMIN script in
  `apex/db/admin/create-xxfusion-schema.sql` (only needed when XXFUSION does not exist).
- Release 55's separate move script is withdrawn. As in release 54, the first KYC import moves KYC's shared data to
  XXFUSION itself (all IDs kept, columns and row counts checked before XXCUS's copy is dropped and synonyms created).

## Deploy
1. Import `COMMON-Application-APEXlang_56.zip`: parsing schema **XXFUSION**, Install Supporting Objects: Yes.
2. Import `KYC-Compliance-Platform-APEXlang_56.zip` over app 134: Install Supporting Objects: Yes.
