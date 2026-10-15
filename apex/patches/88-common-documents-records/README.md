# Patch 88 - COMMON: Documents and Records (release 81, COMMON only - C4 Documents and Records)

## What changes
- **One package per component.** The document store transport (Oracle UCM, SharePoint, database) is private code of
  `XXFND_ATTACH_PKG`; `XXFND_ATTACH_STORE_PKG` is dropped (checked `XXFND_DDL_PKG.DROP_OBJECT`: its DDL is recorded in
  `XXFND_DROPPED_OBJECTS`). Script `13-document-store.sql` is no longer installed.
- **Document Entity (131)** saves its display name through `XXFND_ATTACH_PKG.SAVE_ENTITY_DISPLAY_NAME` (no DML in the page).
- **Retention is a placeholder** (decision D3): new `XXFND_RETENTION_PKG` (`IS_ACTIVE` = N, `POLICY_FOR` = null,
  `RUN` does nothing; no job calls it). The Retention screen (112) shows only "Retention is not active yet: no record is
  flagged, archived or deleted." No data is changed or deleted.

## Files
- `db/`: 13a (comment), 14, 14b (new), `manifest.json`
- `app/`: `application.apx` (Release 81), pages 112 (Retention) and 131 (Document Entity)

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_81.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
A re-run changes nothing.

## Tests
`apex/tests/r81_documents_test.sql` (as XXFUSION) and `apex/tests/r81_documents_ui.py`.
