# Patch 19 – Withdraw message, clickable wizard steps, attachments in the database (release 34)

Goes on top of patch 18 (release 33, app ID 134).

## What changes for users
- **KYC Requests – Withdraw:** after confirming, the green message *Request withdrawn: it is back in Draft.* shows
  (no more empty pop-up). An error from the server still shows in a pop-up.
- **Create / edit request and party wizards:** the steps in the progress bar (Counterparty, Party Details,
  Questionnaire, Review and Submit; and the party wizard) are clickable. Clicking a later step works like pressing
  **Next** step by step: each step is saved and checked, and the jump stops on the step that shows an error. Clicking
  an earlier step works like **Previous**.
- **Attachments:** when no UCM / SharePoint storage is set up for a record (Administration → Document Storage),
  files are stored in the database instead of failing with *No document storage is configured*. Download, versions
  and copying to the party work the same. A UCM / SharePoint row, once enabled, is used for new files; files already
  in the database stay there.

## Deploy from the APEX screens
1. Export app 134 as a backup.
2. **SQL Workshop → SQL Scripts → Upload** `19-db-database-storage.sql` → **Run**. At the end: *no rows* invalid
   objects. Idempotent.
3. **App Builder → Import** `KYC-Compliance-Platform-APEXlang_34.zip` → **Replace Existing Application** 134 →
   **Install Supporting Objects: No**.

`app/` holds the changed files: page 200, `kyc-app.js`, `kyc-app.css`, supporting objects 13a, 13, 14.

DB objects: new table `xxfnd_document_files` (file bytes, one row per version); check constraint
`xxfnd_documents_ck4` allows storage type `DATABASE`; `xxfnd_attach_store_pkg` (`database_config`, DATABASE upload
and download); `xxfnd_attach_pkg.resolve_storage` falls back to DATABASE.

## Tested (local Oracle 26ai + APEX 26.1, app 134)
- Withdraw on KYC Requests: success message, no empty pop-up.
- Edit a draft request: click step 4 from step 1 → saved through each step to Review and Submit; click step 1 →
  back to Counterparty.
- No storage configured (UCM row disabled): Add Document on Party Details stores the file in the database
  (`xxfnd_documents.storage_type = DATABASE`); the download returns the same bytes.
- Packages compile, no invalid objects; `apex validate` passes; `request_party_ui.py` 24/24.
