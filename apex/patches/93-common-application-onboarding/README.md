# Patch 93 - COMMON: application onboarding, workspace servers, storage per application (release 86, COMMON only)

## What changes
- **Applications as a guided journey** (Platform > Applications): Register Application (165) - pick an APEX
  application of the workspace that is not registered, then roles, users, shared functions, setup types, processes,
  notifications, document storage, integrations, review and **Register** (nothing saved before). The application page
  (166) shows every section with Add / Edit / Remove, Edit (journey at any step), Disable / Enable, and Delete only
  when the application is disabled and nothing refers to it. Page 161 is retired; its saves are PL/SQL now.
- **Onboarding by script**: `db/admin/onboard-application.sql` (as XXFUSION) registers an existing APEX application by
  its ID with the basic setup (role `<CODE>_ADMIN`, shared functions and processes off, default notifications,
  documents in the database). Re-runnable.
- **Registration routines** (REGISTER_* in the owning packages) and XXFND_ATTACH_PKG.MOVE_DOCUMENTS for any caller.
- **Workspace servers** (Integrations > Servers): one register for storage and integration servers (APEX Remote Server
  + Web Credential + the type's details: OCI Object Storage, SharePoint, UCM, Fusion, REST, Outlook). Purposes pick a
  server.
- **Document storage per application with category overrides** (Attachments > Storage); database when nothing is set
  or the setup is incomplete; **OCI Object Storage** is a new store. Old storage rules are converted; documents keep
  their location.
- The retired `XXFND_INTEGRATION_ENDPOINTS` table is removed after its servers are copied (approved exception to the
  no-delete rule: retired configuration only). COMMON no longer seeds KYC's application row.

## Files
- `db/`: 00, 04b, 05 (+ upgrade), 05b, 05c, 09b, 09d, 10, 11, 14, 15, 15d, 15e, 16i, 16j, 19c, 21c, 22, 25,
  28-registration.sql (new), 29-servers.sql (new), 30-application-journey.sql (new), admin/onboard-application.sql
  (new), manifest.json
- `app/`: application.apx (Release 86), pages 0, 120, 121, 122, 123, 136, 137, 160, 165 (new), 166 (new), 161 removed;
  lists, breadcrumbs, application process JOURNEY_ACTIONS, LOVs

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_86.zip` over COMMON (App Builder import; the supporting objects run the upgrade
scripts; data kept). A re-run changes nothing. Then set up the servers (Integrations > Servers) and, per application,
its storage (Attachments > Storage) if documents should leave the database. **KYC needs its own release**: its seed
script still writes the removed endpoints table.

## Tests (COMMON on its own - no business application installed or onboarded)
- Test setup: `apex/tests/r86_test_apps.sql` (as XXCUS, once: empty APEX test applications 860 and 861) and
  `apex/tests/common_test_fixture.sql` (as XXFUSION: test application R86TEST onboarded, its RFI categories, local user
  TEST1). Test rows are kept.
- New: `r86_registration_test.sql` (98 checks), `r87_servers_test.sql` (54), `r88_journey_test.sql` (24),
  `r87_servers_ui.py`, `r88_journey_ui.py`.
- Install cycle: COMMON-only fresh install 0 errors, re-run 0, upgrade from release 74 twice 0 errors; DB tests r78-r88
  and browser tests r78-r88 pass on the fresh and the upgraded database (r83's Test Connection reports the unreachable
  test server, as before). `r73_common_test.sql` tests KYC's own workflows and needs KYC installed: it passes on the
  upgraded database only.
