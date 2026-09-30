# Patch 06 – Application ID 134

Goes on top of patch 05 (release 20). The application ID changes from 101 to 134. Nothing else changes: no pages or
database objects change, and no database script is needed. The database code finds the application by its alias,
KYC, not by its ID.

## What changes in the source
- `apex/src/database/xxcus/apex_apps/f101` is renamed to `f134`, as SQLcl names an exported app.
- `f134/deployments/default.json` sets `"app": { "id": 134 }`, so an import with no ID given installs as 134.
- Tools, tests and docs now use the new path and ID 134.

## Deploy from the APEX screens
The workspace can't have two apps with the alias KYC. Choose one of these ways:

**A. Change the ID in place (keeps the app, no import).** Open app 101 in App Builder →
**Edit Application Properties** → **Application ID** = `134` → **Apply Changes**. If your APEX doesn't let you edit
the ID there, use B.

**B. Replace it with the release 21 zip.**
1. Export app 101 as a backup (App Builder → Export).
2. Finish or note any open requests and cases. Deleting the app also deletes its running workflows and tasks.
3. Delete app 101. Choose to delete the **application only**; do not remove supporting objects. Your tables and
   data are kept.
4. App Builder → **Import** `KYC-Compliance-Platform-APEXlang_21.zip` → application ID **134** → answer **No** to
   *Install Supporting Objects*.

After either way, open `…/ords/r/xxcus/kyc/` to check. Bookmarks that use `f?p=101:…` must change to `f?p=134:…`.
The friendly URL `r/xxcus/kyc/` stays the same.

## Tested (local Oracle 26ai + APEX 26.1)
- `apex validate` passes. `apex import` with no `-id` installed the app as 134.
- `party_ui.py` 15/15 and `request_approval_ui.py` 8/8 on app 134. The workflows and tasks run under the new ID.
