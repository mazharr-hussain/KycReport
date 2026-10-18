# Patch 110 - COMMON 95: the Application Journey sets each part up in the wizard (UI issue 2)

Build: `COMMON-Application-APEXlang_95.zip` (application version "Release 95"). COMMON only, pages only: no database
change; KYC is not changed. Install COMMON 94 (patch 109) first.

## What changes
- **Before:** for a new application nothing was saved until Review > Register, so the Roles, Users, Notifications,
  Document storage and Integrations steps only said "added after registering"; the first administrator was chosen on
  the Users step.
- **Now:** step 1 (Application) also asks for the first administrator, and **Next registers the application** there
  (the same COMMON registration routine: grants, APEX ID, standard rows, administrator role, standard notifications).
  Every following step then does its set-up directly, with the screens already used for a registered application:
  - Roles: add the application's roles and their privileges;
  - Users: assign users to the roles;
  - Shared functions, Setup types, Processes: choose what the application keeps and switches on;
  - Notifications: switch each notification on / off;
  - Document storage: choose where documents are kept;
  - Integrations: add the integration purposes and their servers;
  - Review: everything at a glance; Save goes to the application.
- Step 1 explains this ("Next registers the application with its administrator...").

## Files
- `app/application.apx` (Release 95), `app/pages/p00165-application-journey.apx`
- `tests/r95_journey_ui.py` (new, browser: registers a test application - remove it afterwards with
  XXFND_APPLICATION_PKG.SET_ENABLED(code, 'N') then DELETE_APPLICATION)

## Deploy
App Builder > Import `COMMON-Application-APEXlang_95.zip` over COMMON (135). Install Supporting Objects may be Yes or No.

## Tests (local database, COMMON 95)
- `r95_journey_ui.py 188 JRN95` as ADMIN: 7/7 pass - step 1 asks for the administrator; Next registered JRN95 without
  error; steps 2 (Roles), 3 (Users), 7 (Notifications), 8 (Document storage), 9 (Integrations) show their set-up and no
  "after registering" note. The test application was deleted afterwards.
- Nothing else in COMMON was changed or re-tested.
