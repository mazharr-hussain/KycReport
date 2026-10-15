# Patch 85 - COMMON: six modules (release 78, COMMON only - Foundation)

## What changes
- **Six modules.** COMMON is organised into Platform, Security, Reference Data, Documents and Records, Workflow and
  Integrations (system lookup `XXFND_MODULE`; each admin feature's `FEATURE_GROUP` is its module). Notifications moves
  to Workflow, Retention to Documents and Records, Lookups and Flexfields to Reference Data, Applications and
  Application Settings to Platform. The groups Basic Setup, Workflow & Integration and Application are no longer used.
- **Menu.** Home, then the six modules (the "Administration" level is gone). A module opens its module page (page
  100, one module per visit) and is expanded in the menu, showing its components.
- **Module page (100)** shows the module's components as cards; without a module it shows all six.
- **Home (1)** shows the six modules as cards with their state (for example "Retention not active yet", "E-mail off
  for the workspace", inactive endpoints); the Applications report (a duplicate of Platform > Applications) is gone.
- **Breadcrumbs:** Home > Module > Component on every page.
- **Approval Setup** (pages 148, 149) and **Optional Features** (pages 10020, 10021, formerly "Feature
  Configuration") are components of their own with their own menu entries; every role and application that had the
  Workflow Setup / Application Settings rights gets the same rights on them.
- **Subscriptions** (new page 164, a tab of Platform > Applications): every component an application subscribes from
  a COMMON master, and whether it needs a Publish.
- **`XXFND_DDL_PKG.DROP_OBJECT`**: the checked, re-runnable drop for packages and views used by the next releases
  (dependents and DDL recorded in `XXFND_DROPPED_OBJECTS`, own synonyms dropped, never purged; tables are refused).

## Files
- `db/00-deployment-framework.sql` (DROP_OBJECT, XXFND_DROPPED_OBJECTS), `db/19c-share-with-applications.sql`
  (the admin seed in six modules), `db/22-common-modules.sql` (new), `db/manifest.json`
- `app/`: `application.apx` (Release 78), pages 1, 100, 164 (new), 10020, 10021, shared components `lists.apx`
  (navigation menu, module lists; the four Administration group lists removed) and `breadcrumbs.apx`

## Deploy (COMMON only)
Import `COMMON-Application-APEXlang_78.zip` over COMMON with **Parsing Schema = XXCUS** and
**Install Supporting Objects: No**; then Edit Application Definition > Security > **Parsing Schema = XXFUSION** >
Apply Changes; then Utilities > Supporting Objects > **Install Supporting Objects** (upgrade scripts; data kept).
KYC is not changed. A re-run changes nothing.

## Tests
`apex/tests/r78_common_test.sql` (as XXFUSION) and `apex/tests/r78_modules_ui.py`.
