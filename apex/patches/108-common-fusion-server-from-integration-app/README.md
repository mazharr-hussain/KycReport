# Patch 108 - COMMON 93: the Fusion server reads its connection from the Fusion integration application (UI issue 9)

Build: `COMMON-Application-APEXlang_93.zip` (application version "Release 93"). COMMON only; KYC is not changed.
Install COMMON 92 (patch 107) first.

## What changes
- **Server (121), Oracle Fusion Cloud:** new field **Fusion Integration Application**. Choose the workspace's Fusion
  integration application (the one made with App Builder > Create Fusion Integration, on the same identity domain as
  Fusion). COMMON then reads, every time it calls Fusion, that application's Remote Server (the URL) and Web Credential
  from APEX's own views (APEX_APPL_WEB_SRC_MODULES, APEX_WORKSPACE_REMOTE_SERVERS). Nothing is copied or typed, so a
  change to the Fusion application's server or credential is followed at once.
- With an application chosen, the server's own Web Credential list is hidden and the credential in use is shown
  read-only next to it ("Web Credential (from the application)"). Other server types (Outlook, SharePoint, UCM, ...)
  keep their own credential and do not show the field.
- Every Fusion call (the HCM worker sync, Fusion notifications) uses the server through XXFND_INTEGRATION_PKG.SERVER,
  which now returns the application's URL and credential.

## Database (`05b-integration-pkg.sql`)
- Checked step: XXFND_SERVERS.SOURCE_APPLICATION_ID (new column).
- XXFND_SERVERS_V: URL and Web Credential from the source application first; new columns SOURCE_APPLICATION_ID,
  SOURCE_APPLICATION, SOURCE_REMOTE_SERVER.
- XXFND_INTEGRATION_PKG.SAVE_SERVER: new optional p_source_application_id (kept for FUSION servers only).
A re-run changes nothing.

## After the upgrade
Platform > Integrations > Servers > Oracle Fusion Cloud: choose your Fusion integration application
(e.g. "Fusion Integrated Sample App") and Apply Changes. Until then the server works as before.

## Files
- `db/05b-integration-pkg.sql`
- `app/application.apx` (Release 93), `app/pages/p00121-server.apx`
- `tests/r93_fusion_server_test.sql` (new, as XXFUSION; argument: an application ID with REST Data Sources),
  `tests/r93_fusion_server_ui.py` (new, browser)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_93.zip` over COMMON (135), Install Supporting Objects: Yes.

## Tests (local database, COMMON 93)
- Install of 05b over COMMON 92: no error, no invalid object after recompile.
- `r93_fusion_server_test.sql 135`: 5/5 pass - the source application is kept, the Web Credential and URL are read from
  its REST Data Sources and Remote Server, XXFND_INTEGRATION_PKG.SERVER returns the same, a non-Fusion server keeps its
  own credential. (The local database has no Fusion integration application; COMMON's own REST Data Sources stood in.)
- `r93_fusion_server_ui.py` as ADMIN: 3/3 pass - the Fusion server shows the application field, other types do not.
  Choosing an application could not be clicked through locally (no such application in the local workspace).
- Nothing else in COMMON was changed or re-tested.
