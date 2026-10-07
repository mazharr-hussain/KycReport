# Patch 32 – application key independent of the APEX ID (release 47)

Goes on top of any earlier release of app 134.

## Why
The APEX application ID can differ between DEV, TEST and PROD, so it cannot be the key of `XXFND_APPLICATIONS`.

## What changes
- `XXFND_APPLICATIONS.APPLICATION_ID` is an **internal key** (sequence `XXFND_APPLICATIONS_S`), never changed
  (trigger), used by the foreign keys (roles, features).
- `APPLICATION_CODE` (e.g. KYC) and `APEX_APP_ALIAS` (unique) are the **same in every environment**; seed scripts
  find the application by its code.
- New `APEX_APPLICATION_ID`: the APEX ID **in this environment**, written automatically at sign-in
  (`xxfnd_privilege_pkg.sync_current_application`).
- `xxfnd_privilege_pkg.current_application_id` finds the running application by its alias (then by the APEX ID);
  "KYC User" and "Administration Area" use it.
- Existing rows keep their key (the KYC row stays 134 locally; in a new environment it gets a sequence number).

## Deploy – application import only
**App Builder → Import** `KYC-Compliance-Platform-APEXlang_47.zip` → **Replace Existing Application** 134 →
**Install Supporting Objects: Yes**.

## Tested (local Oracle 26ai + APEX 26.1)
- All 37 upgrade scripts in APEX order: no errors, no invalid objects; after sign-in the KYC row has its APEX ID.
- App removed and re-imported from git (release 47): `kyc_ui.py` 26/26, `party_ui.py` 23/23,
  `request_party_ui.py` 24/24.
