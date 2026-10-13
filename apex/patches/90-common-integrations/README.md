# Patch 90 - COMMON: Integrations (release 83, COMMON only - C6 Integrations)

## What changes
- **Servers are APEX components.** APEX Remote Servers FUSION, UCM_MAIN, SHAREPOINT_MAIN and OUTLOOK_GRAPH and Web
  Credentials FUSION_CREDENTIALS, XXFND_UCM_CRED and XXFND_GRAPH_CRED are installed with placeholder URLs and no
  secrets; the workspace administrator sets them (ADMIN-GUIDE.md, "How to change a server").
- **Endpoints are REST Data Sources of COMMON:** FUSION_HCM_WORKERS, UCM_CONTENT, SHAREPOINT_DRIVES, OUTLOOK_MESSAGES.
  Purposes point to a REST Data Source; purpose HCM_SYNC is added. The registered endpoints are read-only and retiring
  (their rows stay; nothing in the application changes them).
- **One call procedure** (`XXFND_INTEGRATION_PKG.CALL`): purpose, REST Data Source, Remote Server, Web Credential;
  every call is logged with what is needed to retry it. **Test Connection** keeps each server's last result. The
  attachments find their document stores through the package and log their calls in the same log.
- **Screens:** Servers (120: owner, health - last call, last error, last test - and how to change a server), Server
  (121, Test Connection), Purposes (122/123, REST Data Source), Transmission Log (124, APEX's own web service log with
  the purpose and record), Call (125, Retry for a failed call made through the call procedure).
- **Fusion HCM sync** is a COMMON automation, installed **disabled**: switch it on once FUSION and FUSION_CREDENTIALS
  are set.
- `XXFND_INTEGRATION_PKG` now installs after the security objects (05b at 130 / 90) and creates the trigger
  `XXFND_EMPLOYEES_SRC` (moved from 08). No data is deleted.

## Files
- `db/`: 05b, 08, 14, 25 (new), `manifest.json`
- `app/`: `application.apx` (Release 83); pages 120 (Servers), 121 (Server), 122, 123, 124 (Transmission Log),
  125 (Call); `breadcrumbs.apx`; REST Data Sources (4); automation `fusion-hcm-sync`; workspace components (4 Remote
  Servers, 3 Web Credentials)
- `ADMIN-GUIDE.md`

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_83.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
A re-run changes nothing. Then set the servers and credentials (ADMIN-GUIDE.md).

## Tests
`apex/tests/r83_integrations_test.sql` (as XXFUSION) and `apex/tests/r83_integrations_ui.py`.
