# Patch 38 – application zips hold APEXlang files only; separate install packs (release 53)

## Why
App Builder's import wizard showed a blank page (Export Repository → Import Application) for the release 50–52 zips.
Those zips also held `INSTALL.md` and `admin/*.sql`, which are not APEXlang files. SQLcl `apex import` ignores such
files, so the local tests did not catch it.

## What changes
- `COMMON-Application-APEXlang_53.zip` / `KYC-Compliance-Platform-APEXlang_53.zip`: APEXlang files only, as up
  to release 49.
- New per application: `COMMON-Install-Pack_53.zip` / `KYC-Install-Pack_53.zip` (`tools/build.py`). Each contains:
  - the application zip;
  - `INSTALL.md` (source `install/<APP>/INSTALL.md`);
  - for COMMON, the ADMIN script `admin/create-xxfusion-schema.sql` (source `db/admin/`).
- No change to the applications or database scripts (52 = 53 apart from the files above).

## Deploy
Unzip the install pack and import **the application zip inside it** in App Builder; follow its INSTALL.md.
COMMON: parsing schema XXFUSION, Install Supporting Objects: Yes. KYC: replace 134, Install Supporting Objects: Yes.

## Tested (local)
- Both application zips contain only .apx/.sql/.json/.js/.css/.png files.
- Both applications pass `apex validate` and import.
- The App Builder wizard itself was not available locally.
